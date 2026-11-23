import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';
import 'package:core/core.dart';

/// Granted-permission geolocator mock (file default): service enabled,
/// whileInUse permission, fixed position. Top-level so the denied-permission
/// test can swap and restore the handler deterministically.
Future<dynamic> grantedGeolocatorHandler(MethodCall methodCall) async {
  switch (methodCall.method) {
    case 'isLocationServiceEnabled':
      return true;
    case 'checkPermission':
      return 3; // LocationPermission.whileInUse
    case 'requestPermission':
      return 3; // LocationPermission.whileInUse
    case 'getCurrentPosition':
      return {
        'latitude': 25.2048,
        'longitude': 55.2708,
        'accuracy': 10.0,
        'altitude': 0.0,
        'speed': 0.0,
        'speed_accuracy': 0.0,
        'heading': 0.0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    default:
      return null;
  }
}

/// Denied-permission mock (PERF-3 T-1): services disabled + permission denied,
/// so startTracking must fail gracefully WITHOUT publishing a tracking row.
Future<dynamic> deniedGeolocatorHandler(MethodCall methodCall) async {
  switch (methodCall.method) {
    case 'isLocationServiceEnabled':
      return false;
    case 'checkPermission':
      return 0; // LocationPermission.denied
    case 'requestPermission':
      return 0; // LocationPermission.denied
    default:
      return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock geolocator platform channel — granted by default.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/geolocator'),
        grantedGeolocatorHandler,
      );

  late FakeFirebaseFirestore fakeFirestore;
  late DriverLocationService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    final logger = LoggerService();
    service = DriverLocationService(fakeFirestore, logger);
  });

  group('DriverLocationService', () {
    test('can be instantiated with Firestore and Logger', () {
      expect(service, isA<DriverLocationService>());
    });

    test(
      'stopTracking is idempotent when NO tracking is active: no writes',
      () async {
        await service.stopTracking();
        await service.stopTracking();

        final rows = await fakeFirestore.collection('deliveries').get();
        expect(
          rows.docs,
          isEmpty,
          reason: 'an inactive stop must never create tracking rows',
        );
      },
    );

    test(
      'startTracking with permission/services DENIED: graceful, NO row',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('flutter.baseflow.com/geolocator'),
              deniedGeolocatorHandler,
            );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('flutter.baseflow.com/geolocator'),
                grantedGeolocatorHandler,
              );
          // The denied path may also touch path_provider (local breadcrumb);
          // point it at the system temp dir and unregister on teardown.
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('plugins.flutter.io/path_provider'),
                null,
              );
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (call) async => Directory.systemTemp.path,
            );

        // Must complete without throwing (graceful permission handling)...
        await service.startTracking('order-denied');

        // ...and must NOT publish a tracking row (nothing to track).
        final rows = await fakeFirestore.collection('deliveries').get();
        expect(
          rows.docs,
          isEmpty,
          reason: 'denied permission must not publish a tracking row',
        );
      },
    );

    test(
      'startTracking stamps the initial delivery row with the injected driver uid (MONEY-3 W3.5/P-2)',
      () async {
        final uidService = DriverLocationService(
          fakeFirestore,
          LoggerService(),
          driverUid: 'uid-123',
        );
        await uidService.startTracking('order-driver-id-1');

        final row = await fakeFirestore
            .collection('deliveries')
            .doc('order-driver-id-1')
            .get();
        expect(
          row.exists,
          isTrue,
          reason: 'initial publish must establish the tracking row',
        );
        expect(
          row.data()?['driverId'],
          'uid-123',
          reason: 'deliveries rows must be uid-stamped for GDPR erasure',
        );
        expect(row.data()?['lat'], 25.2048);
        expect(row.data()?['lng'], 55.2708);
        await uidService.stopTracking();
      },
    );

    test(
      'publishing without a driver uid still writes the row (no driverId key)',
      () async {
        await service.startTracking('order-no-uid');

        final row = await fakeFirestore
            .collection('deliveries')
            .doc('order-no-uid')
            .get();
        expect(row.exists, isTrue);
        expect(
          row.data()!.containsKey('driverId'),
          isFalse,
          reason:
              'null uid must omit the key (row still erases via order-id path)',
        );
        await service.stopTracking();
      },
    );
  });
}
