import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/tour/domain/tour_manager.dart';

void main() {
  group('TourManager Domain Tests', () {
    test('shows tour on first run and provides 3 step keys', () {
      final manager = TourManager(isFirstRun: true);
      expect(manager.shouldShowTour, isTrue);
      expect(manager.tourStepKeys, hasLength(3));
      expect(manager.tourStepKeys, contains('tourStep1'));
      expect(manager.tourStepKeys, contains('tourStep2'));
      expect(manager.tourStepKeys, contains('tourStep3'));
    });

    test('suppresses tour when isFirstRun is false', () {
      final manager = TourManager(isFirstRun: false);
      expect(manager.shouldShowTour, isFalse);
    });
  });
}
