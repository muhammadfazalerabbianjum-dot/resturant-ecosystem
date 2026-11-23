import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('BranchService.distanceMiles', () {
    test('same coordinates = 0 miles', () {
      final dist = BranchService.distanceMiles(
        40.7128,
        -74.0060,
        40.7128,
        -74.0060,
      );
      expect(dist, closeTo(0, 0.01));
    });

    test('London to NY approx 3440 miles', () {
      // Using known Haversine calculation independently
      // London: 51.5074ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â° N, 0.1278ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â° W, NY: 40.7128ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â° N, 74.0060ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â° W
      final dist = BranchService.distanceMiles(
        51.5074,
        -0.1278,
        40.7128,
        -74.0060,
      );
      expect(dist, greaterThan(3000));
      expect(dist, lessThan(4000));
    });

    test('small distance within NYC blocks approx 0.6 miles', () {
      // 42nd St to 14th St in Manhattan (~1.4 miles lat diff ~0.06 deg)
      final dist = BranchService.distanceMiles(
        40.7527,
        -73.9772,
        40.7370,
        -73.9900,
      );
      expect(dist, greaterThan(0.5));
      expect(dist, lessThan(1.5));
    });

    test('commutative property holds', () {
      final d1 = BranchService.distanceMiles(
        34.0522,
        -118.2437,
        36.1699,
        -115.1398,
      );
      final d2 = BranchService.distanceMiles(
        36.1699,
        -115.1398,
        34.0522,
        -118.2437,
      );
      expect(d1, closeTo(d2, 0.001));
    });

    test('antipodal points approx 12450 miles (half earth circumference)', () {
      // Equator point (0,0) and antipode (0,180)
      final dist = BranchService.distanceMiles(0, 0, 0, 180);
      // Half circumference = pi * 3958.8 ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Â¹ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â  12436 miles
      expect(dist, greaterThan(12000));
      expect(dist, lessThan(13000));
    });
  });

  group('BranchService.nearestBranch', () {
    test('returns null when override returns empty', () async {
      final service = BranchService(
        FakeFirebaseFirestore(),
        logger: LoggerService(),
        fetchBranchesOverride: (lat, lng) async => [],
      );
      final result = await service.nearestBranch(40.7128, -74.0060);
      expect(result, isNull);
    });

    test('returns nearest branch from override list', () async {
      final firestore = FakeFirebaseFirestore();
      // Add two branches - one closer to user
      await firestore.collection('branches').add({
        'name': 'Far Branch',
        'lat': 40.7500,
        'lng': -73.9900,
        'deliveryRadiusMiles': 5.0,
        'isDefault': false,
      });
      await firestore.collection('branches').add({
        'name': 'Near Branch',
        'lat': 40.7130, // Very close to user at 40.7128
        'lng': -74.0065,
        'deliveryRadiusMiles': 5.0,
        'isDefault': true,
      });

      final service = BranchService(
        firestore,
        logger: LoggerService(),
        fetchBranchesOverride: (lat, lng) async {
          final snap = await firestore.collection('branches').get();
          return snap.docs;
        },
      );
      final result = await service.nearestBranch(40.7128, -74.0060);
      expect(result, isNotNull);
      expect(result!.name, 'Near Branch');
    });
  });

  group('BranchService.isWithinRadius', () {
    test('point within 1 mile radius returns true', () {
      final firestore = FakeFirebaseFirestore();
      final service = BranchService(firestore, logger: LoggerService());
      // Branch at (40.7128, -74.0060) with 1 mile radius
      const branch = BranchInfo(
        id: 'b1',
        name: 'Test',
        lat: 40.7128,
        lng: -74.0060,
        deliveryRadiusMiles: 1.0,
      );
      // ~0.5 miles south
      final result = service.isWithinRadius(branch, 40.7200, -74.0060);
      expect(result, isTrue);
    });

    test('outside radius returns false', () {
      final firestore = FakeFirebaseFirestore();
      final service = BranchService(firestore, logger: LoggerService());
      const branch = BranchInfo(
        id: 'b1',
        name: 'Test',
        lat: 40.7128,
        lng: -74.0060,
        deliveryRadiusMiles: 1.0,
      );
      // ~2 miles north = outside 1 mile radius
      final result = service.isWithinRadius(branch, 40.7400, -74.0060);
      expect(result, isFalse);
    });

    test('zero radius only matches exact location', () {
      final firestore = FakeFirebaseFirestore();
      final service = BranchService(firestore, logger: LoggerService());
      const branch = BranchInfo(
        id: 'b1',
        name: 'Test',
        lat: 40.0,
        lng: -74.0,
        deliveryRadiusMiles: 0.0,
      );
      expect(service.isWithinRadius(branch, 40.0, -74.0), isTrue);
      expect(service.isWithinRadius(branch, 40.001, -74.0), isFalse);
    });
  });

  group('BranchService SharedPreferences', () {
    test('persistSelectedBranch and loadPersistedBranch roundtrip', () async {
      SharedPreferences.setMockInitialValues({});
      final service = BranchService(
        FakeFirebaseFirestore(),
        logger: LoggerService(),
      );
      await service.persistSelectedBranch('branch_123', isManual: true);
      final loaded = await service.loadPersistedBranch();
      expect(loaded, 'branch_123');
    });

    test('isManualLocation returns false when not set', () async {
      SharedPreferences.setMockInitialValues({});
      final service = BranchService(
        FakeFirebaseFirestore(),
        logger: LoggerService(),
      );
      final isManual = await service.isManualLocation();
      expect(isManual, isFalse);
    });

    test('isManualLocation returns true when set', () async {
      SharedPreferences.setMockInitialValues({});
      final service = BranchService(
        FakeFirebaseFirestore(),
        logger: LoggerService(),
      );
      await service.persistSelectedBranch('branch_123', isManual: true);
      final isManual = await service.isManualLocation();
      expect(isManual, isTrue);
    });

    test('loadPersistedBranch returns null when no branch persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final service = BranchService(
        FakeFirebaseFirestore(),
        logger: LoggerService(),
      );
      final loaded = await service.loadPersistedBranch();
      expect(loaded, isNull);
    });
  });

  group('BranchInfo', () {
    test('fromDoc parses GeoPoint coordinates', () async {
      final firestore = FakeFirebaseFirestore();
      final docRef = firestore.collection('branches').doc('doc1');
      await docRef.set({
        'name': 'Test',
        'address': '123 St',
        'coordinates': const GeoPoint(40.71, -74.00),
        'deliveryRadiusMiles': 5.0,
        'isActive': true,
        'isDefault': false,
      });
      final doc = await docRef.get();
      final info = BranchInfo.fromDoc(doc);
      expect(info.lat, 40.71);
      expect(info.lng, -74.00);
      expect(info.name, 'Test');
    });

    test('fromDoc parses lat/lng fields as fallback', () async {
      final firestore = FakeFirebaseFirestore();
      final docRef = firestore.collection('branches').doc('doc1');
      await docRef.set({
        'name': 'Fallback Branch',
        'lat': 34.05,
        'lng': -118.24,
        'deliveryRadiusMiles': 10.0,
        'isDefault': true,
      });
      final doc = await docRef.get();
      final info = BranchInfo.fromDoc(doc);
      expect(info.lat, 34.05);
      expect(info.lng, -118.24);
      expect(info.isDefault, isTrue);
    });

    test('fromDoc defaults for missing fields', () async {
      final firestore = FakeFirebaseFirestore();
      final docRef = firestore.collection('branches').doc('doc1');
      await docRef.set({'name': 'Minimal'});
      final doc = await docRef.get();
      final info = BranchInfo.fromDoc(doc);
      expect(info.lat, 0);
      expect(info.lng, 0);
      expect(info.deliveryRadiusMiles, 5.0);
      expect(info.isDefault, isFalse);
    });
  });
}
