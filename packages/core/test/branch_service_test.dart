import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/recording_logger.dart';

/// CORE-COV LOCATION module test: BranchInfo.fromDoc geo-shape normalization
/// (B4-3), the Haversine distance math, radius containment, and the
/// nearestBranch override seam + persisted-selection prefs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('BranchInfo.fromDoc', () {
    test(
      'parse [lng, lat] coordinates WITHOUT pinning to null island',
      () async {
        final fake = FakeFirebaseFirestore();
        final ref = await fake.collection('branches').add(<String, dynamic>{
          'name': 'Downtown',
          'address': '1 Main St',
          'coordinates': <num>[-122.4194, 37.7749],
          'deliveryRadiusMiles': 3.5,
          'isDefault': true,
        });

        final branch = BranchInfo.fromDoc(
          await fake.collection('branches').doc(ref.id).get(),
        );

        expect(branch.id, ref.id);
        expect(branch.name, 'Downtown');
        expect((branch.lat, branch.lng), (37.7749, -122.4194));
        expect(branch.deliveryRadiusMiles, 3.5);
        expect(branch.isDefault, isTrue);
      },
    );

    test('missing name/radius fall back to the safe defaults', () async {
      final fake = FakeFirebaseFirestore();
      final ref = await fake.collection('branches').add(<String, dynamic>{
        'coordinates': <num>[2.0, 1.0],
      });

      final branch = BranchInfo.fromDoc(
        await fake.collection('branches').doc(ref.id).get(),
      );

      expect(branch.name, '—');
      expect(branch.deliveryRadiusMiles, 5.0);
    });

    test('a non-map doc yields a 0,0 placeholder, never a crash', () async {
      final fake = FakeFirebaseFirestore();
      final ref = await fake.collection('branches').add(<String, dynamic>{
        'x': 1,
      });

      final branch = BranchInfo.fromDoc(
        await fake.collection('branches').doc(ref.id).get(),
      );
      expect((branch.lat, branch.lng), (0.0, 0.0));
    });
  });

  group('BranchService.distanceMiles + isWithinRadius', () {
    test('zero distance and the known 69.1 mi/degree symmetry', () {
      expect(
        BranchService.distanceMiles(25.0, 50.0, 25.0, 50.0),
        closeTo(0.0, 0.001),
      );
      expect(
        BranchService.distanceMiles(26.0, 50.0, 25.0, 50.0),
        closeTo(69.1, 1.0),
      );
    });

    test('isWithinRadius compares against the branch radius', () {
      const branch = BranchInfo(
        id: 'b1',
        name: 'B',
        lat: 25.0,
        lng: 50.0,
        deliveryRadiusMiles: 10.0,
      );
      final branchService = BranchService(
        FakeFirebaseFirestore(),
        logger: RecordingLogger(),
      );
      expect(branchService.isWithinRadius(branch, 25.1, 50.0), isTrue);
      expect(branchService.isWithinRadius(branch, 25.2, 50.0), isFalse);
    });
  });

  group('BranchService.nearestBranch — override seam', () {
    test('returns the CLOSEST branch from the fetched set', () async {
      final fake = FakeFirebaseFirestore();
      await fake.collection('branches').doc('far').set(<String, dynamic>{
        'name': 'Far',
        'coordinates': <num>[50.0, 24.5],
      });
      await fake.collection('branches').doc('near').set(<String, dynamic>{
        'name': 'Near',
        'coordinates': <num>[50.0, 24.9],
      });
      final service = BranchService(
        fake,
        logger: RecordingLogger(),
        fetchBranchesOverride: (lat, lng) async =>
            (await fake.collection('branches').get()).docs,
      );

      final nearest = await service.nearestBranch(25.0, 50.0);

      expect(nearest, isNotNull);
      expect(nearest!.id, 'near');
    });
  });

  group('persisted branch selection', () {
    test(
      'persistSelectedBranch then loadPersistedBranch round-trips; isManualLocation reflects the flag',
      () async {
        final service = BranchService(
          FakeFirebaseFirestore(),
          logger: RecordingLogger(),
        );

        expect(await service.loadPersistedBranch(), isNull);
        expect(await service.isManualLocation(), isFalse);

        await service.persistSelectedBranch('b9', isManual: true);

        expect(await service.loadPersistedBranch(), 'b9');
        expect(await service.isManualLocation(), isTrue);
      },
    );
  });

  // ── PERF-1 (T-6) — remaining seams ───────────────────────────────────────
  group('BranchService.nearestBranch — edge seams (PERF-1)', () {
    test(
      'an EMPTY fetched set yields no nearest (null), never a crash',
      () async {
        final service = BranchService(
          FakeFirebaseFirestore(),
          logger: RecordingLogger(),
          fetchBranchesOverride: (lat, lng) async =>
              <DocumentSnapshot<Object?>>[],
        );

        expect(await service.nearestBranch(25.0, 50.0), isNull);
      },
    );

    test(
      'a fetch failure is logged and RETHROWN (never silently swallowed)',
      () async {
        final logger = RecordingLogger();
        final service = BranchService(
          FakeFirebaseFirestore(),
          logger: logger,
          fetchBranchesOverride: (lat, lng) async =>
              throw StateError('geo backend down'),
        );

        await expectLater(
          service.nearestBranch(25.0, 50.0),
          throwsA(isA<StateError>()),
        );
        expect(logger.errors, contains('BranchService_nearestBranch failed'));
      },
    );
  });

  group('providers (PERF-1)', () {
    test('branchServiceProvider resolves from the DI graph', () {
      final container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          loggerProvider.overrideWithValue(RecordingLogger()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(branchServiceProvider), isA<BranchService>());
    });
  });

  group('currentPosition — geolocator seam (PERF-1)', () {
    test(
      'a platform failure is logged and RETHROWN (the caller decides)',
      () async {
        final logger = RecordingLogger();
        final service = BranchService(FakeFirebaseFirestore(), logger: logger);

        // The geolocator platform channel is absent in tests — the service
        // must contain the failure, log it, and rethrow for the caller.
        await expectLater(service.currentPosition(), throwsA(isA<Exception>()));
        expect(logger.errors, contains('BranchService_currentPosition failed'));
      },
    );
  });
}
