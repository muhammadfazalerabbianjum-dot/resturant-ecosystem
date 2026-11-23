import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/locations/data/location_repository.dart';

void main() {
  group('LocationRepository', () {
    late FakeFirebaseFirestore firestore;
    late LocationRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = LocationRepository(
        firestore,
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );
    });

    test('getLocations returns empty list when no locations exist', () async {
      final locations = await repository.getLocations();
      expect(locations, isEmpty);
    });

    test('getLocations returns all locations', () async {
      final col = firestore.collection('locations');
      await col.add({
        'name': 'Branch A',
        'lat': 40.7128,
        'lng': -74.0060,
        'address': '123 Main St',
        'openHours': '9am - 10pm',
      });
      await col.add({
        'name': 'Branch B',
        'lat': 34.0522,
        'lng': -118.2437,
        'address': '456 Oak Ave',
        'openHours': '8am - 11pm',
      });

      final locations = await repository.getLocations();
      expect(locations.length, 2);
      expect(locations[0].name, 'Branch A');
      expect(locations[1].name, 'Branch B');
    });

    test('getLocations limits to 50 results', () async {
      final col = firestore.collection('locations');
      for (int i = 0; i < 60; i++) {
        await col.add({
          'name': 'Branch $i',
          'lat': 0.0,
          'lng': 0.0,
          'address': '',
          'openHours': '',
        });
      }

      final locations = await repository.getLocations();
      expect(locations.length, 50);
    });

    test(
      'getLocations handles missing fields with honest fallbacks (B4-4)',
      () async {
        final col = firestore.collection('locations');
        await col.add({'name': 'Minimal Branch'});

        final locations = await repository.getLocations();
        expect(locations.length, 1);
        expect(locations[0].name, 'Minimal Branch');
        expect(locations[0].lat, 0.0);
        expect(locations[0].lng, 0.0);
        expect(locations[0].address, '');
        // B4-4: never a fabricated '9am - 10pm' — missing openHours is "—".
        expect(locations[0].openHours, '—');
      },
    );

    test(
      'getLocations parses geoflutterfire geo.geopoint shape (B4-3)',
      () async {
        final col = firestore.collection('locations');
        await col.add({
          'name': 'Geo Branch',
          'geo': {'geopoint': const GeoPoint(51.5074, -0.1278)},
          'address': 'London',
          'openHours': '24/7',
        });

        final locations = await repository.getLocations();
        expect(locations[0].lat, 51.5074);
        expect(locations[0].lng, -0.1278);
      },
    );

    test('getLocations parses coordinates GeoPoint shape (B4-3)', () async {
      final col = firestore.collection('locations');
      await col.add({
        'name': 'Coord Branch',
        'coordinates': const GeoPoint(40.7128, -74.0060),
        'openHours': '9am - 10pm',
      });

      final locations = await repository.getLocations();
      expect(locations[0].lat, 40.7128);
      expect(locations[0].lng, -74.0060);
    });

    test(
      'getLocations parses coordinates [lng, lat] array shape (B4-3)',
      () async {
        final col = firestore.collection('locations');
        await col.add({
          'name': 'Array Branch',
          'coordinates': [-74.0060, 40.7128],
          'openHours': '9am - 10pm',
        });

        final locations = await repository.getLocations();
        expect(locations[0].lat, 40.7128);
        expect(locations[0].lng, -74.0060);
      },
    );

    test(
      'getLocations parses coordinates {latitude, longitude} object (B4-3)',
      () async {
        final col = firestore.collection('locations');
        await col.add({
          'name': 'Obj Branch',
          'coordinates': {'latitude': 40.7128, 'longitude': -74.0060},
          'openHours': '9am - 10pm',
        });

        final locations = await repository.getLocations();
        expect(locations[0].lat, 40.7128);
        expect(locations[0].lng, -74.0060);
      },
    );

    test('getLocations parses coordinates correctly', () async {
      final col = firestore.collection('locations');
      await col.add({
        'name': 'Branch',
        'lat': 51.5074,
        'lng': -0.1278,
        'address': 'London',
        'openHours': '24/7',
      });

      final locations = await repository.getLocations();
      expect(locations[0].lat, 51.5074);
      expect(locations[0].lng, -0.1278);
      expect(locations[0].address, 'London');
      expect(locations[0].openHours, '24/7');
    });

    test('getLocations handles null lat/lng values', () async {
      final col = firestore.collection('locations');
      await col.add({
        'name': 'Branch',
        'lat': null,
        'lng': null,
        'address': '',
        'openHours': '',
      });

      final locations = await repository.getLocations();
      expect(locations[0].lat, 0.0);
      expect(locations[0].lng, 0.0);
    });

    test('getLocations handles integer coordinate values', () async {
      final col = firestore.collection('locations');
      await col.add({
        'name': 'Branch',
        'lat': 40,
        'lng': -74,
        'address': '',
        'openHours': '',
      });

      final locations = await repository.getLocations();
      expect(locations[0].lat, 40.0);
      expect(locations[0].lng, -74.0);
    });

    // ------------------------------------------------------------------
    // PERF-10 T-8 (§4.4): the location coverage run left exactly three
    // uncovered lines in location_repository.dart — the provider body
    // (16-18, the DI wiring) and the fail-loud catch (54). These three
    // tests close them; the file's own suite lands on 100% of the
    // repository (see tool_archive/perf2_cited/tool_perf2/t78_report.md §5).
    // ------------------------------------------------------------------

    test(
      'a read failure is logged and rethrown (never a silent empty list)',
      () async {
        final logger = _RecordingLogger();
        final broken = LocationRepository(_BrokenLocationsDb(), logger);

        await expectLater(broken.getLocations(), throwsA(isA<StateError>()));
        expect(logger.errors, contains('getLocations failed'));
      },
    );

    test('missing display fields are traced, not just defaulted', () async {
      final fs = FakeFirebaseFirestore();
      final logger = _RecordingLogger();
      await fs.collection('locations').add({'lat': 1.0, 'lng': 2.0});

      final locations = await LocationRepository(fs, logger).getLocations();

      expect(locations.single.name, '—');
      expect(locations.single.openHours, '—');
      expect(
        logger.warns,
        everyElement('LocationRepository.getLocations missing field'),
      );
      expect(logger.warns, hasLength(2), reason: 'one trace per missing field');
    });

    test(
      'locationRepositoryProvider wires firestore + logger from the graph',
      () {
        final fs = FakeFirebaseFirestore();
        final logger = _RecordingLogger();
        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(fs),
            loggerProvider.overrideWithValue(logger),
          ],
        );
        addTearDown(container.dispose);

        final repo = container.read(locationRepositoryProvider);

        expect(repo, isA<LocationRepository>());
        // The wired instance reads the graph's fake DB, not FirebaseFirestore.instance.
        expect(repo.getLocations(), completes);
      },
    );
  });
}

/// A DB whose `locations` reads always fail — drives the REAL catch/rethrow
/// path without a Firebase app (the Firestore classes are sealed, so the fake
/// is extended per the established in-repo pattern).
class _BrokenLocationsDb extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'locations') {
      throw StateError('permission-denied');
    }
    return super.collection(collectionPath);
  }
}

/// Records warn/error calls without file I/O or Crashlytics.
class _RecordingLogger extends LoggerService {
  _RecordingLogger()
    : super(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      );

  final List<String> warns = <String>[];
  final List<String> errors = <String>[];

  @override
  Future<void> warn(Object error, String message, {StackTrace? stack}) async {
    warns.add(message);
  }

  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {
    errors.add(message);
  }
}
