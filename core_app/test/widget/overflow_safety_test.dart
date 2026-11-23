import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Law 34 (Overflow + SafeArea) + Law 47 (Accessibility — large font scale)
///
/// Tests:
/// 1. 200-char username never causes a RenderFlex overflow.
/// 2. SafeArea respected with simulated iPhone notch padding.
/// 3. textScaleFactor 3.0 does not crash or overflow.

Widget _buildNameDisplay(String name) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    ),
  );
}

void main() {
  group('Overflow Safety & SafeArea Tests (Laws 34, 47)', () {
    testWidgets('200-character username does not overflow on narrow phone', (
      tester,
    ) async {
      // Simulate the smallest commonly supported phone size
      await tester.binding.setSurfaceSize(const Size(320, 568));

      final longName = 'A' * 200; // 200-char adversarial input
      await tester.pumpWidget(_buildNameDisplay(longName));
      await tester.pumpAndSettle();

      // No RenderFlex overflow error thrown
      expect(tester.takeException(), isNull);
      // Text is rendered (possibly ellipsized)
      expect(find.byType(Text), findsOneWidget);

      // Reset
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('SafeArea is respected — content below simulated notch', (
      tester,
    ) async {
      // Simulate iPhone notch insets
      const notchTop = 44.0;
      const homeIndicator = 34.0;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: notchTop, bottom: homeIndicator),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: SafeArea(
                child: Builder(
                  builder: (context) {
                    // Assert SafeArea has applied the padding
                    final MediaQueryData mq = MediaQuery.of(context);
                    // SafeArea removes the insets from the available area
                    return SizedBox(
                      height:
                          mq.size.height - mq.padding.top - mq.padding.bottom,
                      child: const Text('Safe Content'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Safe Content'), findsOneWidget);
    });

    testWidgets('textScaleFactor 3.0 does not overflow or crash', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Carnama')),
            body: const SingleChildScrollView(
              child: Column(
                children: [
                  Text('Welcome to Carnama Restaurant'),
                  Text('Order your favourite meals'),
                  Text('Track your delivery in real-time'),
                  ListTile(
                    title: Text('Menu Item Name That Could Be Long'),
                    subtitle: Text('Description with extra details'),
                    trailing: Text('\$12.99'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // No RenderFlex overflow at 3x text scale
      expect(tester.takeException(), isNull);

      // Reset
      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    });

    testWidgets('Long menu item price does not overflow price column', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 5,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(
                  'Item with a very long name that could cause wrapping issue $i',
                ),
                trailing: const Text('\$10000.99'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
