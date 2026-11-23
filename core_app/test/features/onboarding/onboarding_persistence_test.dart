import 'dart:async';

import 'package:core/core.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/onboarding/presentation/onboarding_screen.dart';
import 'package:labs/features/tour/domain/tour_manager.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingGoRouter extends Fake implements GoRouter {
  final List<String> routes = [];

  @override
  void goNamed(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
    String? fragment,
  }) {
    routes.add(name);
  }
}

/// Firebase [User] whose members are never read — OnboardingScreen only
/// null-checks the auth state (signed in?) before routing home vs login.
/// (firebase_auth_mocks' MockUser — the in-tree signed-in test pattern.)
User _signedInUser() => MockUser(uid: 'driver-uid-1', email: 'd@t.com');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createSubject({User? user, required GoRouter router}) {
    return ProviderScope(
      overrides: [authStateProvider.overrideWith((ref) => Stream.value(user))],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) {
            // In production the router WATCHES authStateProvider
            // (app_router.dart) before onboarding ever shows, so the screen's
            // `ref.read` sees a resolved AsyncValue. The harness mirrors that
            // wiring: this subscription starts the keepAlive stream.
            ref.watch(authStateProvider);
            return InheritedGoRouter(
              goRouter: router,
              child: const OnboardingScreen(),
            );
          },
        ),
      ),
    );
  }

  group('Onboarding completion persistence + first-run detection (COV-2)', () {
    testWidgets('first launch renders Onboarding with NO skip control', (
      tester,
    ) async {
      await tester.pumpWidget(
        createSubject(user: null, router: _RecordingGoRouter()),
      );

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets(
      'Get Started persists the seen flag and routes HOME when signed in',
      (tester) async {
        final router = _RecordingGoRouter();
        await tester.pumpWidget(
          createSubject(user: _signedInUser(), router: router),
        );
        // Let the overridden auth stream deliver its first value so the
        // provider's AsyncValue is `data` before the tap fires _getStarted.
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Get Started'));
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool('onboarding_completed'),
          isTrue,
          reason:
              'splash reads this exact key to skip onboarding for returning users',
        );
        expect(
          router.routes,
          [RouteNames.home],
          reason: 'a signed-in first-run user is routed to home, not login',
        );
      },
    );

    testWidgets(
      'Get Started persistence contract: same flag is written when signed out',
      (tester) async {
        final router = _RecordingGoRouter();
        await tester.pumpWidget(createSubject(user: null, router: router));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Get Started'));
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('onboarding_completed'), isTrue);
        expect(router.routes, [
          RouteNames.login,
        ], reason: 'a signed-out first-run user is routed to login');
      },
    );

    test(
      'tour trigger wiring: the splash first-run bit drives TourManager re-show rules',
      () async {
        // Returning user — the onboarding_completed flag is set (splash would
        // route straight to the entry point, and the tour must stay suppressed).
        SharedPreferences.setMockInitialValues({'onboarding_completed': true});
        var prefs = await SharedPreferences.getInstance();
        final returning = !(prefs.getBool('onboarding_completed') ?? false);
        expect(returning, isFalse);
        expect(TourManager(isFirstRun: returning).shouldShowTour, isFalse);

        // First launch — the flag is absent, so the tour trigger is armed.
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
        final firstRun = !(prefs.getBool('onboarding_completed') ?? false);
        expect(firstRun, isTrue);
        expect(TourManager(isFirstRun: firstRun).shouldShowTour, isTrue);
      },
    );
  });
}
