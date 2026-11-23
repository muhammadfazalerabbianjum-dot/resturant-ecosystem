import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

/// CORE-COV Tier-2 MODELS suite: serialization round-trips and fail-soft
/// parsing for every remaining model — operating hours, promotions (Timestamp
/// normalization), delivery location (null-island guard), the shared
/// LatLngParse normalizer (B4-3), the GeoPoint converter, and the storage
/// shape contracts in user_schema.dart.
void main() {
  group('OperatingHoursModel', () {
    test('fromMap/toMap round-trip preserves every day + hours + flags', () {
      final source = <String, dynamic>{
        'monday': <String, dynamic>{
          'isOpen': true,
          'openTime': '08:00',
          'closeTime': '17:00',
        },
        'tuesday': <String, dynamic>{'isOpen': false},
        'holidayModeEnabled': true,
      };

      final model = OperatingHoursModel.fromMap(source);
      final roundTrip = OperatingHoursModel.fromMap(model.toMap());

      expect(roundTrip.monday.isOpen, isTrue);
      expect(roundTrip.monday.openTime, '08:00');
      expect(roundTrip.monday.closeTime, '17:00');
      expect(roundTrip.tuesday.isOpen, isFalse);
      expect(roundTrip.tuesday.openTime, '09:00', reason: 'DayHours DEFAULT');
      expect(roundTrip.holidayModeEnabled, isTrue);
    });

    test('a corrupt day value parses to a CLOSED day instead of crashing', () {
      final model = OperatingHoursModel.fromMap(<String, dynamic>{
        'monday': 'not-a-map',
      });

      expect(model.monday.isOpen, isTrue, reason: 'safe DEFAULT — no throw');
      expect(model.monday.openTime, '09:00');
    });

    test('entries expose the 7 labeled week days', () {
      expect(const OperatingHoursModel().entries, hasLength(7));
      expect(const OperatingHoursModel().entries[0], (
        'Monday',
        const DayHours(),
      ));
    });

    test('the weekend defaults differ from weekdays', () {
      const model = OperatingHoursModel();
      expect(model.saturday.openTime, '10:00');
      expect(model.sunday.closeTime, '21:00');
    });
  });

  group('PromotionModel', () {
    test('fromJson defaults isActive/priority; toJson round-trips', () {
      final model = PromotionModel.fromJson(<String, dynamic>{'id': 'p1'});

      expect(model.isActive, isTrue);
      expect(model.priority, 99);
      final back = PromotionModel.fromJson(model.toJson());
      expect(back.id, 'p1');
    });

    test('fromDoc normalizes a Firestore Timestamp createdAt', () async {
      final fake = FakeFirebaseFirestore();
      final ref = await fake.collection('promotions').add(<String, dynamic>{
        'title': 'Summer',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 4)),
      });
      final doc = await fake.collection('promotions').doc(ref.id).get();

      final model = PromotionModel.fromDoc(doc);

      expect(model.id, ref.id);
      expect(model.title, 'Summer');
      expect(model.createdAt, DateTime(2026, 3, 4));
    });
  });

  group('DeliveryLocationModel', () {
    test('(0,0) null-island coordinates are NOT a valid delivery location', () {
      expect(
        const DeliveryLocationModel(latitude: 0, longitude: 0).isValid,
        isFalse,
      );
      expect(
        const DeliveryLocationModel(latitude: 37.7, longitude: -122.4).isValid,
        isTrue,
      );
    });

    test('navigation URLs embed the exact coordinates', () {
      const loc = DeliveryLocationModel(latitude: 37.7, longitude: -122.4);
      expect(loc.googleMapsUrl, 'google.navigation:q=37.7,-122.4');
      expect(loc.googleMapsWebUrl, contains('destination=37.7,-122.4'));
    });
  });

  group('LatLngParse — every historical geo shape (B4-3)', () {
    test('geoflutterfire index shape geo.geopoint wins', () {
      final parsed = LatLngParse.fromMap(<String, dynamic>{
        'geo': <String, dynamic>{'geopoint': const GeoPoint(25.2, 55.2)},
      });
      expect((parsed.lat, parsed.lng), (25.2, 55.2));
    });

    test('coordinates as GeoPoint, [lng, lat] list, or map', () {
      expect(
        LatLngParse.fromMap(<String, dynamic>{
          'coordinates': const GeoPoint(1.5, 2.5),
        }),
        (lat: 1.5, lng: 2.5),
      );
      final listShape = LatLngParse.fromMap(<String, dynamic>{
        'coordinates': <num>[2.5, 1.5],
      });
      expect((listShape.lat, listShape.lng), (1.5, 2.5));
      final mapShape = LatLngParse.fromMap(<String, dynamic>{
        'coordinates': <String, dynamic>{'lat': 1.5, 'lng': 2.5},
      });
      expect((mapShape.lat, mapShape.lng), (1.5, 2.5));
    });

    test('top-level lat/lng (string or num) parse; a miss returns (0,0)', () {
      final parsed = LatLngParse.fromMap(<String, dynamic>{
        'lat': '3.5',
        'lng': 4.5,
      });
      expect((parsed.lat, parsed.lng), (3.5, 4.5));
      final miss = LatLngParse.fromMap(<String, dynamic>{'name': 'x'});
      expect((miss.lat, miss.lng), (0.0, 0.0));
    });
  });

  group('GeoPointConverter', () {
    test(
      'passes GeoPoints through, builds from maps, and fails over to 0,0',
      () {
        const converter = GeoPointConverter();
        const point = GeoPoint(10, 20);
        expect(identical(converter.fromJson(point), point), isTrue);
        expect(converter.toJson(point), same(point));
        expect(
          converter.fromJson(<String, dynamic>{'latitude': 3, 'longitude': 4}),
          const GeoPoint(3, 4),
        );
        expect(converter.fromJson('junk'), const GeoPoint(0, 0));
      },
    );
  });

  group('user_schema.dart — storage shape contracts', () {
    test(
      'every declared collection lists the fields the code actually reads',
      () {
        expect(userRequiredFields, <String>['email', 'role', 'createdAt']);
        expect(
          orderRequiredFields,
          containsAll(<String>['customerId', 'items', 'totalCents']),
        );
        expect(loyaltyRequiredFields, <String>['points']);
        // BranchInfo.fromDoc reads name/address/coordinates (LatLngParse).
        expect(branchRequiredFields, <String>[
          'name',
          'address',
          'coordinates',
        ]);
      },
    );
  });
}
