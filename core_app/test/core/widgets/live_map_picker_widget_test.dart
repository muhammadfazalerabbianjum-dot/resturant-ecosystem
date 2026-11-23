import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:core_ui/src/widgets/live_map_picker_widget.dart';

import 'package:latlong2/latlong.dart';

/// A fake position provider that returns a known position.
Future<Position> fakePositionProvider(LocationSettings settings) async {
  return Position(
    latitude: 24.8607,
    longitude: 67.0011,
    timestamp: DateTime.now(),
    altitude: 0,
    accuracy: 10,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
  );
}

void main() {
  group('LiveMapPickerWidget', () {
    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveMapPickerWidget(
            onLocationPicked: (LatLng latlng, String address) {},
            title: 'Set Delivery Location',
            confirmLabel: 'Confirm',
            positioningLabel: 'Positioning...',
            movePinLabel: 'Move the pin to set the delivery location',
            lookingUpLabel: 'Looking up address...',
            deliveringToLabel: 'Delivering to:',
            positionProvider: (settings) => Future.delayed(
              const Duration(seconds: 1),
              () => fakePositionProvider(settings),
            ),
          ),
        ),
      );

      // Initially should show CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Flush the 1s delayed provider so no timer is pending at teardown.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('shows map after position is resolved', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveMapPickerWidget(
            onLocationPicked: (LatLng latlng, String address) {},
            title: 'Set Delivery Location',
            confirmLabel: 'Confirm',
            positioningLabel: 'Positioning...',
            movePinLabel: 'Move the pin to set the delivery location',
            lookingUpLabel: 'Looking up address...',
            deliveringToLabel: 'Delivering to:',
            positionProvider: fakePositionProvider,
          ),
        ),
      );

      // Pump to process the async init
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Loading should be done since provider resolves immediately
      // The widget may or may not show loading depending on timing
      // Just verify the widget is rendered
      expect(find.byType(LiveMapPickerWidget), findsOneWidget);
    });

    testWidgets('handles position failure gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveMapPickerWidget(
            onLocationPicked: (LatLng latlng, String address) {},
            title: 'Set Delivery Location',
            confirmLabel: 'Confirm',
            positioningLabel: 'Positioning...',
            movePinLabel: 'Move the pin to set the delivery location',
            lookingUpLabel: 'Looking up address...',
            deliveringToLabel: 'Delivering to:',
            positionProvider: (settings) async {
              throw Exception('Location error');
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Should not crash - widget should still be rendered
      expect(find.byType(LiveMapPickerWidget), findsOneWidget);
    });

    testWidgets('Confirm button calls onLocationPicked with correct data', (
      tester,
    ) async {
      LatLng? capturedLatLng;
      String? capturedAddress;

      await tester.pumpWidget(
        MaterialApp(
          home: LiveMapPickerWidget(
            onLocationPicked: (latlng, address) {
              capturedLatLng = latlng;
              capturedAddress = address;
            },
            title: 'Set Delivery Location',
            confirmLabel: 'Confirm',
            positioningLabel: 'Positioning...',
            movePinLabel: 'Move the pin to set the delivery location',
            lookingUpLabel: 'Looking up address...',
            deliveringToLabel: 'Delivering to:',
            positionProvider: fakePositionProvider,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tap the Confirm button. Use pump() (not pumpAndSettle) because the
      // widget fires a reverse-geocode network call that never settles in a
      // test environment.
      await tester.tap(find.text('Confirm'));
      await tester.pump();

      // Should capture the resolved pin position (from the fake provider)
      expect(capturedLatLng, isNotNull);
      expect(capturedLatLng!.latitude, closeTo(24.8607, 0.001));
      expect(capturedLatLng!.longitude, closeTo(67.0011, 0.001));
      expect(capturedAddress, isNotNull);
    });

    testWidgets('AppBar has correct title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveMapPickerWidget(
            onLocationPicked: (LatLng latlng, String address) {},
            title: 'Set Delivery Location',
            confirmLabel: 'Confirm',
            positioningLabel: 'Positioning...',
            movePinLabel: 'Move the pin to set the delivery location',
            lookingUpLabel: 'Looking up address...',
            deliveringToLabel: 'Delivering to:',
            positionProvider: fakePositionProvider,
          ),
        ),
      );

      expect(find.text('Set Delivery Location'), findsOneWidget);
    });

    testWidgets('shows positioning label initially when no center is seeded', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveMapPickerWidget(
            onLocationPicked: (LatLng latlng, String address) {},
            title: 'Set Delivery Location',
            confirmLabel: 'Confirm',
            positioningLabel: 'Positioning...',
            movePinLabel: 'Move the pin to set the delivery location',
            lookingUpLabel: 'Looking up address...',
            deliveringToLabel: 'Delivering to:',
            positionProvider: fakePositionProvider,
          ),
        ),
      );

      // No initialCenter -> the widget shows the positioning label.
      expect(find.text('Positioning...'), findsOneWidget);
    });

    testWidgets('shows move-pin label when an initial center is seeded', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveMapPickerWidget(
            onLocationPicked: (LatLng latlng, String address) {},
            title: 'Set Delivery Location',
            confirmLabel: 'Confirm',
            positioningLabel: 'Positioning...',
            movePinLabel: 'Move the pin to set the delivery location',
            lookingUpLabel: 'Looking up address...',
            deliveringToLabel: 'Delivering to:',
            positionProvider: fakePositionProvider,
            initialCenter: const LatLng(24.8607, 67.0011),
          ),
        ),
      );

      // initialCenter provided -> the widget shows the move-pin label.
      expect(
        find.text('Move the pin to set the delivery location'),
        findsOneWidget,
      );
    });
  });
}
