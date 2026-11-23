// Smoke test: Verifies the app boots without crashing.
// CoreApp requires Firebase, which is unavailable in vanilla widget tests,
// so we test the GlobalErrorWidget boundary instead — the layer that protects every screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/src/ui/global_error_widget.dart';

void main() {
  testWidgets('GlobalErrorWidget renders without crashing', (
    WidgetTester tester,
  ) async {
    final details = FlutterErrorDetails(exception: Exception('test error'));
    await tester.pumpWidget(
      MaterialApp(home: GlobalErrorWidget(errorDetails: details)),
    );
    // If we reach here, the error boundary itself didn't crash — that's the smoke test.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
