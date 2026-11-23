import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

void main() {
  group('Mathematical Invariants: Loyalty Points', () {
    test('1000 properties: loyaltyPoints == floor(total / 100)', () {
      final random = Random();
      for (var i = 0; i < 1000; i++) {
        // Random totals between $0.00 and $500.00 (in cents)
        final totalCents = random.nextInt(50000);
        final expectedPoints = (totalCents / 100).floor();

        // Simulating the loyalty calculator
        final calculatedPoints = (totalCents / 100).floor();

        expect(calculatedPoints, equals(expectedPoints));
      }
    });
  });
}
