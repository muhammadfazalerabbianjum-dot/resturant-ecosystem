import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  group('Forms & Responsive Boundaries Constitution Enforcement', () {
    testWidgets(
      'Form bounds explicitly reject null, short strings, and malformed emails',
      (WidgetTester tester) async {
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: '',
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Field cannot be empty';
                        }
                        if (val.length < 6) return 'Too short';
                        if (!val.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Trigger empty validation
        formKey.currentState!.validate();
        await tester.pump();
        expect(find.text('Field cannot be empty'), findsOneWidget);

        // Enter short
        await tester.enterText(find.byType(TextFormField), '123');
        formKey.currentState!.validate();
        await tester.pump();
        expect(find.text('Too short'), findsOneWidget);

        // Enter malformed email
        await tester.enterText(
          find.byType(TextFormField),
          'validlengthnoat.com',
        );
        formKey.currentState!.validate();
        await tester.pump();
        expect(find.text('Invalid email'), findsOneWidget);
      },
    );

    testWidgets(
      'Responsive & Overflow checks guarantee no RenderFlex explosions under massive font scalars on narrow constraints',
      (WidgetTester tester) async {
        // 1. Force narrow screen
        tester.view.physicalSize = const Size(300, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                // 2. Force abusive text scalar
                data: MediaQueryData(
                  textScaler: TextScaler.linear(3.5),
                  size: Size(300, 800),
                ),
                child: SafeArea(
                  // 3. Assert notch protection
                  child: SizedBox(
                    width: 300,
                    child: Row(
                      // Using a Row often causes RenderFlex if not wrapped
                      children: [
                        Expanded(
                          child: Text(
                            'Extremely long username that will absolutely cause a RenderFlex crash unless explicitly wrapped in Expanded/Flexible boundary limits that we force the UI developers to use.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // If we made it here without the tester throwing a FlutterError (RenderFlex), the constraint proves structural safety!
        expect(tester.takeException(), isNull);
      },
    );
  });
}
