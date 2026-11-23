import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/locations/domain/location_model.dart';

void main() {
  group('LocationModel', () {
    test('constructor assigns all fields correctly', () {
      const model = LocationModel(
        id: 'loc1',
        name: 'Downtown Branch',
        lat: 40.7128,
        lng: -74.0060,
        address: '123 Main St',
        openHours: '9am - 10pm',
      );
      expect(model.id, 'loc1');
      expect(model.name, 'Downtown Branch');
      expect(model.lat, 40.7128);
      expect(model.lng, -74.0060);
      expect(model.address, '123 Main St');
      expect(model.openHours, '9am - 10pm');
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 'loc1',
        'name': 'Downtown Branch',
        'lat': 40.7128,
        'lng': -74.0060,
        'address': '123 Main St',
        'openHours': '9am - 10pm',
      };
      final model = LocationModel.fromJson(json);
      expect(model.id, 'loc1');
      expect(model.name, 'Downtown Branch');
      expect(model.lat, 40.7128);
      expect(model.lng, -74.0060);
      expect(model.address, '123 Main St');
      expect(model.openHours, '9am - 10pm');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'loc1',
        'name': 'Branch',
        'lat': 0.0,
        'lng': 0.0,
        'address': '',
        'openHours': '',
      };
      final model = LocationModel.fromJson(json);
      expect(model.id, 'loc1');
      expect(model.name, 'Branch');
    });

    test('equality works correctly', () {
      const a = LocationModel(
        id: 'loc1',
        name: 'Branch',
        lat: 0.0,
        lng: 0.0,
        address: '',
        openHours: '',
      );
      const b = LocationModel(
        id: 'loc1',
        name: 'Branch',
        lat: 0.0,
        lng: 0.0,
        address: '',
        openHours: '',
      );
      expect(a, equals(b));
    });

    test('inequality detects different id', () {
      const a = LocationModel(
        id: 'loc1',
        name: 'Branch',
        lat: 0.0,
        lng: 0.0,
        address: '',
        openHours: '',
      );
      const b = LocationModel(
        id: 'loc2',
        name: 'Branch',
        lat: 0.0,
        lng: 0.0,
        address: '',
        openHours: '',
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality detects different name', () {
      const a = LocationModel(
        id: 'loc1',
        name: 'Branch A',
        lat: 0.0,
        lng: 0.0,
        address: '',
        openHours: '',
      );
      const b = LocationModel(
        id: 'loc1',
        name: 'Branch B',
        lat: 0.0,
        lng: 0.0,
        address: '',
        openHours: '',
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality detects different coordinates', () {
      const a = LocationModel(
        id: 'loc1',
        name: 'Branch',
        lat: 40.0,
        lng: -74.0,
        address: '',
        openHours: '',
      );
      const b = LocationModel(
        id: 'loc1',
        name: 'Branch',
        lat: 41.0,
        lng: -75.0,
        address: '',
        openHours: '',
      );
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent with equality', () {
      const a = LocationModel(
        id: 'loc1',
        name: 'Branch',
        lat: 0.0,
        lng: 0.0,
        address: '',
        openHours: '',
      );
      const b = LocationModel(
        id: 'loc1',
        name: 'Branch',
        lat: 0.0,
        lng: 0.0,
        address: '',
        openHours: '',
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString contains class name', () {
      const model = LocationModel(
        id: 'loc1',
        name: 'Branch',
        lat: 0.0,
        lng: 0.0,
        address: '',
        openHours: '',
      );
      expect(model.toString(), contains('LocationModel'));
    });
  });

  group('LocationModel.fromDoc — single normalized schema (B4-3)', () {
    test('parses geoflutterfire geo.geopoint shape', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('locations').doc('l1').set({
        'name': 'Geo',
        'geo': {'geopoint': const GeoPoint(51.5, -0.1)},
        'openHours': '24/7',
      });
      final doc = await firestore.collection('locations').doc('l1').get();
      final model = LocationModel.fromDoc(doc);
      expect(model.lat, 51.5);
      expect(model.lng, -0.1);
    });

    test('parse coordinates GeoPoint shape', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('locations').doc('l1').set({
        'name': 'Coord',
        'coordinates': const GeoPoint(40.71, -74.00),
        'openHours': '9am - 10pm',
      });
      final doc = await firestore.collection('locations').doc('l1').get();
      final model = LocationModel.fromDoc(doc);
      expect(model.lat, 40.71);
      expect(model.lng, -74.00);
    });

    test('parse coordinates [lng, lat] array', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('locations').doc('l1').set({
        'name': 'Arr',
        'coordinates': [-74.00, 40.71],
        'openHours': '9am - 10pm',
      });
      final doc = await firestore.collection('locations').doc('l1').get();
      final model = LocationModel.fromDoc(doc);
      expect(model.lat, 40.71);
      expect(model.lng, -74.00);
    });

    test('parse top-level lat/lng', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('locations').doc('l1').set({
        'name': 'Flat',
        'lat': 34.05,
        'lng': -118.24,
        'openHours': '9am - 10pm',
      });
      final doc = await firestore.collection('locations').doc('l1').get();
      final model = LocationModel.fromDoc(doc);
      expect(model.lat, 34.05);
      expect(model.lng, -118.24);
    });

    test(
      'honest em-dash fallbacks for missing name/openHours (B4-4)',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('locations').doc('l1').set({
          'lat': 1.0,
          'lng': 2.0,
        });
        final doc = await firestore.collection('locations').doc('l1').get();
        final model = LocationModel.fromDoc(doc);
        expect(model.name, '—');
        expect(model.openHours, '—');
        expect(model.address, '');
      },
    );
  });
}
