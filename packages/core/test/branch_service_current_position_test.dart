import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:core/core.dart';

import 'helpers/recording_logger.dart';

/// PERF-8 W2: a fixed-answer geolocator platform double so the permission
/// lattice of [BranchService.currentPosition] is driven deterministically
/// (the platform channel is absent in tests and cannot represent
/// deniedForever / re-request-denied / granted outcomes).
class _FixedGeolocator extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestResult = LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => requestResult;

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final originalPlatform = GeolocatorPlatform.instance;
  late _FixedGeolocator fake;
  late RecordingLogger logger;

  setUp(() {
    fake = _FixedGeolocator();
    GeolocatorPlatform.instance = fake;
    logger = RecordingLogger();
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalPlatform;
  });

  group('BranchService.currentPosition — permission lattice (PERF-8 W2)', () {
    test('returns null while the permission is permanently denied', () async {
      fake.permission = LocationPermission.deniedForever;
      final service = BranchService(FakeFirebaseFirestore(), logger: logger);

      expect(
        await service.currentPosition(),
        isNull,
        reason: 'deniedForever must degrade to null, never crash or throw',
      );
    });

    test(
      're-requests a denied permission and returns null when still denied',
      () async {
        fake.permission = LocationPermission.denied;
        fake.requestResult = LocationPermission.denied;
        final service = BranchService(FakeFirebaseFirestore(), logger: logger);

        expect(
          await service.currentPosition(),
          isNull,
          reason: 'a still-denied re-request must degrade to null',
        );
      },
    );

    test('returns the device fix when the permission is granted', () async {
      fake.permission = LocationPermission.whileInUse;
      final service = BranchService(FakeFirebaseFirestore(), logger: logger);

      final fix = await service.currentPosition();
      expect(fix, isNotNull);
      expect(fix!.latitude, 25.2048);
      expect(fix.longitude, 55.2708);
    });
  });

  group(
    'BranchService.nearestBranch — real geohash query path (PERF-8 W2)',
    () {
      test(
        'resolves the nearest branch through the production fetchWithin query, '
        'including the legacy-coordinates and geo-less doc shapes',
        () async {
          final fake = FakeFirebaseFirestore();
          // The production index shape: geo: {geopoint, geohash} — the query
          // orders by 'geo.geohash' and BranchInfo reads geo.geopoint.
          final near = await fake.collection('branches').add(<String, dynamic>{
            'name': 'Near',
            'geo': const GeoFirePoint(GeoPoint(24.95, 49.95)).data,
            'deliveryRadiusMiles': 5.0,
          });
          await fake.collection('branches').add(<String, dynamic>{
            'name': 'Far',
            'geo': const GeoFirePoint(GeoPoint(25.5, 50.5)).data,
            'deliveryRadiusMiles': 5.0,
          });
          // Legacy shape: a queryable geohash but the position only under
          // `coordinates` — the geopointFrom seam must still find it.
          await fake.collection('branches').add(<String, dynamic>{
            'name': 'Legacy',
            'geo': <String, dynamic>{
              'geohash': const GeoFirePoint(GeoPoint(24.0, 49.0)).geohash,
            },
            'coordinates': const GeoPoint(24.0, 49.0),
            'deliveryRadiusMiles': 5.0,
          });
          // No position anywhere: the parser must fall back to (0,0) without
          // crashing the query.
          await fake.collection('branches').add(<String, dynamic>{
            'name': 'GeoLess',
            'geo': <String, dynamic>{
              'geohash': const GeoFirePoint(GeoPoint(0, 0)).geohash,
            },
            'deliveryRadiusMiles': 5.0,
          });

          final service = BranchService(fake, logger: logger);
          final nearest = await service.nearestBranch(25.0, 50.0);

          expect(
            nearest?.id,
            near.id,
            reason:
                'the real geohash query path must resolve the closest branch '
                '(the override seam tests never exercised this code)',
          );
          expect(nearest?.name, 'Near');
        },
      );
    },
  );
}
