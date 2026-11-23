/// Shared plumbing for the ARCH-1 shell router tests — a port of
/// `core_app/test/helpers/router_test_harness.dart` (the ROUTER-3 pattern)
/// into the generated shell: the shell's REAL router is built from the
/// shell's OWN bundled `assets/client_config.json` through the production
/// `appRouterProvider` from `package:labs`. These helpers only provide the
/// provider overrides every router build needs and a structural walker over
/// the actual go_router route tree.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:labs/labs.dart';

/// Puts [AppConfig] into config mode from the SHELL's bundled asset: resets
/// every static and loads `assets/client_config.json` (the client template —
/// the whitelisted screens on today's schema).
Future<void> loadRealConfigMode() async {
  AppConfig.resetForTest();
  await AppConfig.loadConfig();
}

/// Returns the overrides every router build needs (same contract as the
/// core_app harness):
/// - `authStateProvider`/`currentUserProvider` so the router's redirect can
///   resolve without Firebase. Pass [authUser] and [user] to simulate a
///   signed-in role.
/// - `loggerProvider` bound to the service's designed test seam
///   (`LoggerService(testDirectory:)`) so building the router never touches
///   the unmocked `path_provider` platform channel.
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

/// The overrides the home feed tab needs so the REAL HomeScreen renders
/// against controlled data in a widget test (no Firebase/Isar): an empty
/// merged menu, no pending sync / DLQ entries, no restaurant-config stream,
/// and a fail-safe HomeService double that returns no promotions.
///
/// Q2 (visual pack): pass [menu] to render a SEEDED grid — the full-screen
/// home capture needs real density evidence, not an empty state (the
/// critique's "the capture canvas tells no story"). Absent [menu] keeps the
/// original empty-stream behavior byte-for-byte.
///
/// These are test doubles over the production provider seams — the screens
/// themselves are the real `package:labs` production widgets.
class _FakeHomeService implements HomeService {
  @override
  Future<List<HomePromotion>> getPromotions() async => const <HomePromotion>[];

  @override
  Future<List<HomeBranch>> getBranches() async => const <HomeBranch>[];

  @override
  List<MenuItemModel> searchMenuItems(List<MenuItemModel> items, String query) {
    if (query.isEmpty) return items;
    final q = query.trim().toLowerCase();
    return items
        .where(
          (i) =>
              i.name.toLowerCase().contains(q) ||
              i.description.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  List<MenuItemModel> filterByCategory(
    List<MenuItemModel> items,
    String category,
  ) {
    if (category.isEmpty) return items;
    final c = category.trim().toLowerCase();
    return items
        .where(
          (i) =>
              i.category.toLowerCase() == c ||
              i.tags.any((t) => t.toLowerCase() == c),
        )
        .toList();
  }

  @override
  List<MenuItemModel> filterByMaxPrice(
    List<MenuItemModel> items,
    int maxPriceCents,
  ) {
    return items.where((i) => i.priceCents <= maxPriceCents).toList();
  }

  @override
  List<MenuItemModel> filterAvailable(List<MenuItemModel> items) {
    return items.where((i) => i.isAvailable).toList();
  }
}

List<Override> homeFeedOverrides({List<MenuItemModel>? menu}) {
  return [
    homeServiceProvider.overrideWithValue(_FakeHomeService()),
    mergedMenuProvider.overrideWith(
      (ref) =>
          Stream<List<MenuItemModel>>.value(menu ?? const <MenuItemModel>[]),
    ),
    restaurantConfigProvider.overrideWith(
      (ref) => const Stream<RestaurantConfigModel>.empty(),
    ),
    pendingSyncCountProvider.overrideWith((ref) => Stream<int>.value(0)),
    deadLetterCountProvider.overrideWith((ref) => Stream<int>.value(0)),
  ];
}

/// Pumps the production `appRouterProvider` inside a `MaterialApp.router`
/// themed with the SHELL's config palette ([AppConfig.theme]) and the labs
/// localization delegates. Uses FIXED pumps (never `pumpAndSettle`): the
/// splash screen animates indefinitely, which would never settle.
/// [theme] post-processes the real config theme for the capture (defaults to
/// the untouched `AppConfig.theme` so existing callers are byte-identical).
Future<GoRouter> pumpRouterApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
  ThemeData? theme,
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
            theme: theme ?? AppConfig.theme,
            // Q2/P2: the real app suppresses the debug banner (app_bootstrap)
            // — captures must not carry the "corner ribbon" the critique
            // flagged.
            debugShowCheckedModeBanner: false,
            darkTheme: AppConfig.darkTheme,
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
