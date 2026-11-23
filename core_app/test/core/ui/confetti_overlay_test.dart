import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/src/ui/confetti_overlay.dart';

void main() {
  group('ConfettiOverlay', () {
    test('class exists', () {
      expect(ConfettiOverlay, isA<Type>());
    });

    test('show static method exists', () {
      expect(ConfettiOverlay.show, isA<Function>());
    });
  });
}
