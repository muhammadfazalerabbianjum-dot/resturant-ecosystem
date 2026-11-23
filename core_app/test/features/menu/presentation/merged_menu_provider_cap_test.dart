import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/menu/data/menu_repository.dart'
    show kMenuMaxItemsSafetyCap;
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import '../../../helpers/test_helpers.dart';

/// Returns a fixed branch synchronously so the provider deterministically
/// takes the branch path — no async race on [mergedMenuProvider.future].
class _BranchNotifier extends CurrentBranchNotifier {
  _BranchNotifier(super.db, super.branchService) {
    state = 'b1';
  }
}

/// [BranchService] that never touches shared prefs in tests.
class _StickyBranchService extends BranchService {
  _StickyBranchService(super.db, {required super.logger});

  @override
  Future<String?> loadPersistedBranch() async => 'b1';

  @override
  Future<void> persistSelectedBranch(
    String branchId, {
    bool isManual = false,
  }) async {}
}

Future<void> _seedMenus(
  FirebaseFirestore firestore, {
  String? branchId,
  required int count,
}) async {
  // fake_cloud_firestore (and Firestore itself) caps batches at 500 tasks —
  // chunk the seed so >500 docs never land in one commit.
  for (var start = 0; start < count; start += 400) {
    final batch = firestore.batch();
    final end = (start + 400).clamp(0, count);
    for (var i = start; i < end; i++) {
      batch.set(firestore.collection('menus').doc('${branchId ?? 'g'}-o$i'), {
        'name': 'Item $i',
        'priceCents': 999,
        'isAvailable': true,
        if (branchId != null) 'branchId': branchId,
      });
    }
    await batch.commit();
  }
}

void main() {
  group('mergedMenuProvider — W8.7 menu caps (T-2 query-fixture corpus)', () {
    test('global stream caps at kMenuMaxItemsSafetyCap (500)', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedMenus(firestore, count: kMenuMaxItemsSafetyCap + 20);

      final container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          loggerProvider.overrideWithValue(FakeLogger()),
          currentBranchIdProvider.overrideWith(
            (ref) => _BranchNotifier(
              firestore,
              _StickyBranchService(firestore, logger: FakeLogger()),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(mergedMenuProvider.future);

      expect(
        items.length,
        kMenuMaxItemsSafetyCap,
        reason:
            'W8.7: the global menus stream (merged_menu_provider.dart) '
            'must be hard-capped at kMenuMaxItemsSafetyCap',
      );
    });

    test(
      'branch-override stream caps at kMenuMaxItemsSafetyCap (500)',
      () async {
        final firestore = FakeFirebaseFirestore();
        await _seedMenus(
          firestore,
          branchId: 'b1',
          count: kMenuMaxItemsSafetyCap + 20,
        );

        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(firestore),
            loggerProvider.overrideWithValue(FakeLogger()),
            currentBranchIdProvider.overrideWith(
              (ref) => _BranchNotifier(
                firestore,
                _StickyBranchService(firestore, logger: FakeLogger()),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final items = await container.read(mergedMenuProvider.future);

        expect(
          items.length,
          kMenuMaxItemsSafetyCap,
          reason:
              'W8.7: the branch menus stream (merged_menu_provider.dart) '
              'must be hard-capped at kMenuMaxItemsSafetyCap',
        );
      },
    );
  });
}
