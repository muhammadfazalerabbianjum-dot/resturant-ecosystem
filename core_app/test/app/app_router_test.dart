import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/app_router.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/auth/presentation/login_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:core/core.dart';

void main() {
  group('App Router', () {
    test('appRouterProvider is defined', () {
      expect(appRouterProvider, isNotNull);
    });

    test('appRouterProvider is a Provider', () {
      expect(appRouterProvider.runtimeType.toString(), contains('Provider'));
    });

    test('appRouterProvider name references router', () {
      expect(
        appRouterProvider.runtimeType.toString().toLowerCase(),
        contains('provider'),
      );
    });

    test('appRouterProvider can be referenced', () {
      expect(appRouterProvider, isNotNull);
    });

    test('appRouterProvider is exported from app_router.dart', () {
      expect(appRouterProvider, isNotNull);
    });
  });

  group('ROUTER-1 T-1: screenIdToRouteName covers every config screens[].id', () {
    for (final configPath in const [
      'assets/client_config.json',
      '../apps/halal_boyz/assets/client_config.json',
    ]) {
      test('$configPath — every screens[].id is a key of the map', () {
        final file = File(configPath);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'config asset missing at $configPath '
              '(run flutter test from the package root)',
        );
        final decoded =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final screens = decoded['screens'] as List<dynamic>;
        expect(screens, isNotEmpty);
        final ids = screens
            .whereType<Map<dynamic, dynamic>>()
            .map((s) => s['id'])
            .whereType<String>()
            .toList();
        expect(ids, isNotEmpty);
        for (final id in ids) {
          expect(
            screenIdToRouteName.containsKey(id),
            isTrue,
            reason:
                'config screen id "$id" has no RouteNames mapping — '
                'add it to screenIdToRouteName (core_app/lib/app/app_router.dart) '
                'or config-mode named navigation will crash (00-P0-1)',
          );
          expect(screenIdToRouteName[id], isNotEmpty);
        }
      });
    }
  });

  group('ROUTER-2: screenIdToRouteName structural integrity (PERF-6a-2)', () {
    test('no duplicate route-name values (named navigation must stay 1:1)', () {
      final values = screenIdToRouteName.values.toList();
      expect(
        values.toSet().length,
        values.length,
        reason:
            'duplicate route name — two screen ids resolving to one name '
            'makes goNamed ambiguous (00-P0-1 class defect)',
      );
    });

    test('every mapped route name is a RouteNames constant', () {
      final routeNamesSource = File(
        'lib/app/navigation/route_names.dart',
      ).readAsStringSync();
      for (final name in screenIdToRouteName.values) {
        expect(
          routeNamesSource,
          contains("'$name'"),
          reason:
              'route name "$name" is not a RouteNames constant — named '
              'navigation would crash on an unknown route name',
        );
      }
    });

    test('every config screens[].id also has a WIDGET switch case', () {
      // T-1 covers the NAME map against both real configs; this covers the
      // widget switch in _getScreenWidget so a mapped-but-unrenderable id
      // cannot silently ship rendering the fallback scaffold.
      final routerSource = File('lib/app/app_router.dart').readAsStringSync();
      for (final configPath in const [
        'assets/client_config.json',
        '../apps/halal_boyz/assets/client_config.json',
      ]) {
        final decoded =
            jsonDecode(File(configPath).readAsStringSync())
                as Map<String, dynamic>;
        final ids = (decoded['screens'] as List<dynamic>)
            .whereType<Map<dynamic, dynamic>>()
            .map((s) => s['id'])
            .whereType<String>();
        for (final id in ids) {
          expect(
            routerSource,
            contains("case '$id':"),
            reason:
                'screen id "$id" maps to a route name but has NO widget '
                'case — config mode would render the fallback scaffold',
          );
        }
      }
    });
  });

  group('ROUTER-1 T-2: config-mode named navigation resolves', () {
    testWidgets(
      'goNamed(RouteNames.login) lands on LoginScreen — not the error page',
      (tester) async {
        // Load the REAL bundled config so the router registers its 26 config
        // routes (config mode, not the static fallback).
        await AppConfig.loadConfig();
        expect(
          AppConfig.screens,
          isNotEmpty,
          reason: 'bundled client_config.json must register screens',
        );

        GoRouter? router;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith(
                (ref) => Stream<User?>.value(null),
              ),
              currentUserProvider.overrideWith((ref) async => null),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                router = ref.watch(appRouterProvider);
                return MaterialApp.router(
                  routerConfig: router,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: AppLocalizations.supportedLocales,
                );
              },
            ),
          ),
        );
        // Fixed pumps (NOT pumpAndSettle): the splash entry screen runs an
        // infinite loading animation, which would never settle. These pumps
        // let the auth overrides resolve and the router rebuild once.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        router!.goNamed(RouteNames.login);
        // Pump through the FadeSlideTransitionPage animation.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(LoginScreen), findsOneWidget);
        // The router error page renders the 'Route Error' app bar title.
        expect(find.text('Route Error'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ROUTER-1 T-3: Navigator name-API ban (G0 conformance)', () {
    test(
      'Navigator.pushNamed / pushReplacementNamed = 0 in both lib trees',
      () {
        final banned = RegExp(r'Navigator\.pushNamed|pushReplacementNamed');
        final offenders = <String>[];
        for (final root in const ['lib', '../apps/halal_boyz/lib']) {
          final dir = Directory(root);
          expect(dir.existsSync(), isTrue, reason: 'lib tree missing: $root');
          dir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .forEach((file) {
                final lines = file.readAsLinesSync();
                for (var i = 0; i < lines.length; i++) {
                  if (banned.hasMatch(lines[i])) {
                    offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
                  }
                }
              });
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'go_router is the only navigation stack (ROUTER-1); the '
              'Navigator name API never registered these routes. Offenders:\n'
              '${offenders.join('\n')}',
        );
      },
    );
  });
}
