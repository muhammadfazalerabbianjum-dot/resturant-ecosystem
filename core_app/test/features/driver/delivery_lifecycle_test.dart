import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:labs/features/admin/domain/delivery_service.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';
import '../../helpers/test_helpers.dart';
import '../../support/tenant_claim_fakes.dart';

/// COV-2 deterministic geolocator fake used to observe the GPS lifecycle that
/// the delivery dashboard drives through [DeliveryService]: streams opened,
/// subscriptions taken and cancellations issued. The GPS write/read behavior
/// itself is covered in driver_location_stamping_test.dart.
class _ProbingGeolocator extends GeolocatorPlatform {
  final StreamController<Position> _controller =
      StreamController<Position>.broadcast();

  int getPositionStreamCalls = 0;
  int listenCalls = 0;
  int cancelCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
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
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => 0;

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
  late DriverLocationService locationService;
  late DeliveryService service;
  late List<String> timeline;
  late RecordingSyncQueue syncQueue;
  final originalPlatform = GeolocatorPlatform.instance;

  setUp(() {
    probe = _ProbingGeolocator();
    GeolocatorPlatform.instance = probe;
    fakeFirestore = FakeFirebaseFirestore();
    locationService = DriverLocationService(
      fakeFirestore,
      LoggerService(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      ),
      driverUid: 'driver-1',
    );
    timeline = <String>[];
    syncQueue = RecordingSyncQueue(events: timeline);
    service = DeliveryService(
      firestore: fakeFirestore,
      locationService: locationService,
      logger: LoggerService(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      ),
      syncQueue: syncQueue,
      tenantClaim: const FixedTenantClaim(),
    );
  });

  tearDown(() async {
    await service.stopGpsTracking();
    await probe.dispose();
    GeolocatorPlatform.instance = originalPlatform;
  });

  Future<void> seedOrder(
    String orderId, {
    String status = 'ready',
    String? assignedDriverId,
  }) async {
    final data = <String, dynamic>{
      'branchId': 'branch-1',
      'status': status,
      'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
      'totalCents': 1000,
      'items': <Map<String, dynamic>>[],
    };
    if (assignedDriverId != null) {
      data['assignedDriverId'] = assignedDriverId;
    }
    await fakeFirestore.collection('orders').doc(orderId).set(data);
    timeline.clear();
  }

  Future<Map<String, dynamic>?> orderData(String orderId) async =>
      (await fakeFirestore.collection('orders').doc(orderId).get()).data();

  group('DeliveryService dashboard integration COV-2 (STATE-1 W8.3)', () {
    test(
      'A1: assignToMe claims a ready order (pickedUp + driverId stamped)',
      () async {
        await seedOrder('life-a');

        await service.assignToMe('life-a', 'driver-1');

        final data = await orderData('life-a');
        expect(data!['status'], 'pickedUp');
        expect(data['assignedDriverId'], 'driver-1');
        expect(
          syncQueue.enqueuedPayloads.single,
          {
            'id': 'life-a',
            'assignedDriverId': 'driver-1',
            'status': 'pickedUp',
          },
          reason:
              'the queued claim must be EXACTLY the rules-legal claim shape',
        );
        expect(syncQueue.pendingPayloads, isEmpty);
        expect(timeline.last, 'remove:update:life-a');
      },
    );

    test(
      'A2: a claim on an already-assigned order fails closed and never enqueues',
      () async {
        await seedOrder('life-b', assignedDriverId: 'other-driver');

        await expectLater(
          service.assignToMe('life-b', 'driver-1'),
          throwsA(predicate((e) => e.toString().contains('already assigned'))),
        );

        expect(syncQueue.enqueuedPayloads, isEmpty);
        final data = await orderData('life-b');
        expect(data!['status'], 'ready');
        expect(data['assignedDriverId'], 'other-driver');
      },
    );

    test(
      'A3: STATE-1 guard — ready -> delivered is rejected, GPS keeps running',
      () async {
        await seedOrder('life-c');
        await service.startGpsTracking('life-c');
        expect(probe.listenCalls, 1);

        await expectLater(
          service.markDelivered('life-c'),
          throwsA(
            predicate(
              (e) =>
                  e.toString().contains('Invalid status transition') &&
                  e.toString().contains('ready -> delivered'),
            ),
          ),
        );

        final data = await orderData('life-c');
        expect(data!['status'], 'ready');
        expect(
          probe.cancelCalls,
          0,
          reason: 'a rejected transition must never stop the GPS session',
        );
        expect(syncQueue.enqueuedPayloads, isEmpty);
      },
    );

    test(
      'A4: full lifecycle claim -> GPS -> markDelivered stops GPS after commit',
      () async {
        await seedOrder('life-d');

        await service.assignToMe('life-d', 'driver-1');
        await service.startGpsTracking('life-d');
        expect(probe.listenCalls, 1);

        await service.markDelivered('life-d');

        final data = await orderData('life-d');
        expect(data!['status'], 'delivered');
        expect(
          probe.cancelCalls,
          1,
          reason: 'GPS stops once delivered commits',
        );
        expect(syncQueue.pendingPayloads, isEmpty);
      },
    );

    test(
      'A5: markDelivered on a missing order fails closed and never enqueues',
      () async {
        await expectLater(
          service.markDelivered('life-missing'),
          throwsA(isA<FirebaseException>()),
        );

        expect(syncQueue.enqueuedPayloads, isEmpty);
        expect(probe.cancelCalls, 0);
      },
    );
  });
}
