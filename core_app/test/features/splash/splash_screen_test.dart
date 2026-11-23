import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:labs/features/splash/presentation/splash_screen.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class MockLogger extends Mock implements LoggerService {}

class MockGoRouter extends Mock implements GoRouter {}

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

  Widget createSubject(Override initOverride) {
    return ProviderScope(
      overrides: [loggerProvider.overrideWithValue(mockLogger), initOverride],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InheritedGoRouter(
          goRouter: mockRouter,
          child: const SplashScreen(),
        ),
      ),
    );
  }

  testWidgets('Splash navigates to onboarding when init succeeds', (
    tester,
  ) async {
    await tester.pumpWidget(
      createSubject(splashInitProvider.overrideWith((ref) => Future.value())),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    verify(() => mockRouter.goNamed(RouteNames.onboarding)).called(1);
  });

  testWidgets('Splash shows error and retry when init fails', (tester) async {
    await tester.pumpWidget(
      createSubject(
        splashInitProvider.overrideWith(
          (ref) => Future.error(Exception('Failed')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Initialization failed. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    verify(
      () => mockLogger.error(any(), any(), stack: any(named: 'stack')),
    ).called(1);
    verifyNever(() => mockRouter.goNamed(any()));
  });

  testWidgets('Splash shows error on timeout', (tester) async {
    await tester.pumpWidget(
      createSubject(
        splashInitProvider.overrideWith((ref) {
          return Future.error(TimeoutException('Timeout'));
        }),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Initialization took too long'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('P21 C1: the loading body renders through BrandedSplash (W-5)', (
    tester,
  ) async {
    await tester.pumpWidget(
      createSubject(splashInitProvider.overrideWith((ref) => Future.value())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Adoption proof: the hand-rolled Icon/Text/Spinner Column is replaced by
    // the frozen library splash (routing/timing logic above is untouched).
    expect(find.byType(BrandedSplash), findsOneWidget);
  });
}
