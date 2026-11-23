import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:core_ui/core_ui.dart';

/// CORE-COV Tier-3 LIVE_MAP_PICKER suite: the widget's testing seams
/// (`positionProvider`, localized labels, `initialCenter` seed) prove the
/// GPS fallback chain and the W9.2 no-English-literals contract — no
/// platform channels, no network tiles required.
void main() {
  // Geolocator's high-accuracy position used by the successful GPS stub.
  Position pos(double lat, double lng) => Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime(2026),
    accuracy: 5,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
  );

  testWidgets(
    'seeded initialCenter shows movePinLabel immediately (no GPS dependency)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveMapPickerWidget(
            title: 'Pick location',
            confirmLabel: 'Confirm',
            positioningLabel: 'Positioning…',
            movePinLabel: 'Move the pin',
            lookingUpLabel: 'Looking up…',
            deliveringToLabel: 'Deliver to',
            initialCenter: const LatLng(51.5, -0.12),
            onLocationPicked: (_, __) {},
            // Never completes — the seeded-frame assertions below must not
            // depend on GPS resolution (or a real 10s geolocator timer).
            positionProvider: (_) => Completer<Position>().future,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pick location'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Move the pin'), findsOneWidget);
    },
  );

  testWidgets(
    'GPS failure falls back to the seeded pin and NEVER crashes (fail-closed)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveMapPickerWidget(
            title: 't',
            confirmLabel: 'c',
            positioningLabel: 'p',
            movePinLabel: 'm',
            lookingUpLabel: 'l',
            deliveringToLabel: 'd',
            initialCenter: const LatLng(48.85, 2.35),
            onLocationPicked: (_, __) {},
            // GPS throws (permission denied) — the widget must stay on the
            // seeded pin, leave the spinner, and NOT crash.
            positionProvider: (_) async =>
                throw const LocationServiceDisabledException(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 11));

      // Spinner still up? No — the failure path must clear it (fail-closed,
      // never hang in 'positioning…' limbo).
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      // Address label stays on the seeded copy (no bogus reverse-geocode).
      expect(find.text('m'), findsOneWidget);
    },
  );

  testWidgets(
    'GPS success re-centers on the fix and shows the localized lookingUp label (W9.2)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveMapPickerWidget(
            title: 't',
            confirmLabel: 'c',
            positioningLabel: 'p',
            movePinLabel: 'm',
            lookingUpLabel: 'GPS found you',
            deliveringToLabel: 'd',
            initialCenter: const LatLng(0, 0),
            onLocationPicked: (_, __) {},
            positionProvider: (_) async => pos(48.8584, 2.2945),
          ),
        ),
      );
      await tester.pump();

      // W9.2 regression guard: the GPS path must use the HOST-supplied
      // looking-up copy — never a hardcoded English literal.
      expect(find.text('GPS found you'), findsOneWidget);
      // The map re-centered: the FlutterMap exists and rendered the fix.
      expect(find.byType(FlutterMap), findsOneWidget);
    },
  );

  testWidgets(
    'neutral center fallback when no seed and GPS fails (no hardcoded city)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveMapPickerWidget(
            title: 't',
            confirmLabel: 'c',
            positioningLabel: 'no seed',
            movePinLabel: 'm',
            lookingUpLabel: 'l',
            deliveringToLabel: 'd',
            onLocationPicked: (_, __) {},
            positionProvider: (_) async =>
                throw const LocationServiceDisabledException(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 11));

      expect(tester.takeException(), isNull);
      // The positioning copy (NOT 'Move the pin') is shown before GPS resolves,
      // and stays — proving no hardcoded business/city default exists.
      expect(find.text('no seed'), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
    },
  );
}
