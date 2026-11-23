import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';

import 'package:labs/l10n/app_localizations.dart';

/// B6-1 — the global error surface renders in the ACTIVE locale.
///
/// Regression: `GlobalErrorWidget` previously hardcoded English
/// ('Our team has been notified. Please try refreshing.') so an Arabic user
/// saw English on the P5-12 error surface. In-app call sites pass
/// `AppLocalizations`-driven copy; this test proves the Arabic path renders
/// Arabic and the hardcoded English fallback does NOT appear.
void main() {
  Widget buildSubject() {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ar'),
      home: Builder(
        builder: (context) {
          final loc = AppLocalizations.of(context);
          return Scaffold(
            body: GlobalErrorWidget(
              errorDetails: FlutterErrorDetails(
                exception: Exception('Test failure message'),
                library: 'test',
              ),
              title: loc.globalErrorTitle,
              body: loc.globalErrorBody,
            ),
          );
        },
      ),
    );
  }

  testWidgets('Arabic locale renders Arabic error copy, not English fallback', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Arabic localized copy is what the user sees...
    expect(find.text('حدث خطأ ما'), findsOneWidget);
    expect(find.text('تم إخطار فريقنا. يرجى محاولة التحديث.'), findsOneWidget);

    // ...and the hardcoded English fallback string is NOT on the surface.
    expect(
      find.text('Our team has been notified. Please try refreshing.'),
      findsNothing,
    );
    expect(find.text('Something went wrong'), findsNothing);
  });
}
