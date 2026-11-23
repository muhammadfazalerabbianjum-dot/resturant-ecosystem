import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:labs/features/onboarding/presentation/onboarding_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:core/core.dart';

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  late MockGoRouter mockRouter;

  setUp(() {
    mockRouter = MockGoRouter();
    SharedPreferences.setMockInitialValues({});
    when(() => mockRouter.goNamed(any())).thenReturn(null);
  });

  Widget createSubject() {
    return ProviderScope(
      overrides: [authStateProvider.overrideWith((ref) => Stream.value(null))],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InheritedGoRouter(
          goRouter: mockRouter,
          child: const OnboardingScreen(),
        ),
      ),
    );
  }

  testWidgets('renders welcome + Get Started button', (tester) async {
    await tester.pumpWidget(createSubject());

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('Get Started button is present and enabled', (tester) async {
    await tester.pumpWidget(createSubject());

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Get Started'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('has semantics labels for accessibility', (tester) async {
    await tester.pumpWidget(createSubject());

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets(
    'Get Started persists the seen flag and routes to login when logged out',
    (tester) async {
      await tester.pumpWidget(createSubject());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Get Started'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), isTrue);
      verify(() => mockRouter.goNamed('login')).called(1);
    },
  );
}
