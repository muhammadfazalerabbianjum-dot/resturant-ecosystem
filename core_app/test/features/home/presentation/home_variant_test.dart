import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart'
    show
        currentUserProvider,
        deadLetterCountProvider,
        firestoreProvider,
        kGdprAnalyticsConsentKey,
        loggerProvider,
        LoggerService,
        pendingSyncCountProvider;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/config/screen_variants.dart';
import 'package:labs/features/home/presentation/home_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PERF-5 T-4/T-5: the home feed's variant mechanism, driven end-to-end.
///
/// Two provenance paths for the resolved variant:
///  1. CONFIG-DRIVEN (the real chain): a mocked `assets/client_config.json`
///     carrying `screens[].variant` → `AppConfig.loadConfig` → the registry
///     providers → `_HomeFeedTab`'s showcase sliver.
///  2. REGISTRY-OVERRIDE (fast unit path): the `screenVariantsProvider`
///     override — proves the wiring independent of the config load.
///
/// The default-proof (T-5) loads the REAL template asset (which carries no
/// variant keys) and asserts the ORIGINAL 2-column grid renders with no
/// showcase header — byte-for-byte behavior, only asserted structurally.

/// Mocks the flutter/assets channel so `rootBundle` resolves exactly
/// [assets] (anything else is reported missing) — the schema test's
/// pattern, so the config-driven tests drive the REAL asset read.
void mockAssets(Map<String, String> assets) {
  const channel = 'flutter/assets';
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(channel, (message) async {
        if (message == null) return null;
        final key = utf8.decode(message.buffer.asUint8List());
        final content = assets[key];
        if (content == null) return null;
        return ByteData.view(Uint8List.fromList(utf8.encode(content)).buffer);
      });
}

String configJsonWithVariant(String variant) => jsonEncode(<String, dynamic>{
  '_meta': <String, dynamic>{'schemaVersion': '1.0.0'},
  'app': <String, dynamic>{'name': 'Client App', 'bundleId': 'com.client.app'},
  'currency': <String, dynamic>{'code': 'USD', 'symbol': ''},
  'environment': <String, dynamic>{
    'firebaseAndroidApiKey': 'AIzaSyA-real-key',
    'firebaseIosApiKey': 'AIzaSyA-real-key',
  },
  'firebase': <String, dynamic>{'projectId': 'client-project'},
  'theme': <String, dynamic>{
    'injection': 'local-config-file',
    'colors': <String, dynamic>{'primary': '0xFF2E7D32'},
  },
  'navigation': <String, dynamic>{'entryPoint': '/'},
  'features': <String, dynamic>{
    'flags': <String, dynamic>{'smartReorder': true},
  },
  'screens': <dynamic>[
    {'id': 'HomeScreen', 'route': '/', 'variant': variant},
  ],
});

Future<void> _seedItem(
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

Future<Widget> _homeHarness(
  FakeFirebaseFirestore firestore, {
  Map<String, String>? variantTable,
}) async {
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
      if (variantTable != null)
        screenVariantsProvider.overrideWithValue(variantTable),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(),
    ),
  );
}

Future<void> _settleHome(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

/// Drains any post-rebuild zero-duration timers (the hero carousel's
/// house-pattern settle), so no Timer survives the teardown assertion.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1000));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppConfig.resetForTest();
  });

  tearDown(() {
    AppConfig.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  group('PERF-5: the showcase variant renders a DISTINCT structure '
      '(registry override path)', () {
    testWidgets('showcase: full-width rows + header, the 2-col grid is GONE', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await _seedItem(
        firestore,
        id: 'm1',
        name: 'Margherita Pizza',
        category: 'pizza',
        priceCents: 1500,
      );
      await _seedItem(
        firestore,
        id: 'm2',
        name: 'Salmon Roll',
        category: 'sushi',
        priceCents: 3500,
      );

      await tester.pumpWidget(
        await _homeHarness(
          firestore,
          variantTable: const {
            ScreenVariants.homeScreenId: ScreenVariants.homeShowcaseVariant,
          },
        ),
      );
      await _settleHome(tester);

      // The showcase layout: the l10n'd section header + the seeded items.
      expect(find.text('Showcase'), findsOneWidget);
      expect(find.text('Margherita Pizza'), findsOneWidget);
      expect(find.text('Salmon Roll'), findsOneWidget);
      // ...and the default grid is structurally GONE.
      expect(find.byType(SliverGrid), findsNothing);

      await _drain(tester);
    });

    testWidgets('showcase keeps the grid\'s money/nav contracts: add-to-cart '
        'snackbar fires from the showcase card', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedItem(
        firestore,
        id: 'm1',
        name: 'Margherita Pizza',
        category: 'pizza',
        priceCents: 1500,
      );

      await tester.pumpWidget(
        await _homeHarness(
          firestore,
          variantTable: const {
            ScreenVariants.homeScreenId: ScreenVariants.homeShowcaseVariant,
          },
        ),
      );
      await _settleHome(tester);

      await tester.tap(find.byIcon(Icons.add_circle).first);
      await tester.pump();
      // The same localized add-to-cart feedback the grid card produces.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Margherita Pizza'), findsWidgets);

      await _drain(tester);
    });

    testWidgets('default (no variant): the ORIGINAL 2-column grid renders', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await _seedItem(
        firestore,
        id: 'm1',
        name: 'Margherita Pizza',
        category: 'pizza',
        priceCents: 1500,
      );

      await tester.pumpWidget(await _homeHarness(firestore));
      await _settleHome(tester);

      // Byte-for-byte default: the grid, and NO showcase chrome.
      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.text('Showcase'), findsNothing);
      expect(find.text('Margherita Pizza'), findsOneWidget);

      await _drain(tester);
    });
  });

  group('PERF-5: the CONFIG-DRIVEN chain (mocked asset -> loadConfig -> '
      'registry -> UI)', () {
    testWidgets('variant: "showcase" in client_config.json drives the '
        'showcase layout', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedItem(
        firestore,
        id: 'm1',
        name: 'Margherita Pizza',
        category: 'pizza',
        priceCents: 1500,
      );

      AppConfig.resetForTest();
      mockAssets({
        'assets/client_config.json': configJsonWithVariant('showcase'),
      });
      await AppConfig.loadConfig();
      expect(AppConfig.loadFailed, isFalse, reason: 'the variant is valid');
      expect(
        AppConfig.schemaError,
        isNull,
        reason: 'a valid variant must NOT trip the W6.5 gate',
      );

      // NO provider override — the resolution comes from the loaded config.
      await tester.pumpWidget(await _homeHarness(firestore));
      await _settleHome(tester);

      expect(find.text('Showcase'), findsOneWidget);
      expect(find.text('Margherita Pizza'), findsOneWidget);
      expect(find.byType(SliverGrid), findsNothing);

      await _drain(tester);
    });

    testWidgets('T-5 default-proof: the REAL template asset (no variant '
        'keys) renders the original grid', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedItem(
        firestore,
        id: 'm1',
        name: 'Margherita Pizza',
        category: 'pizza',
        priceCents: 1500,
      );

      AppConfig.resetForTest();
      // No mock: the REAL bundled assets/client_config.json loads — the
      // checked-in configs carry NO variant keys, which is exactly the
      // byte-for-byte default this batch must preserve (acceptance 2).
      // Real asset I/O must run outside the FakeAsync zone: runAsync.
      await tester.runAsync(() => AppConfig.loadConfig());
      expect(AppConfig.loadFailed, isFalse);
      expect(AppConfig.schemaError, isNull);

      await tester.pumpWidget(await _homeHarness(firestore));
      await _settleHome(tester);

      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.text('Showcase'), findsNothing);
      expect(find.text('Margherita Pizza'), findsOneWidget);

      await _drain(tester);
    });
  });
}
