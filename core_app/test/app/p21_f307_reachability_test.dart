// UI-13 (p21) phase G3 — F3-07 tail reachability receipts (contract §3-G3).
//
// `LogsScreen` and `BugReporterOverlay` were listed by the register as
// "unassigned surfaces" (F3-07) even though both are ALREADY wired:
//   - `app_router.dart` registers `RouteNames.logs` (`/logs`) and
//     `RouteNames.errorLogs` (`/error-logs`), each rendering a `LogsScreen`,
//     plus the config-mode `screenIdToRouteName` `LogsScreen` case;
//   - `app_bootstrap.dart:904` composes `BugReporterOverlay(...)` as the
//     `MaterialApp.router` builder, which gates the diagnostics FAB by the
//     build-mode seam.
//
// This file PROVES that claim — it rebuilds nothing and edits no production
// file. Three shapes of evidence:
//   1. static-mode registration (name -> path) from the real router tree;
//   2. widget-level navigation to `/logs` and `/error-logs` on the real router,
//      which renders the library `LogsScreen`;
//   3. the B6-2 seam halves of `BugReporterOverlay` (reachable in dev,
//      unreachable in release), asserted hermetically so they run in the
//      default battery — the older `test/widget/bug_reporter_test.dart` is
//      tagged `needs-emulator` and does not.
//
// STATIC-MODE NOTE: the splash screen calls `AppConfig.loadConfig()`
// (`splash_screen.dart:22`), which loads the REAL bundled `client_config.json`
// and flips the router into config mode — where both diagnostic routes are
// deliberately NOT registered (the ROUTER-3 suite proves that half). The config
// asset is therefore mocked here with a schema-valid payload whose `screens`
// list is empty, so `loadConfig()` early-returns from `_loaded` and the router
// stays in the static fallback that owns these two routes. The asset channel is
// restored in `tearDown`.
import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart' show BugReporterOverlay, LogsScreen;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/app_router.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/l10n/app_localizations.dart';

import '../helpers/router_test_harness.dart';

const String _assetChannel = 'flutter/assets';

/// Schema-valid client config with NO config-driven screens: `loadConfig()`
/// succeeds, `_loaded` flips true, and the router keeps its static fallback
/// (the one that registers `/logs` and `/error-logs`).
String _emptyScreensConfig() => jsonEncode(<String, dynamic>{
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
  'navigation': <String, dynamic>{'entryPoint': '/splash'},
  'features': <String, dynamic>{'flags': <String, dynamic>{}},
  'screens': <dynamic>[],
});

void _mockClientConfigAsset() {
  final body = _emptyScreensConfig();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(_assetChannel, (message) async {
        if (message == null) return null;
        final key = utf8.decode(message.buffer.asUint8List());
        if (key != 'assets/client_config.json') return null;
        return ByteData.view(Uint8List.fromList(utf8.encode(body)).buffer);
      });
}

/// Logger with a deterministic in-memory log line, so the diagnostics surface
/// reads real content without touching a platform channel or a file.
class _FakeReadLogsLogger implements LoggerService {
  @override
  Future<List<String>> readLogs() async => const ['Crash Event 1'];

  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {}

  @override
  Future<void> info(Map<String, dynamic> context, String message) async {}

  @override
  Future<void> warn(Object error, String message, {StackTrace? stack}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps the production router and returns a getter for its CURRENT instance
/// (the provider can rebuild when auth resolves; reading through the getter
/// keeps the test on the live router instead of a discarded one).
///
/// Uses fixed pumps, never `pumpAndSettle`: the splash animates indefinitely.
Future<GoRouter Function()> _pumpStaticRouter(WidgetTester tester) async {
  late GoRouter router;
  await tester.pumpWidget(
    ProviderScope(
      overrides: routerAuthOverrides(
        authUser: MockUser(uid: 'p21-f307', email: 'p21@test.com'),
        user: const UserModel(id: 'p21-f307', role: UserRole.customer),
      ),
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
  return () => router;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.resetForTest();
    _mockClientConfigAsset();
    // Loads a schema-valid config with zero config-driven screens: the router
    // keeps its static fallback, and the splash's own `loadConfig()` call
    // early-returns from `_loaded` instead of flipping into config mode.
    await AppConfig.loadConfig();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, null);
    AppConfig.resetForTest();
  });

  test('the diagnostics routes are registered by name and path', () {
    final container = ProviderContainer(overrides: routerAuthOverrides());
    addTearDown(container.dispose);

    final registered = routerNamedRoutes(container.read(appRouterProvider));

    expect(registered[RouteNames.logs], '/logs');
    expect(registered[RouteNames.errorLogs], '/error-logs');
  });

  testWidgets('/logs resolves to the library LogsScreen', (tester) async {
    final live = await _pumpStaticRouter(tester);

    live().go('/logs');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(LogsScreen), findsOneWidget);
    expect(find.byKey(const Key('logsTitle')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/error-logs resolves to the library LogsScreen', (tester) async {
    final live = await _pumpStaticRouter(tester);

    live().go('/error-logs');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(LogsScreen), findsOneWidget);
    expect(find.byKey(const Key('logsTitle')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BugReporterOverlay: seam ON => the FAB opens LogsScreen', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          loggerProvider.overrideWithValue(_FakeReadLogsLogger()),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: BugReporterOverlay(
            navigatorKey: navigatorKey,
            debugShowBugReporter: true,
            child: const Scaffold(body: Text('HomeSurface')),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byIcon(Icons.bug_report), findsOneWidget);
    expect(find.byKey(const Key('logsTitle')), findsNothing);

    await tester.tap(find.byIcon(Icons.bug_report));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The diagnostics surface is genuinely reachable in a dev build.
    expect(find.byKey(const Key('logsTitle')), findsOneWidget);
    expect(find.text('Crash Event 1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('BugReporterOverlay: seam OFF => LogsScreen is unreachable', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          loggerProvider.overrideWithValue(_FakeReadLogsLogger()),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: BugReporterOverlay(
            navigatorKey: navigatorKey,
            debugShowBugReporter: false,
            child: const Scaffold(body: Text('HomeSurface')),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Release half of the B6-2 contract: no FAB => no route into the logs.
    expect(find.byIcon(Icons.bug_report), findsNothing);
    expect(find.byKey(const Key('logsTitle')), findsNothing);
    expect(find.text('HomeSurface'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
