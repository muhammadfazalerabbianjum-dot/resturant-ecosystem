import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:core_ui/src/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    test('primary color is C84F00 (darkened orange, AA on white — W9.1)', () {
      expect(AppColors.primary, const Color(0xFFC84F00));
    });

    test('background color is white', () {
      expect(AppColors.background, const Color(0xFFFFFFFF));
    });

    test('textPrimary color is dark grey', () {
      expect(AppColors.textPrimary, const Color(0xFF1E1E1E));
    });

    test('textSecondary color is darkened grey (AA on white — W9.1)', () {
      expect(AppColors.textSecondary, const Color(0xFF757575));
    });

    test('error color is red', () {
      expect(AppColors.error, const Color(0xFFE53935));
    });

    test('success color is darkened green (AA on white — W9.1)', () {
      expect(AppColors.success, const Color(0xFF2E7D32));
    });

    test('warning color is amber', () {
      expect(AppColors.warning, const Color(0xFFFFC107));
    });

    test('transparent color is fully transparent', () {
      expect(AppColors.transparent, const Color(0x00000000));
    });

    test('background54 has 54% opacity', () {
      expect(AppColors.background54, const Color(0x8AFFFFFF));
    });

    test('background70 has 70% opacity', () {
      expect(AppColors.background70, const Color(0xB3FFFFFF));
    });

    test('textPrimary12 has 12% opacity', () {
      expect(AppColors.textPrimary12, const Color(0x1F1E1E1E));
    });

    test('textPrimary45 has 45% opacity', () {
      expect(AppColors.textPrimary45, const Color(0x731E1E1E));
    });

    test('textPrimary54 has 54% opacity', () {
      expect(AppColors.textPrimary54, const Color(0x8A1E1E1E));
    });
    // FIX-B7 T-3 (AUD1-10): two tests pinning the dead AppColors shadow
    // tokens were deleted together with those declarations — no production
    // call site existed, so nothing else covered them.
  });
}
