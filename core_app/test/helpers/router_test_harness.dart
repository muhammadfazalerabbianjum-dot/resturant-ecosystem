/// Shared plumbing for the ROUTER-3 config-mode router tests (W2.7).
///
/// The production router is built from the REAL bundled `client_config.json`
/// through the production `appRouterProvider`; these helpers only provide the
/// auth overrides every router build needs and a structural walker over the
/// actual go_router route tree (so a test can assert registration/resolution
/// without depending on a screen's private DI).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:labs/app/app_router.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/l10n/app_localizations.dart';

/// Puts [AppConfig] into config mode: resets every static and loads the REAL
/// bundled `assets/client_config.json` (26 screens on today's schema).
Future<void> loadRealConfigMode() async {
  AppConfig.resetForTest();
  await AppConfig.loadConfig();
}

/// Returns the overrides every router build needs:
/// - `authStateProvider`/`currentUserProvider` so the router's redirect can
///   resolve without Firebase. Pass [authUser] and [user] to simulate a
///   signed-in role (needed to bypass the anonymous→login redirect when
///   probing non-public routes).
/// - `loggerProvider` bound to the service's designed test seam
///   (`LoggerService(testDirectory:)`, the same seam the admin harnesses use)
///   so building the router never touches the unmocked `path_provider`
///   platform channel.
List<Override> routerAuthOverrides({User? authUser, UserModel? user}) {
  return [
    authStateProvider.overrideWith((ref) => Stream<User?>.value(authUser)),
    currentUserProvider.overrideWith((ref) async => user),
    loggerProvider.overrideWithValue(
      LoggerService(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      ),
    ),
  ];
}

/// Pumps the production `appRouterProvider` inside a `MaterialApp.router` with
/// the app's localization delegates. Uses FIXED pumps (never `pumpAndSettle`):
/// the splash screen animates indefinitely, which would never settle.
Future<GoRouter> pumpRouterApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  late GoRouter router;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return router;
}

/// Flattens a go_router route tree into `{routeName: fullPath}`.
///
/// go_router stores nested `GoRoute`s with RELATIVE paths (e.g. `menu` under
/// `/admin`), so the full path is recomposed from the parent prefix. This
/// walker works for both `GoRoute` and `ShellRoute` nesting.
Map<String, String> collectNamedRoutes(
  List<RouteBase> routes, [
  String parentPath = '',
]) {
  final out = <String, String>{};
  void walk(List<RouteBase> rs, String prefix) {
    for (final r in rs) {
      if (r is GoRoute) {
        final full = _joinPaths(prefix, r.path);
        final name = r.name;
        if (name != null && name.isNotEmpty) out[name] = full;
        walk(r.routes, full);
      } else if (r is ShellRoute) {
        walk(r.routes, prefix);
      }
    }
  }

  walk(routes, parentPath);
  return out;
}

/// The named routes a built [GoRouter] actually registered.
Map<String, String> routerNamedRoutes(GoRouter router) =>
    collectNamedRoutes(router.configuration.routes);

String _joinPaths(String prefix, String path) {
  if (path.startsWith('/')) return path;
  if (prefix.isEmpty) return '/$path';
  if (prefix.endsWith('/')) return '$prefix$path';
  return '$prefix/$path';
}
