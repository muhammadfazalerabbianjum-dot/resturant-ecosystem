import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/admin/presentation/privacy_policy_screen.dart';
import '../../../helpers/app_localizations_test_helper.dart';

void main() {
  testWidgets('PrivacyPolicyScreen renders app bar', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizationsTestHelper.delegates,
          supportedLocales: AppLocalizationsTestHelper.supportedLocales,
          home: PrivacyPolicyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('PrivacyPolicyScreen shows privacy policy title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizationsTestHelper.delegates,
          supportedLocales: AppLocalizationsTestHelper.supportedLocales,
          home: PrivacyPolicyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsAtLeastNWidgets(1));
  });

  testWidgets('PrivacyPolicyScreen shows privacy description text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizationsTestHelper.delegates,
          supportedLocales: AppLocalizationsTestHelper.supportedLocales,
          home: PrivacyPolicyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Please review our privacy policy to understand how we handle your data.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('PrivacyPolicyScreen shows back button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizationsTestHelper.delegates,
          supportedLocales: AppLocalizationsTestHelper.supportedLocales,
          home: PrivacyPolicyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('PrivacyPolicyScreen does not crash', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizationsTestHelper.delegates,
          supportedLocales: AppLocalizationsTestHelper.supportedLocales,
          home: PrivacyPolicyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
