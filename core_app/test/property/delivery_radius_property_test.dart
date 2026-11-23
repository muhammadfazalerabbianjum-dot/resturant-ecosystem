import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

// Spec: Haversine distance in miles between known coordinate pairs.
// Values verified against geodesic calculators (WGS-84 ellipsoid).
// Tests call the production BranchService.distanceMiles and assert
// against hard-coded spec values — no local formula copy.

void main() {
  group('Haversine Distance — Spec Values (BranchService)', () {
    test('London (LHR) to Paris (CDG) is approximately 214 miles', () {
      // Spec: LHR (51.4700, -0.4543) to CDG (49.0097, 2.5479)
      // Expected: ~214 miles (344 km)
      const latLHR = 51.4700;
      const lonLHR = -0.4543;
      const latCDG = 49.0097;
      const lonCDG = 2.5479;

      final distance = BranchService.distanceMiles(
        latLHR,
        lonLHR,
        latCDG,
        lonCDG,
      );

      // Spec tolerance: ±5 miles for known city-pair distances
      expect(distance, closeTo(214.0, 5.0));
    });

    test('Same coordinates yield exactly 0.0 miles', () {
      final distance = BranchService.distanceMiles(
        25.2048,
        55.2708,
        25.2048,
        55.2708,
      );
      expect(distance, equals(0.0));
    });

    test('JFK to LAX is approximately 2475 miles', () {
      // Spec: JFK (40.6413, -73.7781) to LAX (33.9425, -118.4081)
      // Expected: ~2,475 miles (3,983 km)
      const latJFK = 40.6413;
      const lonJFK = -73.7781;
      const latLAX = 33.9425;
      const lonLAX = -118.4081;

      final distance = BranchService.distanceMiles(
        latJFK,
        lonJFK,
        latLAX,
        lonLAX,
      );

      // Spec tolerance: ±20 miles for cross-continental distances
      expect(distance, closeTo(2475.0, 20.0));
    });

    test('Dubai Marina to Downtown is approximately 12 miles', () {
      // Spec: Dubai Marina (25.0807, 55.1408) to Downtown Dubai (25.2048, 55.2708)
      const latMarina = 25.0807;
      const lonMarina = 55.1408;
      const latDowntown = 25.2048;
      const lonDowntown = 55.2708;

      final distance = BranchService.distanceMiles(
        latMarina,
        lonMarina,
        latDowntown,
        lonDowntown,
      );

      // Spec tolerance: ±2 miles for intra-city distances
      expect(distance, closeTo(12.0, 2.0));
    });

    test('All known distances are non-negative', () {
      // Spec: distance must never be negative for any valid coordinate pair
      final distance = BranchService.distanceMiles(0.0, 0.0, 0.0, 0.0);
      expect(distance, greaterThanOrEqualTo(0.0));
    });
  });
}
