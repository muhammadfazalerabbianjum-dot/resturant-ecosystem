/// UI-8 (p18) T-4 — mechanical RTL inventory + widget geometry proofs.
///
/// T-5 appends the RTL golden pack to this file. The inventory below is the
/// fail-closed regression guard for the T-4 sweep: every physical
/// left/right anchor in `core_app/lib/features/**` and
/// `packages/core_ui/lib/src/ui/**` must be either (a) rewritten to a
/// directional API (`PositionedDirectional`, `EdgeInsetsDirectional`) or
/// (b) dispositioned as documented-safe in the report's disposition table
/// (`tool_uilib/p18/p18_report.md`).
library;

import 'dart:io';

import 'package:core/core.dart'
    show
        IsarService,
        currentUserProvider,
        deadLetterCountProvider,
        firestoreProvider,
        kGdprAnalyticsConsentKey,
        loggerProvider,
        LoggerService,
        pendingSyncCountProvider;
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/cart/presentation/cart_screen.dart';
import 'package:labs/features/home/presentation/home_feed_showcase.dart';
import 'package:labs/features/home/presentation/home_screen.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/domain/menu_modifier_model.dart';
import 'package:labs/features/menu/presentation/dish_detail_screen.dart';
import 'package:labs/features/menu/presentation/menu_screen.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/platform_mocks.dart';

/// Evidence string for one violation: `token line N (one-line statement)`.
String _evidence(String source, int index, String token, String stmt) {
  final line = source.substring(0, index).split(String.fromCharCode(10)).length;
  final flat = stmt.split(String.fromCharCode(10)).join(' ').trim();
  return '$token line $line: $flat';
}

/// Physical `left:`/`right:` anchors of one constructor call.
///
/// [anySideIsViolation] = true flags ANY physical side (core_ui rule);
/// false flags only ONE-sided anchors — core_app symmetric pairs such as
/// `EdgeInsets.only(left: 12, right: 12)` are dispositioned safe.
List<String> _ctorSideHits(
  String source,
  String ctor, {
  required bool anySideIsViolation,
}) {
  final hits = <String>[];
  var from = 0;
  while (true) {
    final start = source.indexOf(ctor, from);
    if (start < 0) return hits;
    final open = start + ctor.length - 1;
    var depth = 0;
    var end = open;
    for (; end < source.length; end++) {
      final ch = source.codeUnitAt(end);
      if (ch == 0x28) depth += 1; // open paren
      if (ch == 0x29) {
        depth -= 1; // close paren
        if (depth == 0) break;
      }
    }
    final stmt = source.substring(open, end + 1);
    final hasLeft = stmt.contains('left:');
    final hasRight = stmt.contains('right:');
    final violation = anySideIsViolation
        ? (hasLeft || hasRight)
        : (hasLeft != hasRight);
    // Documented-safe exception (disposition table): the confetti emitter is
    // anchored at the horizontal CENTER — `left: width / 2` is direction-
    // neutral geometry, not a leading/trailing assumption.
    final isCenterAnchor = stmt.contains('size.width / 2');
    if (violation && !isCenterAnchor) {
      hits.add(_evidence(source, start, ctor, stmt));
    }
    from = end + 1;
  }
}

/// Whole-file physical tokens (each reported at most once per file).
const List<String> _kPhysicalTokens = <String>[
  'Alignment.topLeft',
  'Alignment.topRight',
  'Alignment.bottomLeft',
  'Alignment.bottomRight',
  'Alignment.centerLeft',
  'Alignment.centerRight',
  'Alignment.left',
  'Alignment.right',
  'topLeft:',
  'topRight:',
  'bottomLeft:',
  'bottomRight:',
  'TextAlign.left',
  'TextAlign.right',
  'TextDirection.ltr',
];

/// Collects every violation across both T-4 scan roots (fail-closed).
List<String> collectRtlViolations() {
  final violations = <String>[];
  final roots = <Directory>[
    Directory('lib/features'),
    Directory('../packages/core_ui/lib/src/ui'),
  ];
  for (final root in roots) {
    final files =
        root
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final source = file.readAsStringSync();
      final path = file.path;
      final isCoreUi = path.contains('packages');
      violations.addAll(
        _ctorSideHits(
          source,
          'Positioned(',
          anySideIsViolation: true,
        ).map((h) => '$path | $h'),
      );
      violations.addAll(
        _ctorSideHits(
          source,
          'EdgeInsets.only(',
          anySideIsViolation: isCoreUi,
        ).map((h) => '$path | $h'),
      );
      final fromSteb = source.indexOf('EdgeInsets.fromSTEB(');
      if (fromSteb >= 0) {
        violations.add(
          '$path | ${_evidence(source, fromSteb, 'EdgeInsets.fromSTEB(', 'physical 4-arg form')}',
        );
      }
      for (final token in _kPhysicalTokens) {
        final idx = source.indexOf(token);
        if (idx >= 0) {
          violations.add(
            '$path | ${_evidence(source, idx, token, 'physical-direction token')}',
          );
        }
      }
    }
  }
  return violations;
}

// ---------------------------------------------------------------------------
// T-5 — RTL golden pack for the p16-wired screens + component samples.
//
// Each harness CLONES the screen's existing green p16/app test harness with
// ONE delta: `locale: const Locale('ar')`. MaterialApp derives
// TextDirection.rtl from the locale through the ordinary framework path — no
// Directionality.override anywhere (L3: RTL correctness over hacks).
// Baselines are captured ONCE via
// `flutter test --update-goldens test/rtl_goldens_test.dart`, then verified
// by the plain run.

const List<MenuItemModel> _menuFixtures = <MenuItemModel>[
  MenuItemModel(
    id: 'g1',
    name: 'Truffle Burger',
    description: 'Smashed patty, truffle aioli',
    priceCents: 1850,
    category: 'mains',
    tags: ['popular'],
    isAvailable: true,
  ),
  MenuItemModel(
    id: 'g2',
    name: 'Margherita Pizza',
    description: 'San Marzano, fior di latte',
    priceCents: 1599,
    category: 'pizza',
    isAvailable: true,
  ),
  MenuItemModel(
    id: 'g3',
    name: 'Salmon Roll',
    description: 'Sold out today',
    priceCents: 3500,
    category: 'sushi',
    isAvailable: false,
  ),
];

/// Menu harness — clone of `test/ui/p16_menu_golden_test.dart` + ar locale.
Widget _rtlMenuApp() => ProviderScope(
  overrides: [
    mergedMenuProvider.overrideWith((ref) => Stream.value(_menuFixtures)),
    firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    loggerProvider.overrideWithValue(
      LoggerService(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      ),
    ),
    currentUserProvider.overrideWith((ref) async => null),
    pendingSyncCountProvider.overrideWith((ref) => Stream<int>.value(0)),
    deadLetterCountProvider.overrideWith((ref) => Stream<int>.value(0)),
    restaurantConfigProvider.overrideWith(
      (ref) => Stream<RestaurantConfigModel>.value(
        const RestaurantConfigModel(currency: 'USD'),
      ),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const MenuScreen(),
  ),
);

/// Dish-detail harness — clone of `test/ui/p16_dish_detail_golden_test.dart`
/// (no `imageUrl`: the Hero/CachedNetworkImage branch would hit the
/// transport-blocked double and make the capture time-dependent).
Widget _rtlDishApp(MenuItemModel item) => ProviderScope(
  overrides: [
    mergedMenuProvider.overrideWith((ref) => Stream.value([item])),
    firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    loggerProvider.overrideWithValue(
      LoggerService(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      ),
    ),
    restaurantConfigProvider.overrideWith(
      (ref) => Stream<RestaurantConfigModel>.value(
        const RestaurantConfigModel(currency: 'USD'),
      ),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DishDetailScreen(menuItemId: item.id),
  ),
);

Future<void> _seedHomeItem(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String name,
  required String category,
  required int priceCents,
}) async {
  await firestore.collection('menus').doc(id).set({
    'name': name,
    'category': category,
    'priceCents': priceCents,
    'isAvailable': true,
    'branchId': null,
  });
}

/// Home harness — clone of `p16_home_adoption_test.dart` + ar locale. No
/// fixture carries an `imageUrl`, so the capture never enters the
/// transport-blocked network branch (deterministic, no cache Timer).
Widget _rtlHomeApp(FakeFirebaseFirestore firestore) {
  SharedPreferences.setMockInitialValues({kGdprAnalyticsConsentKey: true});
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      loggerProvider.overrideWithValue(
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      ),
      currentUserProvider.overrideWith((ref) async => null),
      pendingSyncCountProvider.overrideWith((ref) => Stream<int>.value(0)),
      deadLetterCountProvider.overrideWith((ref) => Stream<int>.value(0)),
    ],
    child: const MaterialApp(
      locale: Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(),
    ),
  );
}

class _RtlCapturingCartRepo extends CartRepository {
  _RtlCapturingCartRepo(this._initial)
    : super(
        IsarService.shared(),
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  CartModel _initial;

  @override
  Future<CartModel> loadCart() async => _initial;

  @override
  Future<void> saveCart(CartModel cart) async => _initial = cart;
}

/// Cart harness — clone of `p16_cart_adoption_test.dart` + ar locale.
Widget _rtlCartApp(CartRepository repo) => ProviderScope(
  overrides: [
    cartRepositoryProvider.overrideWith((ref) => repo),
    firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
  ],
  child: MaterialApp.router(
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
        GoRoute(
          path: '/checkout',
          name: 'checkout',
          builder: (context, state) => const Scaffold(body: Text('Checkout')),
        ),
        GoRoute(
          path: '/',
          name: 'menu',
          builder: (context, state) => const Scaffold(body: Text('Menu')),
        ),
      ],
    ),
  ),
);

/// Component samples under RTL — the T-4-touched primitives (BrandDivider
/// indent/endIndent, SectionHeader) beside the money/notice components.
Widget _rtlComponentSamples() => ProviderScope(
  child: MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SectionHeader(title: 'الأطباق', subtitle: 'عرض كل الأقسام'),
          SizedBox(height: 8),
          BrandDivider(indent: 16, endIndent: 8, thickness: 2),
          SizedBox(height: 8),
          BrandDivider.dashed(indent: 16, endIndent: 8),
          SizedBox(height: 8),
          PriceTag(cents: 1250, large: true),
          SizedBox(height: 8),
          InfoBanner(
            tone: InfoTone.warning,
            child: Text('نفدت الكمية من هذا الطبق'),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  // House fixture (`helpers/platform_mocks.dart`): the cart harness's
  // logger path reaches `path_provider` through LoggerService.init — the
  // checkout golden test wires the same setUpAll.
  setUpAll(setupPlatformMocks);

  group('T-4 mechanical RTL inventory (fail-closed guard)', () {
    test(
      'zero physical-direction anchors in features/** and core_ui ui/**',
      () {
        final violations = collectRtlViolations();
        expect(
          violations,
          isEmpty,
          reason:
              'T-4 disposition required — rewrite to PositionedDirectional/'
              'EdgeInsetsDirectional or record as documented-safe '
              '(report table): ${violations.join(' | ')}',
        );
      },
    );
  });

  group('T-4 widget geometry proofs (direction resolution, not pixels)', () {
    testWidgets('BrandDivider indent/endIndent resolve to start/end in RTL', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 300,
              child: BrandDivider(indent: 16, endIndent: 8, thickness: 2),
            ),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(BrandDivider),
              matching: find.byType(Container),
            )
            .first,
      );
      final margin = container.margin!;
      final rtl = margin.resolve(TextDirection.rtl);
      expect(rtl.right, 16, reason: 'indent = leading = RIGHT in RTL');
      expect(rtl.left, 8, reason: 'endIndent = trailing = LEFT in RTL');
      final ltr = margin.resolve(TextDirection.ltr);
      expect(ltr.left, 16, reason: 'LTR rendering stays byte-identical');
      expect(ltr.right, 8, reason: 'LTR rendering stays byte-identical');
    });

    testWidgets(
      'showcase section-header padding follows the start edge in RTL',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              locale: Locale('ar'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: CustomScrollView(slivers: [ShowcaseHomeFeed(items: [])]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final paddings = tester
            .widgetList<Padding>(
              find.ancestor(
                of: find.byType(SectionHeader),
                matching: find.byType(Padding),
              ),
            )
            .toList();
        expect(
          paddings
              .map((p) => p.padding.resolve(TextDirection.rtl).right)
              .toList(),
          contains(4),
          reason: 'header indent is a LEADING gap — right side in RTL',
        );
        expect(
          paddings
              .map((p) => p.padding.resolve(TextDirection.ltr).left)
              .toList(),
          contains(4),
          reason: 'LTR rendering stays byte-identical',
        );
      },
    );
  });

  group('T-5 RTL golden pack (p16-wired screens + samples under ar)', () {
    testWidgets('menu — ar/RTL', (tester) async {
      await tester.pumpWidget(_rtlMenuApp());
      // Home-suite explicit-pump pattern (the thumbnail shimmer never lets
      // pumpAndSettle finish): 2×200 ms for the streams, then the 15 s pump
      // drains flutter_cache_manager's one-shot cleanup Timer.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(seconds: 15));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/snapshots/rtl_menu_ar.png'),
      );
    });

    testWidgets('dish detail — ar/RTL', (tester) async {
      await tester.pumpWidget(
        _rtlDishApp(
          const MenuItemModel(
            id: 'd1',
            name: 'Truffle Burger',
            description: 'Smashed patty, truffle aioli, brioche bun',
            priceCents: 1850,
            quantityRemaining: 6,
            isAvailable: true,
            modifiers: [
              MenuModifier(
                id: 'mod_size',
                name: 'Size',
                options: [
                  ModifierOption(id: 'opt_small', name: 'Small'),
                  ModifierOption(
                    id: 'opt_large',
                    name: 'Large',
                    upchargeCents: 150,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/snapshots/rtl_dish_detail_ar.png'),
      );
    });

    testWidgets('home feed — ar/RTL', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedHomeItem(
        firestore,
        id: 'm1',
        name: 'Margherita Pizza',
        category: 'pizza',
        priceCents: 1500,
      );
      await _seedHomeItem(
        firestore,
        id: 'm2',
        name: 'Salmon Roll',
        category: 'sushi',
        priceCents: 3500,
      );
      await tester.pumpWidget(_rtlHomeApp(firestore));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      // flutter_animate's entrance stagger (L12.3) drains inside ~1000 ms.
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/snapshots/rtl_home_ar.png'),
      );
    });

    testWidgets('cart — ar/RTL', (tester) async {
      final repo = _RtlCapturingCartRepo(
        CartModel(
          items: [
            CartItemModel(item: _menuFixtures[0], quantity: 1),
            CartItemModel(item: _menuFixtures[1], quantity: 2),
          ],
        ),
      );
      await tester.pumpWidget(_rtlCartApp(repo));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/snapshots/rtl_cart_ar.png'),
      );
    });

    testWidgets('component samples — ar/RTL', (tester) async {
      await tester.pumpWidget(_rtlComponentSamples());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/snapshots/rtl_component_samples_ar.png'),
      );
    });
  });
}
