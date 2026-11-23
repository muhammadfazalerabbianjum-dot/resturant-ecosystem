import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/domain/menu_modifier_model.dart';
import 'package:rxdart/rxdart.dart';

import '../../admin/domain/menu_item_model.dart' as admin_model;
import '../data/menu_repository.dart' show kMenuMaxItemsSafetyCap;

/// Watches the selected branch ID
final currentBranchIdProvider =
    StateNotifierProvider<CurrentBranchNotifier, String?>((ref) {
      // Inject the Firestore instance and BranchService (never a direct static
      // Firestore instance / inline `LoggerService()` in feature
      // code — rule 5 grep gate + testability).
      return CurrentBranchNotifier(
        ref.watch(firestoreProvider),
        ref.watch(branchServiceProvider),
      );
    });

class CurrentBranchNotifier extends StateNotifier<String?> {
  final FirebaseFirestore _db;
  final BranchService _branchService;

  CurrentBranchNotifier(this._db, this._branchService) : super(null) {
    _init();
  }

  Future<void> _init() async {
    final svc = _branchService;
    final persisted = await svc.loadPersistedBranch();
    if (persisted != null) {
      state = persisted;
      return;
    }
    try {
      QuerySnapshot<Map<String, dynamic>>? snap;

      snap = await _db
          .collection('branches')
          .where('isMainBranch', isEqualTo: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        snap = await _db
            .collection('branches')
            .where('isDefault', isEqualTo: true)
            .limit(1)
            .get();
      }

      if (snap.docs.isEmpty) {
        snap = await _db.collection('branches').limit(1).get();
      }

      if (snap.docs.isNotEmpty) {
        final id = snap.docs.first.id;
        state = id;
        await svc.persistSelectedBranch(id, isManual: false);
      }
    } catch (e, stack) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          fatal: false,
          information: ['context=CurrentBranchNotifier._init'],
        ),
      );
    }
  }

  void setBranch(String branchId) {
    state = branchId;
    unawaited(_branchService.persistSelectedBranch(branchId, isManual: true));
  }
}

/// Resolves the effective branch id for a feature screen.
///
/// B4-2: a branch id must NEVER be a hardcoded string literal in a screen.
/// Resolution order:
///  1. [currentBranchIdProvider] (the real, user-selected/auto-detected branch)
///  2. the client config's declared default branch id
///     ([AppConfig.defaultBranchId], NOT `'main'`/`'default'`)
///  3. null — the caller fails closed instead of silently writing under a
///     made-up branch id.
///
/// Every fallback to the config default is logged once (via [logger]) so
/// misconfiguration is visible in telemetry instead of silently "working".
String? resolveEffectiveBranchId(WidgetRef ref, LoggerService logger) {
  final current = ref.read(currentBranchIdProvider);
  if (current != null) return current;
  final configuredDefault = AppConfig.defaultBranchId;
  if (configuredDefault.isNotEmpty) {
    unawaited(
      logger.warn(
        StateError(
          'currentBranchIdProvider was null; using configured default branch '
          '"$configuredDefault"',
        ),
        'branch fallback used',
      ),
    );
    return configuredDefault;
  }
  return null;
}

/// P9 W1 (T-3): one per-branch override, keyed by the canonical (global)
/// menu item id. Schema: `branches/{bid}/menu_overrides/{canonicalItemId}`
/// carrying `{priceCents?, isAvailable?}` — additive to the global `menus`
/// collection, no migration. A null/absent/malformed field inherits the
/// global value (fail-closed to inherit).
class MenuOverride {
  const MenuOverride({this.priceCents, this.isAvailable});

  final int? priceCents;
  final bool? isAvailable;

  static MenuOverride fromData(Map<String, dynamic> data) => MenuOverride(
    priceCents: data['priceCents'] is int ? data['priceCents'] as int : null,
    isAvailable: data['isAvailable'] is bool
        ? data['isAvailable'] as bool
        : null,
  );
}

/// Watches the selected branch's menu override overlay
/// (`branches/{bid}/menu_overrides/{canonicalItemId}`).
///
/// P9 W1 (T-3): this is the fix for the structurally-unreachable doc-id merge
/// (PERF-8 W4-2) — the overlay is keyed by DOMAIN id (override doc id ==
/// canonical item id), so a branch can re-price or mask a global dish.
///
/// Fail-soft by design: the overlay is additive, so when the subcollection
/// cannot be read (offline, or the rules lane for menu_overrides not yet
/// opened — handed to W2), the menu inherits the global items. The failure is
/// logged — never silent.
final menuOverridesProvider =
    StreamProvider.autoDispose<Map<String, MenuOverride>>((ref) async* {
      final branchId = ref.watch(currentBranchIdProvider);
      final db = ref.watch(firestoreProvider);
      if (branchId == null) return;
      LoggerService? logger;
      try {
        logger = ref.watch(loggerProvider);
        await for (final snapshot
            in db
                .collection('branches')
                .doc(branchId)
                .collection('menu_overrides')
                .limit(kMenuMaxItemsSafetyCap)
                .snapshots()) {
          yield {
            for (final doc in snapshot.docs)
              doc.id: MenuOverride.fromData(doc.data()),
          };
        }
      } catch (e, stack) {
        // Fail-soft: the overlay is additive — a read failure (or even a logger
        // construction failure in a degraded environment) must never take the
        // menu path down. Log when a logger exists; never silent otherwise.
        if (logger != null) {
          await logger.error(
            e,
            'menu_overrides stream failed — inheriting global menu for branch '
            '$branchId',
            stack: stack,
          );
        }
        yield const <String, MenuOverride>{};
      }
    });

/// Watches global menu items and branch-specific overrides, merging them
final mergedMenuProvider = StreamProvider.autoDispose<List<MenuItemModel>>((
  ref,
) async* {
  final branchId = ref.watch(currentBranchIdProvider);
  final db = ref.watch(firestoreProvider);

  // W8.7 (04-P1-QUERY): both menus streams are the app's primary data path
  // and were uncapped — they now carry the repo's named menu safety cap
  // (kMenuMaxItemsSafetyCap, menu_repository.dart:16).
  final globalStream = db
      .collection('menus')
      .where('branchId', isNull: true)
      .limit(kMenuMaxItemsSafetyCap)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => admin_model.MenuItemModel.fromDoc(d)).toList(),
      );

  if (branchId == null) {
    await for (final globals in globalStream) {
      yield globals.map(_mapToDomain).toList();
    }
    return;
  }

  // P9 W1 (T-3): the per-branch override overlay, keyed by canonical item id
  // (override doc id == canonical item id) — the fix for the structurally
  // unreachable doc-id merge (PERF-8 W4-2). The first merged emission is
  // GATED on the overlay's first resolved value so the stream never shows an
  // un-overridden price that immediately flips. The overlay provider is
  // fail-soft (it yields {} and logs on a read failure), so this await cannot
  // stall or error the menu; this catch is belt-and-braces for a provider-level
  // failure — the source error's telemetry belongs to that provider.
  Map<String, MenuOverride> overlay;
  try {
    overlay = await ref.watch(menuOverridesProvider.future);
  } catch (_) {
    overlay = const <String, MenuOverride>{};
  }

  final overrideStream = db
      .collection('menus')
      .where('branchId', isEqualTo: branchId)
      .limit(kMenuMaxItemsSafetyCap)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => admin_model.MenuItemModel.fromDoc(d)).toList(),
      );

  final mergedStream = Rx.combineLatest2(globalStream, overrideStream, (
    globals,
    overrides,
  ) {
    final map = <String, admin_model.MenuItemModel>{};
    for (final g in globals) {
      map[g.id] = g;
    }
    for (final o in overrides) {
      final key = o.id;
      if (map.containsKey(key)) {
        map[key] = map[key]!.mergeWith(o);
      } else {
        map[key] = o;
      }
    }
    // P8 W4 (A-4 / T4) — availability masking is NOT this provider's job.
    //
    // This path used to drop `!isAvailable` items while the global-only path
    // above (branchId == null) has always emitted them, which made the merged
    // stream path-dependent AND hid out-of-stock dishes from the owner surface
    // that exists to re-enable them (admin_menu_manager.dart:24 renders this
    // stream and draws an out-of-stock badge at :48-58; owner_dashboard.dart
    // toggles `isAvailable`). Customers are protected downstream instead:
    // menu_screen.dart:235 / dish_detail_screen.dart:97 render sold-out with
    // the add disabled, home_service.dart:57 masks the feed, and
    // cart_validator_service.dart:97 fails closed at add time.
    //
    // P9 W1 (T-3) — the overlay applies LAST, keyed by canonical item id:
    // an override doc wins for the fields it sets; absence (of doc or field)
    // inherits. `isAvailable:false` therefore arrives as a MASKED row (the
    // W4 contract above is untouched) — never dropped.
    return map.values.map((raw) => _mapToDomain(raw, overlay[raw.id])).toList();
  });

  yield* mergedStream;
});

MenuItemModel _mapToDomain(
  admin_model.MenuItemModel raw, [
  MenuOverride? branchOverride,
]) {
  final resolvedCategory = raw.category.isNotEmpty
      ? raw.category
      : (raw.tags.isNotEmpty ? raw.tags.first : 'General');
  return MenuItemModel(
    id: raw.id,
    name: raw.name,
    description: raw.description,
    // P9 W1 (T-3): the branch overlay wins per-field; absence inherits.
    priceCents: branchOverride?.priceCents ?? raw.priceCents,
    imageUrl: raw.imageUrl.isNotEmpty ? raw.imageUrl : null,
    category: resolvedCategory,
    tags: raw.tags,
    isAvailable: branchOverride?.isAvailable ?? raw.isAvailable,
    quantityRemaining: raw.quantityRemaining,
    modifiers: raw.modifiers.map((m) => MenuModifier.fromJson(m)).toList(),
  );
}
