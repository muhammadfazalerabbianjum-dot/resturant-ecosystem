import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/config/force_update_guard.dart';
import 'package:labs/app/config/force_update_service.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/splash/presentation/splash_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// COV-1 — SPLASH force-update contract (STATE-3 / 04-P1-BOOT).
///
/// Two halves of the same STATE-3 pattern are pinned here:
///   1. splash-side parallel future — the version check is started by
///      [splashInitProvider] as an UNAWAITED future next to the auth race, so
///      a hung Remote Config can NEVER block the splash funnel (the check
///      failing/never completing still routes the user through);
///   2. guard-side first frame — [ForceUpdateGuard] renders the child
///      immediately (loading, error, `ok`) and swaps to the un-dismissible
///      lock screen ONLY on a real `required` verdict.

class MockLogger extends Mock implements LoggerService {}

class MockGoRouter extends Mock implements GoRouter {}

class MockAuthRepository extends Mock implements AuthRepository {}

const String _kChildMarker = 'CORE_CHILD';

void main() {
  late MockLogger mockLogger;
  late MockGoRouter mockRouter;

  setUp(() {
    mockLogger = MockLogger();
    mockRouter = MockGoRouter();
    SharedPreferences.setMockInitialValues({});
    when(
      () => mockLogger.error(any(), any(), stack: any(named: 'stack')),
    ).thenAnswer((_) async {});
    when(() => mockRouter.goNamed(any())).thenReturn(null);
  });

  group('splash force-update — parallel future (STATE-3, COV-1)', () {
    testWidgets('a hung Remote Config never blocks the splash init funnel', (
      tester,
    ) async {
      final hungCheck = Completer<ForceUpdateDecision>();
      final mockAuth = MockAuthRepository();
      // The auth stream emits immediately; the version check NEVER does.
      when(
        () => mockAuth.authStateChanges(),
      ).thenAnswer((_) => Stream<User?>.value(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loggerProvider.overrideWithValue(mockLogger),
            authRepositoryProvider.overrideWithValue(mockAuth),
            // The REAL splashInitProvider runs: it starts the force-update
            // check as a PARALLEL future and must never await it.
            forceUpdateStatusProvider.overrideWith((ref) => hungCheck.future),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InheritedGoRouter(
              goRouter: mockRouter,
              child: const SplashScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Navigation happened WHILE the version check was still hung: if the
      // splash ever awaited it, this route could not have fired.
      verify(() => mockRouter.goNamed(RouteNames.onboarding)).called(1);

      // The un-awaited force-update future never completes (by design), and
      // the REAL init funnel's 1 s cosmetic floor inside `Future.any` owns a
      // FakeAsync timer until it elapses. Advance the fake clock so the test
      // ends with no pending timers.
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group(
    'splash force-update — guard first frame / fail-open (STATE-3, COV-1)',
    () {
      testWidgets(
        'renders the child immediately while the check is still loading',
        (tester) async {
          final pendingCheck = Completer<ForceUpdateDecision>();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                forceUpdateStatusProvider.overrideWith(
                  (ref) => pendingCheck.future,
                ),
              ],
              // Production mounts the guard ABOVE the app's MaterialApp
              // (main.dart runApp wiring), so a Directionality ancestor always
              // exists around it — the harness mirrors that placement.
              child: const Directionality(
                textDirection: TextDirection.ltr,
                child: ForceUpdateGuard(child: Text(_kChildMarker)),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 10));

          expect(
            find.text(_kChildMarker),
            findsOneWidget,
            reason:
                'STATE-3: no pre-check spinner may ever hold the first frame — '
                'loading resolves to child',
          );
          expect(find.byIcon(Icons.system_update_alt), findsNothing);
        },
      );

      testWidgets('fails OPEN when the remote check errors', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              forceUpdateStatusProvider.overrideWith(
                (ref) => Future<ForceUpdateDecision>.error(
                  Exception('remote config down'),
                ),
              ),
            ],
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: ForceUpdateGuard(child: Text(_kChildMarker)),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 10));

        expect(
          find.text(_kChildMarker),
          findsOneWidget,
          reason: 'a failed/slow Remote Config must never trap the user',
        );
        expect(find.byIcon(Icons.system_update_alt), findsNothing);
      });

      testWidgets('fails OPEN when the verdict is ok', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              forceUpdateStatusProvider.overrideWith(
                (ref) => Future.value(
                  const ForceUpdateDecision(
                    status: ForceUpdateStatus.ok,
                    androidUpdateUrl: 'https://play.example/app',
                    iosUpdateUrl: 'https://apps.example/app',
                  ),
                ),
              ),
            ],
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: ForceUpdateGuard(child: Text(_kChildMarker)),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 10));

        expect(find.text(_kChildMarker), findsOneWidget);
        expect(find.byIcon(Icons.system_update_alt), findsNothing);
      });

      testWidgets('locks ONLY when the verdict is required', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              forceUpdateStatusProvider.overrideWith(
                (ref) => Future.value(
                  const ForceUpdateDecision(
                    status: ForceUpdateStatus.required,
                    androidUpdateUrl: 'https://play.example/app',
                    iosUpdateUrl: 'https://apps.example/app',
                  ),
                ),
              ),
            ],
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: ForceUpdateGuard(child: Text(_kChildMarker)),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 10));

        expect(
          find.text(_kChildMarker),
          findsNothing,
          reason: 'a required verdict swaps the whole tree for the lock screen',
        );
        expect(
          find.byIcon(Icons.system_update_alt),
          findsOneWidget,
          reason: 'the un-dismissible lock screen is up (with its store CTA)',
        );
        expect(find.byType(ElevatedButton), findsOneWidget);
      });
    },
  );
}
