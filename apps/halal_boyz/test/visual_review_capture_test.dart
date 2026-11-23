import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/locations/data/location_repository.dart';
import 'package:labs/labs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/router_test_harness.dart';

/// FIX-B9 T-5 — visual pack harness for the owner's first-look (D-7).
///
/// Captures the affected surfaces rendered through the REAL engine
/// (`AppTheme.buildTheme`) from the shell's own `assets/client_config.json`:
/// input fields, chips, card corners, compact/CTA buttons, backdrop, and the
/// order-success confetti palette — before/after the B9 config edit.
///
/// Q2 (impeccable critique 2026-10-02): the pack now ALSO carries
///   * REAL fonts — `FontLoader` loads the bundled Inter/PlayfairDisplay TTFs
///     and the theme is post-processed through the public
///     `AppTheme.applyResolvedFamilies` seam (the `_isTest` guard inside
///     `_textThemeFor` deliberately skips family application in tests, which
///     is exactly why every label rendered as test-font blocks — the P0),
///   * no debug banner (`debugShowCheckedModeBanner: false` — the critique's
///     P2 "corner ribbon" was the Flutter debug banner, which the REAL app
///     already suppresses at app_bootstrap:896),
///   * a semantic `states.png` (five InfoBanner tones + badge tones +
///     skeleton loading — the "no loading/inline status" evidence gap),
///   * full-screen `home.png` / `cart.png` / `checkout.png` captures (the
///     "capture canvas tells no story" P1) at a 393x844 phone viewport,
///     pumped through the shell's REAL router/config with seeded content.
///
/// Phase selection: `--dart-define=B9_PHASE=before` writes into
/// `tool_fix/b9/visual_review/before/`, the default (`after`) into
/// `tool_fix/b9/visual_review/after/`. Plain suite runs compare ONLY the
/// `after/` pack (committed), so the suite stays green post-GREEN.
///
/// The executor claims nothing about looks — the verdict is the owner's.

/// Loads one client font family (all its weights) through `FontLoader` so
/// widget-test text renders REAL glyphs instead of the test-font blocks the
/// critique caught (P0). Bytes come from the shell's own `assets/fonts/`
/// (family names match `flutter.fonts` in pubspec.yaml).
Future<void> _loadFamily(String family, List<String> ttfPaths) async {
  final loader = FontLoader(family);
  for (final path in ttfPaths) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// A no-op [SyncQueue] double for the checkout capture (the cart/checkout
/// golden recipe injects one; core_app's `RecordingSyncQueue` lives in its
/// test/helpers and is not importable across packages). The two Id-typed
/// DLQ methods are never called by a static capture — [noSuchMethod] covers
/// them without importing `package:isar`, which the shell does not declare
/// (the `FakeLogger` precedent in core_app test_helpers).
class _CaptureSyncQueue implements SyncQueue {
  @override
  Future<void> enqueue(
    String operation,
    String collectionName,
    Map<String, dynamic> data,
  ) async {}

  @override
  Future<void> processQueue() async {}

  @override
  Future<void> removeOperation(String operation, String id) async {}

  @override
  Future<List<IsarDeadLetter>> getDeadLetters() async => <IsarDeadLetter>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Cart repository that returns a seeded cart without touching disk — the
/// p16/p21 golden pattern ported shell-side (the shell cannot import
/// core_app's test/ helpers; this is the same 8-line double).
class _SeedCartRepo extends CartRepository {
  _SeedCartRepo(this._initial)
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const phase = String.fromEnvironment('B9_PHASE', defaultValue: 'after');
  const packDir = '../../../tool_fix/b9/visual_review/$phase';

  late Map<String, dynamic> theme;
  late String headingFamily;
  late String bodyFamily;

  setUpAll(() async {
    final file = File('assets/client_config.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    theme = json['theme'] as Map<String, dynamic>;
    // Config-driven families (never hardcoded): the pack renders whatever the
    // client config declares.
    final typography =
        theme['typography'] as Map<String, dynamic>? ?? <String, dynamic>{};
    headingFamily = (typography['headingFont'] as String?) ?? 'System';
    bodyFamily = (typography['bodyFont'] as String?) ?? 'System';

    // Q2 P0: load the real bundled fonts BEFORE the first pump.
    await _loadFamily('Inter', <String>[
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Bold.ttf',
    ]);
    await _loadFamily('PlayfairDisplay', <String>[
      'assets/fonts/PlayfairDisplay-Regular.ttf',
      'assets/fonts/PlayfairDisplay-Bold.ttf',
    ]);
    // P1 (impeccable re-rate 2026-10-03): the widget-test bundle ships no
    // FontManifest, so `Icons.*` fell back to `.notdef` squares and every
    // icon in the pack was unverifiable. Load the Flutter SDK's MaterialIcons
    // font from the TEST-FIXTURE copy (test/fonts/ + its license file — never
    // under assets/, so it stays out of the shipped bundle). This mirrors the
    // text-font fix above; the golden recapture is the proof.
    await _loadFamily('MaterialIcons', <String>[
      'test/fonts/MaterialIcons-Regular.otf',
    ]);

    // Real shell config (AppConfig.theme for the full-screen captures) +
    // GDPR gate skipped so the REAL home screen paints its content, not the
    // consent dialog (widget_test T-1 recipe).
    await loadRealConfigMode();
    SharedPreferences.setMockInitialValues(<String, Object>{
      kGdprAnalyticsConsentKey: true,
    });
  });

  List<Color> confettiColors() {
    final confetti = theme['confettiOverlay'] as Map<String, dynamic>;
    return (confetti['colors'] as List).cast<String>().map((raw) {
      return Color(int.parse(raw.trim().replaceFirst('0x', ''), radix: 16));
    }).toList();
  }

  /// Post-processes any built theme through the PUBLIC production slot table
  /// so captures carry the config-declared families — the `_isTest` guard in
  /// `AppTheme._textThemeFor` skips family application in test builds, which
  /// was the root cause of the test-font-block pack (Q2/P0).
  ThemeData captureTheme(ThemeData base) => base.copyWith(
    textTheme: AppTheme.applyResolvedFamilies(
      base.textTheme,
      headingFamily: headingFamily,
      bodyFamily: bodyFamily,
    ),
  );

  Future<void> setScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpSurface(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(400, 360),
  }) async {
    await setScreen(tester, size);
    await tester.pumpWidget(
      MaterialApp(
        // Q2/P2: the critique's "corner ribbon" was the Flutter debug
        // banner — the REAL app suppresses it (app_bootstrap), so captures
        // must too.
        debugShowCheckedModeBanner: false,
        theme: captureTheme(AppTheme.buildTheme(theme)),
        home: home,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('T-5 inputs surface (fill / border / radius tokens)', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Search menu',
                  hintText: 'Kebab, wrap, burger...',
                ),
              ),
              SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.person),
                  labelText: 'Email',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$packDir/inputs.png'),
    );
  });

  testWidgets('T-5 chips surface (chip.radius token)', (tester) async {
    await pumpSurface(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            // Q2: run spacing matches the outer margin (16) — the critique's
            // P2 "3+1 accidental wrap" was this 8px gap letting the wrapped
            // row clash with row one; 16 gives the accidental row clear air.
            runSpacing: 16,
            children: [
              const Chip(label: Text('Kebab')),
              const Chip(label: Text('Wraps')),
              FilterChip(
                label: const Text('Halal'),
                selected: false,
                onSelected: (_) {},
              ),
              const Chip(label: Text('Drinks')),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$packDir/chips.png'),
    );
  });

  testWidgets('T-5 card corners surface (cardRadius token)', (tester) async {
    await pumpSurface(
      tester,
      const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Card surface — corner radius from config'),
                ),
              ),
              SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Second card — same brand radius'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$packDir/cards.png'),
    );
  });

  testWidgets('T-5 button surfaces (smallRadius + ctaRadius tokens)', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              const TextButton(onPressed: null, child: Text('Cancel')),
              const OutlinedButton(onPressed: null, child: Text('Details')),
              FilledButton(onPressed: () {}, child: const Text('Checkout')),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$packDir/buttons.png'),
    );
  });

  testWidgets('T-5 backdrop surface (background.color token)', (tester) async {
    await pumpSurface(
      tester,
      Scaffold(
        appBar: AppBar(title: const Text('Backdrop')),
        body: const Center(
          child: Text(
            'scaffold + appbar backdrop from theme.background.color',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$packDir/backdrop.png'),
    );
  });

  testWidgets('T-5 order-success confetti palette (confettiOverlay.colors)', (
    tester,
  ) async {
    final colors = confettiColors();
    await pumpSurface(
      tester,
      Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Order success — confetti palette'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: colors
                    .map(
                      (color) => Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            color: color,
                            foregroundDecoration: BoxDecoration(
                              border: Border.all(color: Colors.black12),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '0x${color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$packDir/confetti.png'),
    );
  });

  // ---------------------------------------------------------------------------
  // Q2 (impeccable critique 2026-10-02): semantic states + full-screen pack.
  // ---------------------------------------------------------------------------

  testWidgets(
    'T-5 semantic states (5 banner tones + badge tones + skeleton loading)',
    (tester) async {
      await setScreen(tester, const Size(400, 600));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(AppTheme.buildTheme(theme)),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const InfoBanner(
                    tone: InfoTone.info,
                    child: Text('We open at 11:00 today'),
                  ),
                  const SizedBox(height: 8),
                  const InfoBanner(
                    tone: InfoTone.success,
                    child: Text('Order confirmed'),
                  ),
                  const SizedBox(height: 8),
                  const InfoBanner(
                    tone: InfoTone.warning,
                    child: Text('Heavy rain — delivery may run late'),
                  ),
                  const SizedBox(height: 8),
                  const InfoBanner(
                    tone: InfoTone.error,
                    child: Text('Payment failed. Try another card.'),
                  ),
                  const SizedBox(height: 8),
                  const InfoBanner(
                    tone: InfoTone.soldOut,
                    child: Text('Chicken Shawarma is sold out'),
                  ),
                  const SizedBox(height: 12),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      BrandBadge(label: 'Loyal', tone: BadgeTone.neutral),
                      BrandBadge(label: 'Open now', tone: BadgeTone.positive),
                      BrandBadge(label: 'Busy', tone: BadgeTone.warning),
                      BrandBadge(label: 'Cancelled', tone: BadgeTone.negative),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SkeletonLoader.block(width: double.infinity, height: 56),
                ],
              ),
            ),
          ),
        ),
      );
      // The skeleton shimmer never settles → fixed window (ui5 golden
      // precedent); every other element is static on frame 1.
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('$packDir/states.png'),
      );
    },
  );

  // Seeded content for the full-screen captures — the "no story" critique
  // needs a populated grid/cart, not empty states.
  const seedBurger = MenuItemModel(
    id: 'cap_burger',
    name: 'Smash Burger',
    priceCents: 899,
    category: 'Mains',
    isAvailable: true,
    quantityRemaining: 10,
  );
  const seedFries = MenuItemModel(
    id: 'cap_fries',
    name: 'Loaded Fries',
    priceCents: 549,
    category: 'Sides',
    isAvailable: true,
    quantityRemaining: 24,
  );
  const seedMenu = <MenuItemModel>[
    seedBurger,
    MenuItemModel(
      id: 'cap_shawarma',
      name: 'Chicken Shawarma',
      priceCents: 899,
      category: 'Mains',
      isAvailable: true,
      quantityRemaining: 40,
    ),
    MenuItemModel(
      id: 'cap_kebab',
      name: 'Beef Kebab Wrap',
      priceCents: 749,
      category: 'Mains',
      isAvailable: true,
      quantityRemaining: 25,
    ),
    MenuItemModel(
      id: 'cap_falafel',
      name: 'Falafel Box',
      priceCents: 699,
      category: 'Mains',
      isAvailable: true,
      quantityRemaining: 30,
    ),
    seedFries,
    MenuItemModel(
      id: 'cap_garlic',
      name: 'Garlic Sauce',
      priceCents: 149,
      category: 'Sides',
      isAvailable: true,
      quantityRemaining: 100,
    ),
    MenuItemModel(
      id: 'cap_lassi',
      name: 'Mango Lassi',
      priceCents: 399,
      category: 'Drinks',
      isAvailable: true,
      quantityRemaining: 50,
    ),
    MenuItemModel(
      id: 'cap_baklava',
      name: 'Chocolate Baklava',
      priceCents: 449,
      category: 'Desserts',
      isAvailable: false,
      quantityRemaining: 0,
    ),
  ];

  testWidgets('T-5 full-screen home (real router + seeded grid, real fonts)', (
    tester,
  ) async {
    await setScreen(tester, const Size(393, 844));
    await pumpRouterApp(
      tester,
      overrides: <Override>[
        ...routerAuthOverrides(),
        ...homeFeedOverrides(menu: seedMenu),
      ],
      theme: captureTheme(AppConfig.theme),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$packDir/home.png'),
    );
  });

  /// The golden-proven override recipe (core_app cart/checkout goldens),
  /// ported shell-side with local doubles.
  List<Override> fullScreenCartOverrides(CartRepository repo) => <Override>[
    cartRepositoryProvider.overrideWithValue(repo),
    firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    restaurantConfigProvider.overrideWith(
      (ref) => Stream<RestaurantConfigModel>.value(
        const RestaurantConfigModel(
          currency: 'USD',
          deliveryFeeCents: 300,
          tipEnabled: true,
        ),
      ),
    ),
    authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
    currentUserIdProvider.overrideWithValue('capture-uid'),
    locationsProvider.overrideWith((ref) async => const []),
    loggerProvider.overrideWithValue(
      LoggerService(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      ),
    ),
    syncQueueProvider.overrideWithValue(_CaptureSyncQueue()),
    // Pinned (not lazily built): the default pending-sync provider runs a
    // periodic scan that reaches a bare LoggerService / platform channels a
    // widget-test process does not host (p16 B-P16-2 note).
    pendingSyncCountProvider.overrideWith((ref) => Stream<int>.value(0)),
    deadLetterCountProvider.overrideWith((ref) => Stream<int>.value(0)),
  ];

  Widget fullScreenApp({
    required GoRouter router,
    required ThemeData appTheme,
  }) => MaterialApp.router(
    routerConfig: router,
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );

  testWidgets('T-5 full-screen cart (seeded rows, real fonts)', (tester) async {
    await setScreen(tester, const Size(393, 844));
    final repo = _SeedCartRepo(
      const CartModel(
        items: [
          CartItemModel(item: seedBurger, quantity: 2),
          CartItemModel(item: seedFries, quantity: 1),
        ],
      ),
    );
    final appTheme = captureTheme(AppConfig.theme);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fullScreenCartOverrides(repo),
        child: fullScreenApp(
          appTheme: appTheme,
          router: GoRouter(
            initialLocation: '/cart',
            routes: <RouteBase>[
              GoRoute(
                path: '/cart',
                builder: (context, state) => const CartScreen(),
              ),
              GoRoute(
                path: '/checkout',
                name: 'checkout',
                builder: (context, state) =>
                    const Scaffold(body: Text('checkout')),
              ),
              GoRoute(
                path: '/',
                name: 'menu',
                builder: (context, state) =>
                    const Scaffold(body: Text('menu home')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CartScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$packDir/cart.png'),
    );
  });

  testWidgets('T-5 full-screen checkout (golden recipe, real fonts)', (
    tester,
  ) async {
    await setScreen(tester, const Size(393, 844));
    // Golden recipe (core_app checkout golden:143-144): CheckoutService reads
    // `functionsProvider` → `Firebase.functions()`, which needs an
    // initialized app over mocked core channels.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    final repo = _SeedCartRepo(
      const CartModel(items: [CartItemModel(item: seedBurger, quantity: 2)]),
    );
    final appTheme = captureTheme(AppConfig.theme);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fullScreenCartOverrides(repo),
        child: fullScreenApp(
          appTheme: appTheme,
          router: GoRouter(
            initialLocation: '/checkout',
            routes: <RouteBase>[
              GoRoute(
                path: '/checkout',
                name: 'checkout',
                builder: (context, state) => const CheckoutScreen(),
              ),
              GoRoute(
                path: '/',
                name: 'menu',
                builder: (context, state) =>
                    const Scaffold(body: Text('menu home')),
              ),
              GoRoute(
                path: '/order',
                name: 'orderTracker',
                builder: (context, state) =>
                    const Scaffold(body: Text('order tracker')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$packDir/checkout.png'),
    );
  });
}
