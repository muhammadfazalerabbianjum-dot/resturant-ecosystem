// P8 W4 (A-4 / T4) — merged_menu_provider behaviour pins.
//
// Every test here drives the REAL provider against a fake Firestore and
// asserts an observable outcome (item identity, availability, category
// resolution, query re-subscription). No runtimeType/toString assertions.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';

import '../../../helpers/test_helpers.dart';

/// Branch service that never touches shared_preferences (test seam).
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

/// No persisted branch and no `branches` document → the notifier stays null,
/// so the provider deterministically takes the global-only path.
class _NoBranchService extends BranchService {
  _NoBranchService(super.db, {required super.logger});

  @override
  Future<String?> loadPersistedBranch() async => null;

  @override
  Future<void> persistSelectedBranch(
    String branchId, {
    bool isManual = false,
  }) async {}
}

/// The branch is resolved synchronously so the merged stream deterministically
/// takes one path — no async race on [mergedMenuProvider.future].
class _ResolvedBranchNotifier extends CurrentBranchNotifier {
  _ResolvedBranchNotifier(super.db, super.branchService, String? branch) {
    state = branch;
  }
}

/// Counts collection resolutions so a test can prove that `invalidate()`
/// rebuilds the menu queries instead of reusing a stale subscription.
class _CountingFirestore extends FakeFirebaseFirestore {
  final Map<String, int> collectionsRequested = <String, int>{};

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    collectionsRequested[path] = (collectionsRequested[path] ?? 0) + 1;
    return super.collection(path);
  }
}

ProviderContainer _container(
  FakeFirebaseFirestore firestore, {
  required String? branch,
}) {
  final container = ProviderContainer(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      // P9 W1 (T-3): the override overlay watches loggerProvider for its
      // fail-soft telemetry — inject the fake (the real LoggerService init
      // needs the path_provider channel, absent in widget tests).
      loggerProvider.overrideWithValue(FakeLogger()),
      currentBranchIdProvider.overrideWith(
        (ref) => _ResolvedBranchNotifier(
          firestore,
          branch == null
              ? _NoBranchService(firestore, logger: FakeLogger())
              : _StickyBranchService(firestore, logger: FakeLogger()),
          branch,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// A GLOBAL menu doc — no `branchId` field, so it matches
/// `where('branchId', isNull: true)`.
Future<void> _globalItem(
  FakeFirebaseFirestore firestore,
  String id,
  Map<String, dynamic> data,
) => firestore.collection('menus').doc(id).set(data);

/// A BRANCH-scoped menu doc — the override stream's shape.
Future<void> _branchItem(
  FakeFirebaseFirestore firestore,
  String id,
  String branchId,
  Map<String, dynamic> data,
) => firestore.collection('menus').doc(id).set(<String, dynamic>{
  ...data,
  'branchId': branchId,
});

void main() {
  group('mergedMenuProvider — merge + category resolution', () {
    test('a branch-scoped item and a global item are emitted as two rows (a '
        'document id can only appear once per collection, so the branch copy '
        'never overrides its global sibling)', () async {
      final firestore = FakeFirebaseFirestore();
      await _globalItem(firestore, 'burger', {
        'name': 'Burger',
        'priceCents': 1000,
      });
      await _branchItem(firestore, 'burger-b1', 'b1', {
        'name': 'Burger (branch)',
        'priceCents': 1200,
      });

      final container = _container(firestore, branch: 'b1');
      final items = await container.read(mergedMenuProvider.future);

      expect(
        items.map((i) => i.id).toSet(),
        {'burger', 'burger-b1'},
        reason:
            'P8-W4: both documents are distinct rows. The merge branch '
            '(merged_menu_provider.dart:161-162) keys overrides by the '
            'Firestore document id, which is unique per collection — so a '
            'branch override can never collide with a global item.',
      );
    });

    test('an item with an empty category resolves to its first tag, and to '
        '"General" when it has no tags', () async {
      final firestore = FakeFirebaseFirestore();
      await _globalItem(firestore, 'tagged', {
        'name': 'Cola',
        'priceCents': 300,
        'category': '',
        'tags': ['Drinks', 'Cold'],
      });
      await _globalItem(firestore, 'untagged', {
        'name': 'Mystery',
        'priceCents': 400,
        'category': '',
        'tags': <String>[],
      });

      final container = _container(firestore, branch: null);
      final items = await container.read(mergedMenuProvider.future);

      expect(
        items.firstWhere((i) => i.id == 'tagged').category,
        'Drinks',
        reason: 'empty category falls back to the first tag',
      );
      expect(
        items.firstWhere((i) => i.id == 'untagged').category,
        'General',
        reason: 'no category and no tags must never reach the UI as ""',
      );
    });

    test(
      'quantityRemaining and modifier options survive the domain mapping and '
      'an empty image url becomes null',
      () async {
        final firestore = FakeFirebaseFirestore();
        await _globalItem(firestore, 'pizza', {
          'name': 'Pizza',
          'priceCents': 1200,
          'description': 'Cheesy',
          'imageUrl': '',
          'quantityRemaining': 7,
          'modifiers': [
            {
              'id': 'mod-size',
              'name': 'Size',
              'isRequired': true,
              'allowMultiple': false,
              'options': [
                {'id': 'opt-l', 'name': 'Large', 'upchargeCents': 200},
              ],
            },
          ],
        });

        final container = _container(firestore, branch: null);
        final item = (await container.read(mergedMenuProvider.future)).single;

        expect(item.imageUrl, isNull);
        expect(item.quantityRemaining, 7);
        expect(item.modifiers.single.name, 'Size');
        expect(item.modifiers.single.options.single.upchargeCents, 200);
      },
    );
  });

  group('mergedMenuProvider — availability masking', () {
    test('the branch path keeps an out-of-stock item so the owner surface can '
        'find and re-enable it', () async {
      final firestore = FakeFirebaseFirestore();
      await _globalItem(firestore, 'soup', {
        'name': 'Soup',
        'priceCents': 500,
        'isAvailable': true,
      });
      await _globalItem(firestore, 'pie', {
        'name': 'Pie',
        'priceCents': 900,
        'isAvailable': false,
      });

      final container = _container(firestore, branch: 'b1');
      final items = await container.read(mergedMenuProvider.future);

      expect(
        items.map((i) => i.id).toSet(),
        {'soup', 'pie'},
        reason:
            'P8-W4 F1: admin_menu_manager.dart:24 renders this stream and '
            'shows an out-of-stock badge (admin_menu_manager.dart:48-58); '
            'masking here made re-enabling a dish impossible once a branch '
            'was selected. Customers are masked downstream instead '
            '(menu_screen.dart:235, home_service.dart:57, '
            'cart_validator_service.dart:97).',
      );
      expect(items.firstWhere((i) => i.id == 'pie').isAvailable, isFalse);
    });

    test('the global-only path emits the same item set as the branch path — '
        'masking is not path-dependent', () async {
      final firestore = FakeFirebaseFirestore();
      await _globalItem(firestore, 'soup', {
        'name': 'Soup',
        'priceCents': 500,
        'isAvailable': true,
      });
      await _globalItem(firestore, 'pie', {
        'name': 'Pie',
        'priceCents': 900,
        'isAvailable': false,
      });

      final container = _container(firestore, branch: null);
      final items = await container.read(mergedMenuProvider.future);

      expect(items.map((i) => i.id).toSet(), {'soup', 'pie'});
    });
  });

  group('mergedMenuProvider — cache invalidation', () {
    test(
      'invalidate() re-subscribes the menu queries and surfaces an item added '
      'after the first read',
      () async {
        final firestore = _CountingFirestore();
        await _branchItem(firestore, 'b-1', 'b1', {
          'name': 'First',
          'priceCents': 100,
        });

        final container = _container(firestore, branch: 'b1');
        final before = await container.read(mergedMenuProvider.future);
        expect(before.map((i) => i.id), ['b-1']);
        final buildsBefore = firestore.collectionsRequested['menus'] ?? 0;

        await _branchItem(firestore, 'b-2', 'b1', {
          'name': 'Second',
          'priceCents': 200,
        });
        container.invalidate(mergedMenuProvider);

        final after = await container.read(mergedMenuProvider.future);
        expect(after.map((i) => i.id).toSet(), {'b-1', 'b-2'});
        expect(
          firestore.collectionsRequested['menus'],
          greaterThan(buildsBefore),
          reason:
              'home_screen.dart:433 refreshes the menu with '
              'ref.invalidate(mergedMenuProvider) — that must rebuild the '
              'Firestore queries, not reuse the previous subscription.',
        );
      },
    );
  });

  group('resolveEffectiveBranchId', () {
    testWidgets(
      'fails closed (null) when no branch is selected and no client default '
      'branch is configured — never a hardcoded branch id',
      (tester) async {
        AppConfig.resetForTest();
        Object? resolved = 'sentinel';

        final firestore = FakeFirebaseFirestore();
        await tester.pumpWidget(
          ProviderScope(
            // No live Firebase in unit tests: the resolver reads
            // currentBranchIdProvider, which needs an injected Firestore.
            overrides: [
              firestoreProvider.overrideWithValue(firestore),
              currentBranchIdProvider.overrideWith(
                (ref) => _ResolvedBranchNotifier(
                  firestore,
                  _NoBranchService(firestore, logger: FakeLogger()),
                  null,
                ),
              ),
            ],
            child: Consumer(
              builder: (context, ref, child) {
                resolved = resolveEffectiveBranchId(ref, FakeLogger());
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(
          resolved,
          isNull,
          reason:
              'merged_menu_provider.dart:113 — with no current branch and no '
              'configured default the resolver returns null so callers fail '
              'closed instead of writing under a made-up branch id',
        );
      },
    );
  });
}
