import 'dart:async';
import 'dart:io';

import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';

/// COV-2 deterministic geolocator fake: replaces [GeolocatorPlatform.instance]
/// so the tests can (a) feed synthetic positions into the service's stream,
/// (b) configure the permission/service-enabled branches, and (c) count the
/// exact observables of the GPS lifecycle — how many position streams were
/// opened, positions read, subscriptions taken and cancellations issued.
class _ProbingGeolocator extends GeolocatorPlatform {
  final StreamController<Position> _controller =
      StreamController<Position>.broadcast();

  int getPositionStreamCalls = 0;
  int getPositionCalls = 0;
  int listenCalls = 0;
  int cancelCalls = 0;

  /// S4 switch: `isLocationServiceEnabled` returns this value.
  bool serviceEnabled = true;

  /// S5/S6 switch: the result of `checkPermission` (for [denied] the probe's
  /// `requestPermission` always answers [denied] — fail-closed).
  LocationPermission checkPermissionResult = LocationPermission.whileInUse;

  /// Position returned by [getCurrentPosition] — used for the initial publish
  /// that establishes the deliveries doc.
  Position _position = Position(
    longitude: 55.0,
    latitude: 25.0,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );

  Position positionAt(double latitude, double longitude) => Position(
    longitude: longitude,
    latitude: latitude,
    timestamp: DateTime.fromMillisecondsSinceEpoch(1234),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );

  void setCurrentPosition(double latitude, double longitude) {
    _position = positionAt(latitude, longitude);
  }

  void emit(Position position) => _controller.add(position);

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => checkPermissionResult;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    getPositionCalls++;
    return _position;
  }

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => (startLatitude - endLatitude).abs() * 111000;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    getPositionStreamCalls++;
    return _ProbedPositionStream(_controller.stream, this);
  }

  Future<void> dispose() => _controller.close();
}

class _ProbedPositionStream extends Stream<Position> {
  final Stream<Position> _inner;
  final _ProbingGeolocator probe;

  _ProbedPositionStream(this._inner, this.probe);

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
  final StreamSubscription<Position> _inner;
  final _ProbingGeolocator probe;

  _ProbedSubscription(this._inner, this.probe);

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ProbingGeolocator probe;
  late FakeFirebaseFirestore fakeFirestore;
  late DriverLocationService service;
  final originalPlatform = GeolocatorPlatform.instance;

  setUp(() {
    probe = _ProbingGeolocator();
    GeolocatorPlatform.instance = probe;
    fakeFirestore = FakeFirebaseFirestore();
    service = DriverLocationService(
      fakeFirestore,
      LoggerService(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      ),
      driverUid: 'driver-42',
    );
  });

  tearDown(() async {
    await service.stopTracking();
    await probe.dispose();
    GeolocatorPlatform.instance = originalPlatform;
  });

  Future<void> pumpUntil(bool Function() predicate) async {
    for (var i = 0; i < 50 && !predicate(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<Map<String, dynamic>?> deliveriesData(String orderId) async =>
      (await fakeFirestore.collection('deliveries').doc(orderId).get()).data();

  group('DriverLocationService GPS lifecycle COV-2 (MONEY-3 / STATE-1)', () {
    test(
      'S1: initial publish stamps the driver uid on the deliveries row',
      () async {
        probe.setCurrentPosition(25.2048, 55.2708);
        await service.startTracking('order-1');

        final data = await deliveriesData('order-1');
        expect(data, isNotNull);
        expect(data!['driverId'], 'driver-42');
        expect(data['lat'], 25.2048);
        expect(data['lng'], 55.2708);
        expect(probe.getPositionStreamCalls, 1);
      },
    );

    test(
      'S2: anonymous driver (null uid) writes NO driverId key (defensive MONEY-3)',
      () async {
        final anonymousService = DriverLocationService(
          fakeFirestore,
          LoggerService(
            testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
          ),
        );
        probe.setCurrentPosition(25.0, 55.0);
        await anonymousService.startTracking('order-2');

        final data = await deliveriesData('order-2');
        expect(data, isNotNull);
        expect(data!['lat'], 25.0);
        expect(data.containsKey('driverId'), isFalse);
        await anonymousService.stopTracking();
      },
    );

    test(
      'S3: ghost positions (<20 m) are throttled, real movement publishes',
      () async {
        probe.setCurrentPosition(25.2048, 55.2708);
        final latReads = <double?>[];
        final sub = fakeFirestore
            .collection('deliveries')
            .doc('order-3')
            .snapshots()
            .listen((snap) {
              latReads.add(snap.data()?['lat'] as double?);
            });

        await service.startTracking('order-3');
        // The initial publish above is the baseline — drop its snapshots so the
        // assertions below only observe stream-driven writes.
        latReads.clear();

        // 0-metre movement (same point) must never reach Firestore.
        probe.emit(probe.positionAt(25.2048, 55.2708));
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(
          latReads,
          isEmpty,
          reason: 'a sub-20m ghost position must be throttled (no write)',
        );

        // ~1.2 km laterality must publish exactly once.
        probe.emit(probe.positionAt(25.2150, 55.2708));
        await pumpUntil(() => latReads.isNotEmpty);
        expect(latReads.single, 25.2150);
        unawaited(sub.cancel());
      },
    );
    test(
      'S4: location services disabled -> fail-closed (no read, no stream, no write)',
      () async {
        probe.serviceEnabled = false;
        probe.setCurrentPosition(25.0, 55.0);
        await service.startTracking('order-4');

        expect(probe.getPositionCalls, 0);
        expect(probe.getPositionStreamCalls, 0);
        expect(probe.listenCalls, 0);
        expect(await deliveriesData('order-4'), isNull);
      },
    );

    test('S5: permission denied and request denied -> fail-closed', () async {
      probe.checkPermissionResult = LocationPermission.denied;
      await service.startTracking('order-5');

      expect(probe.getPositionStreamCalls, 0);
      expect(probe.listenCalls, 0);
      expect(await deliveriesData('order-5'), isNull);
    });

    test('S6: deniedForever -> fail-closed', () async {
      probe.checkPermissionResult = LocationPermission.deniedForever;
      await service.startTracking('order-6');

      expect(probe.getPositionStreamCalls, 0);
      expect(probe.listenCalls, 0);
      expect(await deliveriesData('order-6'), isNull);
    });
  });
}
