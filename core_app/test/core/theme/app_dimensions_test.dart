import 'package:flutter_test/flutter_test.dart';

// Law 3 dimension pins — AppDimensions EXISTS in core_ui; these assertions pin
// the live defaults (paddingM 16, paddingS 8, radiusM 12) against regression.
import 'package:core_ui/core_ui.dart';

void main() {
  group('AppDimensions Tests (Law 3 Compliance)', () {
    test('Standard padding is 16.0', () {
      expect(AppDimensions.paddingM, 16.0);
    });

    test('Small padding is 8.0', () {
      expect(AppDimensions.paddingS, 8.0);
    });

    test('Border radius is 12.0 for standard cards', () {
      expect(AppDimensions.radiusM, 12.0);
    });
  });
}
