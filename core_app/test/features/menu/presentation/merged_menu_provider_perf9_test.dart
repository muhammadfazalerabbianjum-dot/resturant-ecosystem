// P9 W1 (T-3) — per-branch menu override overlay.
//
// B-3 (PERF-8 W4-2): the branch-override merge in mergedMenuProvider keyed by
// Firestore doc id can NEVER match a global item (doc ids are unique), so
// per-branch price/availability overrides were structurally unreachable. The
// fixed schema (spec §3 T-3): `branches/{bid}/menu_overrides/{canonicalItemId}`
// carrying `{priceCents?, isAvailable?}` — additive, no migration. The merge
// keys by DOMAIN id (override doc id == canonical item id); absence of an
// override doc (or of a field in it) = inherit the global item.
//
// Consumer contract (proven in PERF-8 W4): `menu_screen.dart:235` /
// `dish_detail_screen.dart:97` render the sold-out mask off `isAvailable`, so
// an `isAvailable:false` override must arrive as a MASKED row (still emitted —
// the owner surface re-enables it), never dropped.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// No persisted branch → the provider deterministically takes the
/// global-only path (overrides never consulted without a branch).
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

/// Firestore double that DENIES exactly the menu_overrides subcollection —
/// the realistic degradation shape: the global `menus` reads stay allowed
/// while the override lane is closed (rules handoff) or offline. The denial
/// is intercepted at `branches/{bid}.collection('menu_overrides')` because a
/// subcollection read does NOT round-trip through `db.collection()`.
class _DeniedOverridesFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    if (path == 'branches') {
      return _BranchesRefDenyingOverrides(super.collection(path));
    }
    return super.collection(path);
  }
}

// ignore: subtype_of_sealed_class
class _BranchesRefDenyingOverrides
    implements CollectionReference<Map<String, dynamic>> {
  _BranchesRefDenyingOverrides(this._inner);

  final CollectionReference<Map<String, dynamic>> _inner;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _DenyingDocRef(_inner.doc(path));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected call on branches ref: $invocation');
}

// ignore: subtype_of_sealed_class
class _DenyingDocRef implements DocumentReference<Map<String, dynamic>> {
  _DenyingDocRef(this._inner);

  final DocumentReference<Map<String, dynamic>> _inner;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    if (path == 'menu_overrides') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'menu_overrides is not readable for this caller',
      );
    }
    return _inner.collection(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected call on branch doc ref: $invocation');
}

ProviderContainer _container(
  FakeFirebaseFirestore firestore, {
  required String? branch,
}) {
  final container = ProviderContainer(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
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

Future<void> _globalItem(
  FakeFirebaseFirestore firestore,
  String id,
  Map<String, dynamic> data,
) => firestore.collection('menus').doc(id).set(data);

/// An override doc — the doc ID is the canonical (global) item id.
Future<void> _menuOverride(
  FakeFirebaseFirestore firestore,
  String branchId,
  String canonicalItemId,
  Map<String, dynamic> data,
) => firestore
    .collection('branches')
    .doc(branchId)
    .collection('menu_overrides')
    .doc(canonicalItemId)
    .set(data);

void main() {
  group('mergedMenuProvider — menu_overrides overlay (T-3)', () {
    test('an override doc keyed by the canonical id WINS over the global item; '
        'absence of an override doc inherits the global item', () async {
      final firestore = FakeFirebaseFirestore();
      await _globalItem(firestore, 'soup', {
        'name': 'Soup',
        'priceCents': 500,
        'isAvailable': true,
      });
      await _globalItem(firestore, 'pie', {
        'name': 'Pie',
        'priceCents': 900,
        'isAvailable': true,
      });
      await _menuOverride(firestore, 'b1', 'soup', {'priceCents': 700});

      final items = await _container(
        firestore,
        branch: 'b1',
      ).read(mergedMenuProvider.future);

      final soup = items.singleWhere((i) => i.id == 'soup');
      expect(
        soup.priceCents,
        700,
        reason:
            'B-3: the merge is keyed by the canonical item id — the branch '
            'price override must win over the global item',
      );
      final pie = items.singleWhere((i) => i.id == 'pie');
      expect(
        pie.priceCents,
        900,
        reason: 'absence of an override doc = inherit the global item',
      );
    });

    test('isAvailable:false via override arrives as a masked row — still '
        'emitted (the owner surface re-enables it), never dropped', () async {
      final firestore = FakeFirebaseFirestore();
      await _globalItem(firestore, 'soup', {
        'name': 'Soup',
        'priceCents': 500,
        'isAvailable': true,
      });
      await _menuOverride(firestore, 'b1', 'soup', {'isAvailable': false});

      final items = await _container(
        firestore,
        branch: 'b1',
      ).read(mergedMenuProvider.future);

      final soup = items.singleWhere((i) => i.id == 'soup');
      expect(
        soup.isAvailable,
        isFalse,
        reason:
            'menu_screen.dart:235 / dish_detail_screen.dart:97 render the '
            'sold-out mask off this flag (PERF-8 W4 consumer contract)',
      );
      expect(items.map((i) => i.id), contains('soup'));
    });

    test('an override doc with only SOME fields set inherits the rest '
        'per-field', () async {
      final firestore = FakeFirebaseFirestore();
      await _globalItem(firestore, 'soup', {
        'name': 'Soup',
        'priceCents': 500,
        'isAvailable': true,
      });
      await _menuOverride(firestore, 'b1', 'soup', {'isAvailable': false});

      final items = await _container(
        firestore,
        branch: 'b1',
      ).read(mergedMenuProvider.future);

      final soup = items.singleWhere((i) => i.id == 'soup');
      expect(soup.priceCents, 500, reason: 'priceCents absent in the override');
      expect(soup.isAvailable, isFalse);
    });

    test('a malformed override field value inherits the global value '
        '(fail-closed to inherit, never crashes the menu)', () async {
      final firestore = FakeFirebaseFirestore();
      await _globalItem(firestore, 'soup', {
        'name': 'Soup',
        'priceCents': 500,
        'isAvailable': true,
      });
      await _menuOverride(firestore, 'b1', 'soup', {
        'priceCents': 'not-a-number',
        'isAvailable': 'definitely-not-a-bool',
      });

      final items = await _container(
        firestore,
        branch: 'b1',
      ).read(mergedMenuProvider.future);

      final soup = items.singleWhere((i) => i.id == 'soup');
      expect(soup.priceCents, 500);
      expect(soup.isAvailable, isTrue);
    });

    test('the override stream degrading (rules lane closed / offline) inherits '
        'the global menu instead of erroring the whole menu path', () async {
      final logger = FakeLogger();
      final denied = _DeniedOverridesFirestore();
      await denied.collection('menus').doc('soup').set({
        'name': 'Soup',
        'priceCents': 500,
        'isAvailable': true,
      });
      final container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(denied),
          loggerProvider.overrideWithValue(logger),
          currentBranchIdProvider.overrideWith(
            (ref) => _ResolvedBranchNotifier(
              denied,
              _StickyBranchService(denied, logger: FakeLogger()),
              'b1',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(mergedMenuProvider.future);

      expect(items.single.id, 'soup');
      expect(
        items.single.priceCents,
        500,
        reason:
            'the override lane failing must leave the global menu LIVE '
            '(fail-soft inheritance), never error the whole menu path',
      );
      expect(
        logger.loggedErrors.where((m) => m.contains('menu_overrides')),
        isNotEmpty,
        reason: 'the degradation must be visible in telemetry, never silent',
      );
    });

    test('no branch selected → overrides are never consulted (global path '
        'stays pure)', () async {
      final firestore = FakeFirebaseFirestore();
      await _globalItem(firestore, 'soup', {
        'name': 'Soup',
        'priceCents': 500,
        'isAvailable': true,
      });
      await _menuOverride(firestore, 'b1', 'soup', {'priceCents': 999});

      final items = await _container(
        firestore,
        branch: null,
      ).read(mergedMenuProvider.future);

      expect(items.single.priceCents, 500);
    });
  });
}
