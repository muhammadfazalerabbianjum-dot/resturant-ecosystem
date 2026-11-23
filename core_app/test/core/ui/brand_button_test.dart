import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/src/ui/brand_button.dart';
import 'package:core_ui/src/theme/app_theme.dart';

void main() {
  testWidgets('BrandButton renders correct styling and handles taps', (
    WidgetTester tester,
  ) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: BrandButton(
            text: 'Test Button',
            onPressed: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    // Verify it renders the text
    expect(find.text('Test Button'), findsOneWidget);

    // Verify button exists
    expect(find.byType(ElevatedButton), findsOneWidget);

    // Tap the button
    await tester.tap(find.text('Test Button'));
    await tester.pumpAndSettle();

    expect(tapped, true);
  });

  testWidgets('BrandButton shows loading indicator when isLoading is true', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: BrandButton(text: 'Test Button', isLoading: true),
        ),
      ),
    );

    // Should hide text and show CircularProgressIndicator
    expect(find.text('Test Button'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
