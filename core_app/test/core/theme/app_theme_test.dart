import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/src/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets(
    'AppTheme psychological palette and typography mapping resolves correctly',
    (WidgetTester tester) async {
      // We override default text rendering to avoid external HTTP requests for Google Fonts during tests
      GoogleFonts.config.allowRuntimeFetching = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: AppBar(title: const Text('AppTheme Test')),
            body: Text(
              'Body Copy',
              style: AppTheme.lightTheme.textTheme.bodyMedium,
            ),
          ),
        ),
      );

      // Validate Colors
      expect(
        AppTheme.lightTheme.colorScheme.primary.toARGB32(),
        const Color(0xFFC84F00).toARGB32(),
      ); // Carnama Orange (darkened for AA contrast, W9.1)
      expect(
        AppTheme.lightTheme.colorScheme.secondary.toARGB32(),
        const Color(0xFF1D3557).toARGB32(),
      ); // Prussian Blue

      // Validate App Bar renders with background color constraint
      expect(
        AppTheme.lightTheme.appBarTheme.backgroundColor,
        AppTheme.backgroundColor,
      );

      // Validating basic widget mounts without throwing Exceptions
      expect(find.text('Body Copy'), findsOneWidget);
    },
  );
}
