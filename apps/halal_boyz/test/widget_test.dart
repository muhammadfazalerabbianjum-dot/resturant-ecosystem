import 'dart:io';

import 'package:core/core.dart' show kGdprAnalyticsConsentKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/labs.dart' show AppConfig, HomeScreen, RouteNames;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/router_test_harness.dart';

// ARCH-1 T-1/T-2: the shell's app root (`GeneratedApp` in `app/app.dart`) is
// now a THIN WRAPPER over the REAL app widget (`CoreApp` from
// `package:labs`). These tests prove the shell's REAL route table — built
// from the shell's OWN bundled `assets/client_config.json` through the
// production `appRouterProvider` — renders the REAL `HomeScreen` from
// `package:labs`, wearing the client config palette.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARCH-1 T-1: the shell resolves the REAL screens', () {
    testWidgets(
      'the shell router builds HomeScreen from package:labs (not a local '
      'placeholder)',
      (tester) async {
        await loadRealConfigMode();
        // The real HomeScreen fires the GDPR consent chain on first land;
        // mock the prefs store so the ask resolves against the canonical key.
        SharedPreferences.setMockInitialValues(<String, Object>{
          kGdprAnalyticsConsentKey: true,
        });

        final router = await pumpRouterApp(
          tester,
          overrides: [...routerAuthOverrides(), ...homeFeedOverrides()],
        );

        // The REAL production screen type — imported from package:labs via
        // the barrel (this file has NO local HomeScreen to import).
        expect(find.byType(HomeScreen), findsOneWidget);

        // P1 (impeccable re-rate 2026-10-03): the hero app-bar slot carries
        // the CLIENT's configured brand name — never the demo l10n value.
        // Two-sided pin: the wiring (app bar == AppConfig.appName) and the
        // shipped config value itself.
        expect(find.text(AppConfig.appName), findsOneWidget);
        expect(AppConfig.appName, 'Halal Boyz');

        // The entry route is the config-driven home route at '/'.
        final registered = routerNamedRoutes(router);
        expect(registered[RouteNames.home], '/');
        // (The GeneratedApp -> CoreApp wrapper mounting itself is proven by
        // the headless integration test: integration_test/app_launch_test.)
      },
    );

    test(
      'no placeholder screen class remains in shell lib (ARCH-1 deletion)',
      () {
        final files = Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();
        expect(files, isNotEmpty);
        for (final file in files) {
          final text = file.readAsStringSync();
          for (final marker in <String>[
            'class HomeScreen',
            'class MenuScreen',
            'class CartScreen',
            'class CheckoutScreen',
          ]) {
            expect(
              text.contains(marker),
              isFalse,
              reason:
                  '${file.path} must not declare a local screen '
                  '"$marker" — screens come from package:labs',
            );
          }
        }
      },
    );
  });

  group('ARCH-1 T-2: the client config flows through the real app', () {
    test(
      'AppConfig resolves the shell identity/palette/screens registry',
      () async {
        await loadRealConfigMode();

        expect(AppConfig.loadFailed, isFalse);
        expect(AppConfig.schemaError, isNull);
        expect(AppConfig.bundleId, isNotEmpty);
        expect(AppConfig.appName, isNotEmpty);
        expect(AppConfig.screens, isNotEmpty);
      },
    );

    testWidgets(
      'the config palette renders on the REAL MaterialApp (CoreApp wiring)',
      (tester) async {
        await loadRealConfigMode();
        SharedPreferences.setMockInitialValues(<String, Object>{
          kGdprAnalyticsConsentKey: true,
        });

        await pumpRouterApp(
          tester,
          overrides: [...routerAuthOverrides(), ...homeFeedOverrides()],
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp).first,
        );
        // The config palette must be the MaterialApp theme that the real
        // screens render with (not the labs in-code default).
        expect(
          materialApp.theme?.colorScheme.primary,
          AppConfig.theme.colorScheme.primary,
          reason: 'the hydrated config palette must BE the MaterialApp theme',
        );
      },
    );
  });
}
