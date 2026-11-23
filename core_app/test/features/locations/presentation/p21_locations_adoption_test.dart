// UI-13 (p21) phase E adoption receipts — M-4 locations + maps (contract §3-E).
//
// Every expectation below is RED against the pre-adoption screens and GREEN
// after the library composition lands:
//  E1 `location_screen.dart`  -> SectionHeader / SettingTile / SkeletonLoader /
//                                EmptyStateWidget (no raw ListTile, no raw
//                                CircularProgressIndicator).
//  E2 `pin_drop_map_screen.dart` -> InfoBanner hint + BrandButton CTA around the
//                                UNCHANGED pin-drop map (L31: behaviour, the
//                                geolocation error handling and the
//                                `tileProvider` seam stay exactly as-is).
import 'dart:async';
import 'dart:io';

import 'package:core/core.dart'
    show DeliveryLocationModel, LoggerService, loggerProvider;
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/features/location/presentation/pin_drop_map_screen.dart';
import 'package:labs/features/locations/data/location_repository.dart';
import 'package:labs/features/locations/domain/location_model.dart';
import 'package:labs/features/locations/presentation/location_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

import '../../location/presentation/hermetic_tile_provider.dart';

const List<LocationModel> _branches = [
  LocationModel(
    id: 'loc-a',
    name: 'Branch A',
    lat: 1,
    lng: 2,
    address: '1 A St',
    openHours: '9am - 5pm',
  ),
  LocationModel(
    id: 'loc-b',
    name: 'Branch B',
    lat: 3,
    lng: 4,
    address: '2 B St',
    openHours: '10am - 6pm',
  ),
];

/// Pumps [LocationScreen] with a controlled `locationsProvider` stream.
///
/// [locations] `null` keeps the provider pending (the loading state).
Future<void> _pumpLocationScreen(
  WidgetTester tester, {
  List<LocationModel>? locations,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationsProvider.overrideWith(
          (ref) => locations == null
              ? Completer<List<LocationModel>>().future
              : Future.value(locations),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LocationScreen(),
      ),
    ),
  );
  await tester.pump();
}

/// Deterministic logger: the screen AWAITS `logger.error(..)` before showing the
/// SnackBar, and the production logger performs real file I/O that never
/// completes under the fake-async test clock.
class _ImmediateLoggerService extends LoggerService {
  _ImmediateLoggerService()
    : super(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      );

  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {}

  @override
  Future<void> warn(Object error, String message, {StackTrace? stack}) async {}

  @override
  Future<void> info(Map<String, dynamic> context, String message) async {}
}

/// Controllable [GeolocatorPlatform] — the plugin's own documented test seam
/// (`Geolocator.getCurrentPosition` delegates verbatim to
/// `GeolocatorPlatform.instance`), so no platform channel is ever opened.
class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  _FakeGeolocatorPlatform({this.throwOnFix = false});

  final bool throwOnFix;
  int currentPositionCalls = 0;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    currentPositionCalls++;
    if (throwOnFix) {
      throw const PermissionDeniedException('location permission denied');
    }
    return Position(
      latitude: 24.8607,
      longitude: 67.0011,
      timestamp: DateTime(2026, 7, 24, 12),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

/// Host route that renders the popped [DeliveryLocationModel] back on stage, so
/// the Confirm contract can be asserted end-to-end through the NEW CTA.
class _ResultHostScreen extends StatefulWidget {
  const _ResultHostScreen();

  @override
  State<_ResultHostScreen> createState() => _ResultHostScreenState();
}

class _ResultHostScreenState extends State<_ResultHostScreen> {
  DeliveryLocationModel? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _result == null
                  ? 'no result'
                  : 'picked: ${_result!.latitude.toStringAsFixed(3)},'
                        '${_result!.longitude.toStringAsFixed(3)}',
            ),
            ElevatedButton(
              onPressed: () async {
                final result = await context.push<DeliveryLocationModel>(
                  '/map',
                );
                if (mounted) setState(() => _result = result);
              },
              child: const Text('open map'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pumps the host route and opens the real map screen (injected hermetic tiles).
Future<void> _pumpMap(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'resultHost',
        builder: (_, __) => const _ResultHostScreen(),
      ),
      GoRoute(
        path: '/map',
        name: 'pinDropMap',
        builder: (_, __) =>
            PinDropMapScreen(tileProvider: NoNetworkTileProvider()),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationsProvider.overrideWith((ref) async => _branches),
        loggerProvider.overrideWithValue(_ImmediateLoggerService()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );

  await tester.tap(find.text('open map'));
  await tester.pumpAndSettle();
}

void main() {
  group('P21 E1 — LocationScreen library composition', () {
    testWidgets('the branch rows render through the library SettingTile', (
      tester,
    ) async {
      await _pumpLocationScreen(tester, locations: _branches);
      await tester.pumpAndSettle();

      expect(find.byType(SettingTile), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('the picker carries a library SectionHeader (existing copy)', (
      tester,
    ) async {
      await _pumpLocationScreen(tester, locations: _branches);
      await tester.pumpAndSettle();

      expect(find.byType(SectionHeader), findsOneWidget);
      // The copy is the pre-existing `selectBranchTitle` ARB key — no new
      // literal and no new key (p18 owns `l10n/**`).
      expect(find.text('Select a Branch'), findsOneWidget);
    });

    testWidgets('the header copy follows the locale (ar, existing key)', (
      tester,
    ) async {
      await _pumpLocationScreen(
        tester,
        locations: _branches,
        locale: const Locale('ar'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SectionHeader), findsOneWidget);
      expect(find.text('اختر فرعاً'), findsOneWidget);
    });

    testWidgets('a branch row still shows name, address and open hours', (
      tester,
    ) async {
      await _pumpLocationScreen(tester, locations: _branches);
      await tester.pumpAndSettle();

      // L31 preservation: the branch row keeps every datum it had before the
      // adoption (name + address + hours), now inside the frozen component.
      expect(find.text('Branch A'), findsOneWidget);
      expect(find.textContaining('1 A St'), findsOneWidget);
      expect(find.textContaining('9am - 5pm'), findsOneWidget);
    });

    testWidgets('the loading state renders library skeletons, no raw spinner', (
      tester,
    ) async {
      await _pumpLocationScreen(tester);
      await tester.pump();

      expect(find.byType(SkeletonLoader), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('the empty state keeps the library EmptyStateWidget + CTA', (
      tester,
    ) async {
      await _pumpLocationScreen(tester, locations: const <LocationModel>[]);
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateWidget), findsOneWidget);
      expect(find.text('No locations found'), findsOneWidget);
    });
  });

  group('P21 E2 — PinDropMapScreen brand chrome (map preserved)', () {
    testWidgets('the hint renders through the library InfoBanner', (
      tester,
    ) async {
      await _pumpMap(tester);

      expect(find.byType(InfoBanner), findsOneWidget);
      expect(find.text('Tap on the map to select location'), findsOneWidget);
    });

    testWidgets('the CTA renders through the library BrandButton', (
      tester,
    ) async {
      await _pumpMap(tester);

      expect(find.byType(BrandButton), findsOneWidget);
      expect(find.text('Use my location'), findsOneWidget);
    });

    testWidgets(
      'the BrandButton drives the identical geolocation → pin → Confirm → pop',
      (tester) async {
        final fake = _FakeGeolocatorPlatform();
        GeolocatorPlatform.instance = fake;

        await _pumpMap(tester);
        expect(find.byIcon(Icons.location_pin), findsNothing);

        await tester.tap(find.text('Use my location'));
        await tester.pumpAndSettle();

        // Same contract as pre-adoption (L31): one fix call, pin dropped, CTA
        // flips to Confirm and pops the picked coordinates back to the host.
        expect(fake.currentPositionCalls, 1);
        expect(find.byIcon(Icons.location_pin), findsOneWidget);
        expect(find.text('Confirm'), findsOneWidget);

        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();

        expect(find.textContaining('picked: 24.861'), findsOneWidget);
        expect(find.textContaining('67.001'), findsOneWidget);
      },
    );

    testWidgets('a denied fix still surfaces the existing localized message', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(throwOnFix: true);

      await _pumpMap(tester);
      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      // L31: the error path is untouched — same logger call, same SnackBar copy,
      // same "stay on Use my location" state, and never a thrown exception.
      expect(
        find.text('Could not get your location. Tap the map instead.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.location_pin), findsNothing);
      expect(find.text('Use my location'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the pin-drop map surface is preserved (L31)', (tester) async {
      await _pumpMap(tester);

      expect(find.byType(FlutterMap), findsOneWidget);
      // No second map widget was introduced: this screen keeps its own map
      // surface, its own geolocation error path and its own `tileProvider` test
      // seam; the library picker stays the separate checkout host.
      expect(find.byType(PinDropMapScreen), findsOneWidget);
    });
  });
}
