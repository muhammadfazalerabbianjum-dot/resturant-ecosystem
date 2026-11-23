import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';

import '../../../helpers/test_helpers.dart';

/// PERF-8 W2 deterministic geolocator fake: overrides the platform instance
/// (the channel mock used by driver_location_service_test.dart cannot drive
/// stream/error paths) so the tests can count streams and emit errors.
class _ProbingGeolocator extends GeolocatorPlatform {
  final StreamController<Position> _controller =
      StreamController<Position>.broadcast();

  int getPositionStreamCalls = 0;
  int listenCalls = 0;
  int cancelCalls = 0;

  bool serviceEnabled = true;
  bool failInitialFix = false;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestResult = LocationPermission.whileInUse;

  Position get _fakePosition => Position(
    longitude: 55.2708,
    latitude: 25.2048,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => requestResult;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (failInitialFix) throw StateError('no gps fix');
    return _fakePosition;
  }

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => 1000;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    getPositionStreamCalls++;
    return _ProbedPositionStream(_controller.stream, this);
  }

  Future<void> dispose() => _controller.close();
}

class _ProbedPositionStream extends Stream<Position> {
  _ProbedPositionStream(this._inner, this.probe);

  final Stream<Position> _inner;
  final _ProbingGeolocator probe;

  @override
  StreamSubscription<Position> listen(
    void Function(Position)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    probe.listenCalls++;
    return _ProbedSubscription(
      _inner.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      ),
      probe,
    );
  }
}

class _ProbedSubscription implements StreamSubscription<Position> {
  _ProbedSubscription(this._inner, this.probe);

  final StreamSubscription<Position> _inner;
  final _ProbingGeolocator probe;

  @override
  Future<void> cancel() {
    probe.cancelCalls++;
    return _inner.cancel();
  }

  @override
  void onData(void Function(Position)? handle) => _inner.onData(handle);

  @override
  void onError(Function? handle) => _inner.onError(handle);

  @override
  void onDone(void Function()? handle) => _inner.onDone(handle);

  @override
  bool get isPaused => _inner.isPaused;

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture<E>(futureValue);
}

/// Shared mutable flag so ONE `deliveries` write fails across the whole
/// service session (each publish builds a fresh `doc()` reference).
class _FailureFlag {
  bool failed = false;
}

// `DocumentReference` is @sealed in cloud_firestore 6.8.0; a test double is
// the one legitimate implementer (same escape hatch fake_cloud_firestore uses).
// ignore: subtype_of_sealed_class
/// A Firestore double whose FIRST `deliveries` write fails (network down) and
/// every later write succeeds — the publish-recovery observable.
class _FlakyDocRef implements DocumentReference<Map<String, dynamic>> {
  _FlakyDocRef(this._inner, this._flag);

  final DocumentReference<Map<String, dynamic>> _inner;
  final _FailureFlag _flag;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (!_flag.failed) {
      _flag.failed = true;
      throw FirebaseException(
        plugin: 'firestore',
        code: 'unavailable',
        message: 'network down',
      );
    }
    await _inner.set(data, options);
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      _inner.get(options);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// `CollectionReference` implements the @sealed Query; a test double is the one
// legitimate implementer.
// ignore: subtype_of_sealed_class
class _FlakyCollection implements CollectionReference<Map<String, dynamic>> {
  _FlakyCollection(this._inner);

  final CollectionReference<Map<String, dynamic>> _inner;
  final _FailureFlag _flag = _FailureFlag();

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _FlakyDocRef(_inner.doc(path), _flag);

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      _inner.get(options);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FlakyOnceFirestore extends FakeFirebaseFirestore {
  _FlakyCollection? _deliveries;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'deliveries') {
      // ONE cached double: the service re-resolves `collection('deliveries')`
      // on every publish, and each fresh wrapper would forget the failure.
      return _deliveries ??= _FlakyCollection(super.collection(collectionPath));
    }
    return super.collection(collectionPath);
  }
}

/// Waits out the microtask queue so stream callbacks and Firestore writes
/// complete deterministically.
Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ProbingGeolocator probe;
  late FakeFirebaseFirestore fakeFirestore;
  late FakeLogger logger;
  late DriverLocationService service;
  final originalPlatform = GeolocatorPlatform.instance;

  setUp(() {
    probe = _ProbingGeolocator();
    GeolocatorPlatform.instance = probe;
    fakeFirestore = FakeFirebaseFirestore();
    logger = FakeLogger();
    service = DriverLocationService(fakeFirestore, logger);
  });

  tearDown(() async {
    await service.stopTracking();
    await probe.dispose();
    GeolocatorPlatform.instance = originalPlatform;
  });

  group('DriverLocationService error paths (PERF-8 W2)', () {
    test(
      'a failed initial GPS fix is logged and the live stream still opens',
      () async {
        probe.failInitialFix = true;

        await service.startTracking('order-gps-fail');
        await settle();

        expect(
          logger.loggedErrors,
          contains('DriverLocationService_initialGet'),
          reason: 'the initial-fix failure must be logged, never silent',
        );
        expect(
          probe.listenCalls,
          1,
          reason:
              'a failed initial fix must NOT prevent the live position stream',
        );
        expect(
          (await fakeFirestore.collection('deliveries').get()).docs,
          isEmpty,
        );
      },
    );

    test(
      'a stream error is logged and the subscription survives (no cancelOnError)',
      () async {
        await service.startTracking('order-stream-error');
        await settle();

        probe._controller.addError(StateError('gps glitch'));
        await settle();

        expect(
          logger.loggedErrors,
          contains('DriverLocationService_stream'),
          reason: 'the onError handler must log stream failures',
        );
        expect(
          probe.cancelCalls,
          0,
          reason: 'a transient stream error must not kill the tracking session',
        );

        // The subscription is still live: a real position still publishes.
        probe._controller.add(probe._fakePosition);
        await settle();
        final row = await fakeFirestore
            .collection('deliveries')
            .doc('order-stream-error')
            .get();
        expect(
          row.exists,
          isTrue,
          reason: 'the stream must keep publishing after a transient error',
        );
      },
    );

    test(
      'a failed Firestore publish is logged, then the next position publishes',
      () async {
        final flaky = FlakyOnceFirestore();
        final serviceOnFlaky = DriverLocationService(flaky, logger);

        await serviceOnFlaky.startTracking('order-flaky');
        await settle();

        expect(
          logger.loggedErrors,
          contains('DriverLocationService_publish'),
          reason: 'the failed write must be logged, never silent',
        );
        expect(
          (await flaky.collection('deliveries').get()).docs,
          isEmpty,
          reason: 'the first (failed) publish must not fake a row',
        );

        probe._controller.add(probe._fakePosition);
        await settle();

        final row = await flaky
            .collection('deliveries')
            .doc('order-flaky')
            .get();
        expect(
          row.exists,
          isTrue,
          reason: 'the service must recover and publish the next position',
        );
        expect(row.data()?['lat'], 25.2048);
      },
    );

    test(
      'permission permanently denied publishes no row and completes gracefully',
      () async {
        probe.permission = LocationPermission.deniedForever;

        await service.startTracking('order-denied-forever');
        await settle();

        expect(
          logger.loggedErrors,
          contains('Location permissions are permanently denied'),
        );
        expect(
          (await fakeFirestore.collection('deliveries').get()).docs,
          isEmpty,
          reason: 'deniedForever must not publish a tracking row',
        );
        expect(probe.listenCalls, 0, reason: 'no stream without permission');
      },
    );

    test(
      'permission granted after an in-context re-request publishes the initial row',
      () async {
        probe.permission = LocationPermission.denied;
        probe.requestResult = LocationPermission.whileInUse;

        await service.startTracking('order-rerequest');
        await settle();

        final row = await fakeFirestore
            .collection('deliveries')
            .doc('order-rerequest')
            .get();
        expect(
          row.exists,
          isTrue,
          reason: 'the re-request grant path must reach the initial publish',
        );
        expect(row.data()?['lat'], 25.2048);
        expect(probe.listenCalls, 1);
      },
    );

    test(
      're-arming across orders A→B→A re-subscribes cleanly and tracks order A again',
      () async {
        await service.startTracking('order-a');
        await settle();
        await service.startTracking('order-b');
        await settle();
        await service.startTracking('order-a');
        await settle();

        expect(
          probe.listenCalls,
          3,
          reason: 'every order switch opens exactly one fresh subscription',
        );
        expect(
          probe.cancelCalls,
          2,
          reason: 'every prior subscription must be cancelled on a switch',
        );
        expect(
          probe.getPositionStreamCalls,
          3,
          reason: 'no duplicate stream request per re-arm',
        );

        probe._controller.add(probe._fakePosition);
        await settle();

        final orderA = await fakeFirestore
            .collection('deliveries')
            .doc('order-a')
            .get();
        final orderB = await fakeFirestore
            .collection('deliveries')
            .doc('order-b')
            .get();
        expect(
          orderA.exists,
          isTrue,
          reason: 'the re-armed session must track order A again',
        );
        expect(orderB.exists, isTrue);
      },
    );
  });
}
