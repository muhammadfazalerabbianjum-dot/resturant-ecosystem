import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';

void main() {
  testWidgets('EmptyStateWidget renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            icon: Icons.info_outline,
            title: 'No Items',
            subtitle: 'There are no items to display.',
          ),
        ),
      ),
    );
    expect(find.text('No Items'), findsOneWidget);
    expect(find.text('There are no items to display.'), findsOneWidget);
  });

  testWidgets('EmptyStateWidget renders icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            icon: Icons.shopping_cart_outlined,
            title: 'Empty',
            subtitle: 'Nothing here',
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
  });

  testWidgets('EmptyStateWidget renders CTA button when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            icon: Icons.error_outline,
            title: 'Error',
            subtitle: 'Something went wrong',
            ctaText: 'Retry',
            onCtaPressed: () {},
          ),
        ),
      ),
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('EmptyStateWidget does not render CTA button without text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            icon: Icons.info,
            title: 'Info',
            subtitle: 'No action needed',
          ),
        ),
      ),
    );
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('EmptyStateWidget renders without crashing with all params', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            icon: Icons.check_circle,
            title: 'Success',
            subtitle: 'Operation completed',
            ctaText: 'Continue',
            onCtaPressed: () {},
          ),
        ),
      ),
    );
    expect(find.text('Success'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  // Regression pin for the on-device defect (screenshots 20/22, 1280x2856
  // @3.0): the empty-state block rendered centered at x=552 instead of 640
  // because the Column shrinks to its widest child under the loose
  // cross-axis constraints every Scaffold body / Stack child provides, then
  // hugs the topStart corner. Minimal content exposes the shrink-wrap (the
  // default test font would otherwise wrap wide strings and mask it).
  Future<double> centerX(WidgetTester tester, Widget host) async {
    tester.view.physicalSize = const Size(1280, 2856);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host);
    return tester.getCenter(find.byType(EmptyStateWidget)).dx;
  }

  const logicalCenter = 1280 / 3.0 / 2;

  testWidgets('centers horizontally as a direct Scaffold body (loose width)', (
    tester,
  ) async {
    final cx = await centerX(
      tester,
      const MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            icon: Icons.shopping_cart_outlined,
            title: 'T',
            subtitle: 'S',
          ),
        ),
      ),
    );
    expect(cx, closeTo(logicalCenter, 2));
  });

  testWidgets(
    'centers horizontally inside the app tab shell (Column > Expanded > IndexedStack)',
    (tester) async {
      final cx = await centerX(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: 0,
                    children: [
                      Scaffold(
                        body: EmptyStateWidget(
                          icon: Icons.shopping_cart_outlined,
                          title: 'T',
                          subtitle: 'S',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(cx, closeTo(logicalCenter, 2));
    },
  );
}
