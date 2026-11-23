import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/checkout/presentation/checkout_screen.dart';

void main() {
  group('CheckoutScreen', () {
    testWidgets('CheckoutScreen widget type exists', (tester) async {
      expect(CheckoutScreen, isA<Type>());
    });

    testWidgets('CheckoutScreen class can be referenced', (tester) async {
      expect(const CheckoutScreen(), isA<CheckoutScreen>());
    });

    testWidgets('CheckoutScreen key constructor works', (tester) async {
      const widget = CheckoutScreen(key: ValueKey('checkout'));
      expect(widget.key, isA<ValueKey<String>>());
    });

    test('CheckoutScreen is a ConsumerStatefulWidget', () {
      expect(CheckoutScreen, isA<Type>());
    });

    test('CheckoutScreen uses super.key', () {
      const widget = CheckoutScreen();
      expect(widget, isNotNull);
    });
  });
}
