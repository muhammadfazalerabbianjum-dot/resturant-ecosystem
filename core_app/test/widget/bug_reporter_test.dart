@Tags(['needs-emulator'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/app/app_router.dart';
import 'package:labs/app_bootstrap.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLogger extends Mock implements LoggerService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets(
    'BugReporterOverlay (B6-2) — FAB available ONLY when build-mode seam is on',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockLogger = MockLogger();
      when(
        () => mockLogger.readLogs(),
      ).thenAnswer((_) async => ['Crash Event 1', 'Crash Event 2']);

      final dummyRouter = GoRouter(
        navigatorKey: navigatorKey,
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
        ],
      );

      // 1) OVERLAY with the production default played through the seam:
      //    in a debug/profile build the FAB IS present, and tapping it opens
      //    the internal LogsScreen (dev-only diagnostics).
      //
      // We construct the overlay directly (not via CoreApp) so the test does
      // not couple to the router/auto-sync that crashed before — and so we can
      // prove BOTH halves of the B6-2 contract:
      //    - seam ON  -> FAB rendered, LogsScreen reachable (dev builds)
      //    - seam OFF -> no FAB, LogsScreen UNREACHABLE (release builds)
      Future<void> pumpOverlay({required bool seamOn}) {
        return tester.pumpWidget(
          ProviderScope(
            overrides: [
              loggerProvider.overrideWithValue(mockLogger),
              appRouterProvider.overrideWithValue(dummyRouter),
            ],
            child: MaterialApp(
              home: BugReporterOverlay(
                navigatorKey: navigatorKey,
                debugShowBugReporter: seamOn,
                child: const Scaffold(body: Text('Home')),
              ),
            ),
          ),
        );
      }

      await pumpOverlay(seamOn: true);
      await tester.pump(const Duration(milliseconds: 500));

      final fabFinder = find.byIcon(Icons.bug_report);
      expect(
        fabFinder,
        findsOneWidget,
        reason: 'debug/profile build shows FAB',
      );

      await tester.tap(fabFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Genuine diagnostic surface DID open (dev builds).
      expect(find.byKey(const Key('logsTitle')), findsOneWidget);

      // Tear down the widget tree so the open modal sheet is disposed.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('logsTitle')), findsNothing);

      // 2) RELEASE MODE (seam OFF): no FAB => LogsScreen unreachable.
      await pumpOverlay(seamOn: false);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byIcon(Icons.bug_report), findsNothing);
      expect(find.byKey(const Key('logsTitle')), findsNothing);
    },
  );
}
