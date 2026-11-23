import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/auth/presentation/terms_of_service_screen.dart';
import '../../../helpers/app_localizations_test_helper.dart';

void main() {
  testWidgets('TermsOfServiceScreen renders app bar', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizationsTestHelper.delegates,
          supportedLocales: AppLocalizationsTestHelper.supportedLocales,
          home: TermsOfServiceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('TermsOfServiceScreen shows terms of service title', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizationsTestHelper.delegates,
          supportedLocales: AppLocalizationsTestHelper.supportedLocales,
          home: TermsOfServiceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Terms of Service'), findsAtLeastNWidgets(1));
  });

  testWidgets('TermsOfServiceScreen shows content text', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizationsTestHelper.delegates,
          supportedLocales: AppLocalizationsTestHelper.supportedLocales,
          home: TermsOfServiceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Please review our terms of service before using the app.'),
      findsOneWidget,
    );
  });

  testWidgets('TermsOfServiceScreen shows back button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizationsTestHelper.delegates,
          supportedLocales: AppLocalizationsTestHelper.supportedLocales,
          home: TermsOfServiceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('TermsOfServiceScreen does not crash', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizationsTestHelper.delegates,
          supportedLocales: AppLocalizationsTestHelper.supportedLocales,
          home: TermsOfServiceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
