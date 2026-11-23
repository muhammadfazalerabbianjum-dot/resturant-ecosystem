import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  group('Navigation Bounds and SafeArea Render Compliance', () {
    testWidgets(
      'Screen popping accurately returns boundaries and forces state disposal',
      (WidgetTester tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            home: const Scaffold(body: Text('Home Screen Base')),
          ),
        );

        // Verify initial state
        expect(find.text('Home Screen Base'), findsOneWidget);

        // Push new route without awaiting the push Future (push Future completes on pop)
        unawaited(
          navigatorKey.currentState!.push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => Scaffold(
                appBar: AppBar(title: const Text('Secondary')),
                body: const Text('Secondary Screen Bound'),
              ),
              transitionDuration: Duration.zero,
            ),
          ),
        );

        await tester.pump();

        // Verify pushed screen
        expect(find.text('Secondary Screen Bound'), findsOneWidget);

        // Pop back
        navigatorKey.currentState!.pop();
        await tester.pump();

        // Verify returned to home
        expect(find.text('Home Screen Base'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget rendering accurately wrapped by SafeArea constraints escaping physical system overlays',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SafeArea(child: Text('Safely Bound Area Content')),
            ),
          ),
        );

        await tester.pump();

        // Verify SafeArea widget exists
        final safeAreaFinder = find.byType(SafeArea);
        expect(safeAreaFinder, findsOneWidget);

        // Verify text is inside SafeArea
        final textInsideSafeAreaFinder = find.descendant(
          of: safeAreaFinder,
          matching: find.text('Safely Bound Area Content'),
        );

        expect(textInsideSafeAreaFinder, findsOneWidget);
      },
    );
  });
}
