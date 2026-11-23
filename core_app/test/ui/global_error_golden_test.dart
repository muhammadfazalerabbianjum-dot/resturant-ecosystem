import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/src/ui/global_error_widget.dart';

void main() {
  group('Global Visual Regression — Golden Tests', () {
    testWidgets('GlobalErrorWidget renders flawlessly in pure environment', (
      tester,
    ) async {
      final widget = MaterialApp(
        home: Scaffold(
          body: GlobalErrorWidget(
            errorDetails: FlutterErrorDetails(
              exception: Exception(
                'Simulated exception for Golden layout generation',
              ),
            ),
          ),
        ),
      );

      // Render the widget
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Assert against golden file (Law 17 & 22)
      await expectLater(
        find.byType(GlobalErrorWidget),
        matchesGoldenFile('goldens/global_error_widget.png'),
      );
    });
  });
}
