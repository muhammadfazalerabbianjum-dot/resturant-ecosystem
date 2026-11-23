import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

/// PERF-1 (T-6) — DeliveryLocationModel serialization contract: the
/// generated fromJson/toJson round-trip, the null-island guard, and the
/// navigation deeplinks.

void main() {
  group('DeliveryLocationModel — generated JSON round-trip', () {
    test('fromJson restores every field', () {
      final model = DeliveryLocationModel.fromJson(<String, dynamic>{
        'latitude': 25.2048,
        'longitude': 55.2708,
        'address': 'Sheikh Zayed Road 1',
      });
      expect(model.latitude, 25.2048);
      expect(model.longitude, 55.2708);
      expect(model.address, 'Sheikh Zayed Road 1');
    });

    test('toJson emits every field; a round-trip is stable', () {
      const model = DeliveryLocationModel(
        latitude: 25.2048,
        longitude: 55.2708,
        address: 'Dubai Mall',
      );
      final json = model.toJson();
      expect(json['latitude'], 25.2048);
      expect(json['longitude'], 55.2708);
      expect(json['address'], 'Dubai Mall');

      expect(DeliveryLocationModel.fromJson(json), model);
    });

    test('a missing address falls back to the empty default', () {
      final model = DeliveryLocationModel.fromJson(<String, dynamic>{
        'latitude': 1.0,
        'longitude': 2.0,
      });
      expect(model.address, '');
    });
  });

  group('DeliveryLocationModel — guards and deeplinks', () {
    test('isValid rejects only the 0,0 null-island fix', () {
      const island = DeliveryLocationModel(latitude: 0, longitude: 0);
      const real = DeliveryLocationModel(latitude: 0.0001, longitude: 0);
      const lngOnly = DeliveryLocationModel(latitude: 0, longitude: 55.27);
      expect(island.isValid, isFalse);
      expect(real.isValid, isTrue);
      expect(lngOnly.isValid, isTrue);
    });

    test('the Google Maps deeplinks embed the coordinates', () {
      const model = DeliveryLocationModel(latitude: 25.2, longitude: 55.3);
      expect(model.googleMapsUrl, 'google.navigation:q=25.2,55.3');
      expect(
        model.googleMapsWebUrl,
        'https://www.google.com/maps/dir/?api=1&destination=25.2,55.3',
      );
    });
  });
}
