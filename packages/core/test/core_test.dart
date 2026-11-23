import 'package:flutter_test/flutter_test.dart';

import 'package:core/core.dart';

void main() {
  group('core package barrel', () {
    test('exports pure models', () {
      const model = OperatingHoursModel();
      expect(model.monday, isA<DayHours>());
      expect(model.entries.length, 7);
    });

    test('exports converters', () {
      expect(const NumToIntConverter(), isA<NumToIntConverter>());
    });

    test('default config is safe', () {
      const config = DefaultCoreConfig();
      expect(config.isDemoMode, isFalse);
      // OFFLINE_FALLBACK defaults: EMPTY cloudinary credentials guarantee a
      // white-label shell can never silently upload into the reference app's
      // live Cloudinary account if composition (CoreConfig.set) is missed.
      expect(config.cloudinaryUploadPreset, isEmpty);
      expect(config.cloudinaryCloudName, isEmpty);
    });

    test('exports auth contract types', () {
      // References the abstract type only — no Firebase instantiation.
      expect(UserRole.customer, UserRole.customer);
    });
  });
}
