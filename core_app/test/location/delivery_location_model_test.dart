import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

void main() {
  group('DeliveryLocationModel', () {
    test('constructs with lat/lng and address', () {
      const model = DeliveryLocationModel(
        latitude: 24.8607,
        longitude: 67.0011,
        address: 'Karachi, Pakistan',
      );
      expect(model.latitude, 24.8607);
      expect(model.longitude, 67.0011);
      expect(model.address, 'Karachi, Pakistan');
    });

    test('toJson serializes correctly', () {
      const model = DeliveryLocationModel(
        latitude: 24.8607,
        longitude: 67.0011,
        address: 'Karachi, Pakistan',
      );
      final json = model.toJson();
      expect(json['latitude'], 24.8607);
      expect(json['longitude'], 67.0011);
      expect(json['address'], 'Karachi, Pakistan');
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'latitude': 24.8607,
        'longitude': 67.0011,
        'address': 'Karachi, Pakistan',
      };
      final model = DeliveryLocationModel.fromJson(json);
      expect(model.latitude, 24.8607);
      expect(model.longitude, 67.0011);
      expect(model.address, 'Karachi, Pakistan');
    });

    test('googleMapsUrl returns correct navigation URL', () {
      const model = DeliveryLocationModel(
        latitude: 24.8607,
        longitude: 67.0011,
        address: 'Karachi, Pakistan',
      );
      expect(model.googleMapsUrl, 'google.navigation:q=24.8607,67.0011');
    });

    test('googleMapsWebUrl returns correct web fallback URL', () {
      const model = DeliveryLocationModel(
        latitude: 24.8607,
        longitude: 67.0011,
        address: 'Karachi, Pakistan',
      );
      expect(
        model.googleMapsWebUrl,
        'https://www.google.com/maps/dir/?api=1&destination=24.8607,67.0011',
      );
    });

    test('isValid returns true when lat/lng are non-zero', () {
      const model = DeliveryLocationModel(
        latitude: 24.8607,
        longitude: 67.0011,
        address: 'Karachi',
      );
      expect(model.isValid, isTrue);
    });

    test('isValid returns false for default 0,0 coordinates', () {
      const model = DeliveryLocationModel(
        latitude: 0,
        longitude: 0,
        address: '',
      );
      expect(model.isValid, isFalse);
    });

    test('copyWith updates address only', () {
      const model = DeliveryLocationModel(
        latitude: 24.8607,
        longitude: 67.0011,
        address: 'Old Address',
      );
      final updated = model.copyWith(address: 'New Address');
      expect(updated.address, 'New Address');
      expect(updated.latitude, 24.8607);
    });

    test('equality holds for same values', () {
      const a = DeliveryLocationModel(
        latitude: 1.0,
        longitude: 2.0,
        address: 'X',
      );
      const b = DeliveryLocationModel(
        latitude: 1.0,
        longitude: 2.0,
        address: 'X',
      );
      expect(a, equals(b));
    });
  });
}
