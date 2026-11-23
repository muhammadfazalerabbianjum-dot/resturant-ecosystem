// UI-13 (p21 C3) — D-3 three-case proof for the guided-tour wiring (L30):
// (a) the tour IS presented when TourManager.shouldShowTour says yes,
// (b) NOTHING is presented when it says no,
// (c) the first-run flag is written exactly once — the flow's single
//     `onboarding_completed` write, no tour flag, and the re-decision after
//     completion is suppressed (idempotent, Law 9).
//
// The harness uses a REAL GoRouter (production navigation shape) so the
// push-after-route ordering is exercised for real, not against a fake.
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/onboarding/presentation/onboarding_screen.dart';
import 'package:labs/features/tour/domain/tour_manager.dart';
import 'package:labs/features/tour/presentation/tour_overlay.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

GoRouter _router() => GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      name: RouteNames.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/home',
      name: RouteNames.home,
      builder: (context, state) => const Scaffold(body: Text('HOME_DEST')),
    ),
    GoRoute(
      path: '/login',
      name: RouteNames.login,
      builder: (context, state) => const Scaffold(body: Text('LOGIN_DEST')),
    ),
  ],
);

Widget _app(GoRouter router) => ProviderScope(
  // Signed-out first-run user -> the flow routes to LOGIN_DEST under the tour.
  overrides: [
    authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
  ],
  child: MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  ),
);

Future<void> _completeOnboarding(WidgetTester tester) async {
  await tester.pumpWidget(_app(_router()));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ElevatedButton, 'Get Started'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('D-3 (a): first run -> the tour IS presented over the '
      'destination', (tester) async {
    await _completeOnboarding(tester);

    expect(find.byType(TourOverlay), findsOneWidget);
    expect(
      find.text('LOGIN_DEST', skipOffstage: false),
      findsOneWidget,
      reason: 'the flow still routes first (behaviour unchanged)',
    );
    // Dismiss through the production pop path.
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(TourOverlay), findsNothing);
    expect(find.text('LOGIN_DEST'), findsOneWidget);
  });

  testWidgets('D-3 (b): returning user -> NOTHING is presented', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    await _completeOnboarding(tester);

    expect(find.byType(TourOverlay), findsNothing);
    expect(find.text('LOGIN_DEST', skipOffstage: false), findsOneWidget);
  });

  testWidgets(
    'D-3 (c): the first-run flag is written exactly once (single key, no tour '
    'flag, re-decision suppressed)',
    (tester) async {
      await _completeOnboarding(tester);
      expect(find.byType(TourOverlay), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys(),
        ['onboarding_completed'],
        reason: 'the flow writes its one flag; the tour persists NOTHING',
      );
      expect(prefs.getBool('onboarding_completed'), isTrue);

      // Law 9 idempotency: the written flag flips the decision, so a later
      // evaluation can never re-arm the tour.
      final firstRun = !(prefs.getBool('onboarding_completed') ?? false);
      expect(TourManager(isFirstRun: firstRun).shouldShowTour, isFalse);

      // Dismiss, then re-run the flow from a fresh mount: still suppressed.
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(_router()));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Get Started'));
      await tester.pumpAndSettle();
      expect(find.byType(TourOverlay), findsNothing);
    },
  );
}
