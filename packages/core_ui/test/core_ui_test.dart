import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core_ui/core_ui.dart';

void main() {
  group('core_ui barrel exports', () {
    test('AppColors resolves from package barrel', () {
      expect(AppColors.primary, const Color(0xFFC84F00)); // W9.1 AA palette
    });

    test('AppTheme exposes light and dark themes', () {
      expect(AppTheme.lightTheme.brightness, Brightness.light);
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
    });
  });

  group('core_ui widgets', () {
    testWidgets('BrandButton renders label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BrandButton(text: 'Order Now', onPressed: null)),
        ),
      );

      expect(find.text('Order Now'), findsOneWidget);
    });

    testWidgets('BrandButton fires onPressed exactly ONCE per tap', (
      tester,
    ) async {
      var tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrandButton(text: 'Order Now', onPressed: () => tapCount++),
          ),
        ),
      );

      await tester.tap(find.text('Order Now'));
      await tester.pumpAndSettle();
      expect(tapCount, 1);
    });

    testWidgets('GlobalErrorWidget renders errorDetails text', (tester) async {
      final details = FlutterErrorDetails(
        exception: Exception('Test failure message'),
        library: 'test',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GlobalErrorWidget(errorDetails: details)),
        ),
      );

      expect(find.textContaining('Test failure message'), findsOneWidget);
    });

    testWidgets('GlobalErrorWidget renders localized title/body over English', (
      tester,
    ) async {
      final details = FlutterErrorDetails(
        exception: Exception('Test failure message'),
        library: 'test',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlobalErrorWidget(
              errorDetails: details,
              title: 'Something went wrong',
              body: 'Our team has been notified.',
            ),
          ),
        ),
      );

      // In-app call sites pass localized copy — no hardcoded English body.
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Our team has been notified.'), findsOneWidget);
      expect(
        find.text('Our team has been notified. Please try refreshing.'),
        findsNothing,
      );
    });

    testWidgets(
      'BugReporterOverlay hides FAB (release guard) when seam is off',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: BugReporterOverlay(
              debugShowBugReporter: false,
              child: Scaffold(body: Text('App body')),
            ),
          ),
        );

        // Only the child renders — no bug-reporter FAB, LogsScreen unreachable.
        expect(find.text('App body'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);
        final fab = find.byIcon(Icons.bug_report);
        expect(fab, findsNothing);
      },
    );

    testWidgets(
      'BugReporterOverlay shows the FAB when the build-mode seam is on',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: BugReporterOverlay(
              debugShowBugReporter: true,
              child: Scaffold(body: Text('App body')),
            ),
          ),
        );

        expect(find.text('App body'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byIcon(Icons.bug_report), findsOneWidget);
      },
    );

    testWidgets('EmptyStateWidget renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.fastfood,
              title: 'No orders yet',
              subtitle: 'Your orders will appear here.',
            ),
          ),
        ),
      );

      expect(find.text('No orders yet'), findsOneWidget);
      expect(find.text('Your orders will appear here.'), findsOneWidget);
    });
  });
}
