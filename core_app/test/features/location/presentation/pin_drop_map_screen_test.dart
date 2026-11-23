import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart'
    show DeliveryLocationModel, LoggerService, loggerProvider;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/features/location/presentation/pin_drop_map_screen.dart';
import 'package:labs/features/locations/data/location_repository.dart';
import 'package:labs/features/locations/domain/location_model.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart';

/// 1x1 transparent PNG — lets the map render without real network tiles.
final Uint8List _kTransparentImage = Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

/// Hermetic [TileProvider]: returns a valid in-memory image, no network I/O.
class _NoNetworkTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_kTransparentImage);
}

/// PERF-10 T-8 straggler sweep — a controllable [GeolocatorPlatform].
///
/// `PinDropMapScreen._pickCurrentLocation` calls the static
/// `Geolocator.getCurrentPosition()`, which (geolocator 13.0.4,
/// lib/geolocator.dart:147-148) delegates verbatim to
/// `GeolocatorPlatform.instance`. Swapping that instance is the plugin's own
/// documented test seam, so the screen's production code stays untouched and
/// no platform channel is ever opened.
class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  _FakeGeolocatorPlatform({this.throwOnFix = false});

  /// When true, the fix fails the way a denied permission does.
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

/// Deterministic logger for the failure-path test.
///
/// `_pickCurrentLocation` (pin_drop_map_screen.dart:50-57) AWAITS
/// `logger.error(..)` BEFORE showing the SnackBar, and the production logger
/// performs real file I/O (+ Crashlytics) that is not clock-bound under the
/// fake-async test clock — the write would never complete and the SnackBar
/// would never be reached. Same stub as
/// `test/features/home/presentation/home_screen_test.dart`; the screen's own
/// catch → SnackBar handling under test is untouched.
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

/// Host screen that pushes /map and renders the popped [DeliveryLocationModel]
/// back on stage so the Confirm contract can be asserted end-to-end.
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

/// PinDropMapScreen — real behavior tests (B4-12 replacement).
///
/// The interactive FlutterMap tile canvas is not hermetic under `flutter test`
/// (the tile layer performs real network I/O), so the full map interaction
/// (tap -> pin -> Confirm -> pop with [DeliveryLocationModel]) is covered by
/// the pure logic that drives it, plus the widget's already-verified pop
/// contract. The initial-center resolution was extracted as the pure
/// [PinDropMapScreen.initialCenterFor] so it can be asserted without a live
/// map renderer.

void main() {
  group('PinDropMapScreen.initialCenterFor', () {
    const downtown = LocationModel(
      id: 'l1',
      name: 'Downtown',
      lat: 24.8607,
      lng: 67.0011,
      address: '1 Main St',
      openHours: '9am - 10pm',
    );

    test('uses the first Firestore location when coordinates are non-zero', () {
      final center = PinDropMapScreen.initialCenterFor(const [downtown]);
      expect(center, isA<LatLng>());
      expect(center.latitude, closeTo(24.8607, 0.0001));
      expect(center.longitude, closeTo(67.0011, 0.0001));
    });

    test('falls back to the neutral center (0,0) when no locations exist', () {
      final center = PinDropMapScreen.initialCenterFor(const []);
      expect(center.latitude, 0);
      expect(center.longitude, 0);
    });

    test('falls back to the neutral center when the first doc is (0,0)', () {
      const nullIsland = LocationModel(
        id: 'l0',
        name: 'Null Island',
        lat: 0,
        lng: 0,
        address: '',
        openHours: '—',
      );
      final center = PinDropMapScreen.initialCenterFor(const [nullIsland]);
      expect(center.latitude, 0);
      expect(center.longitude, 0);
    });

    test('ignores a trailing non-zero location when the FIRST is (0,0)', () {
      const first = LocationModel(
        id: 'l0',
        name: 'Offline Branch',
        lat: 0,
        lng: 0,
        address: '',
        openHours: '—',
      );
      final center = PinDropMapScreen.initialCenterFor(const [first, downtown]);
      expect(center.latitude, 0);
      expect(center.longitude, 0);
    });
  });

  group('PinDropMapScreen — pin-drop flow (hermetic map)', () {
    const downtown = LocationModel(
      id: 'l1',
      name: 'Downtown',
      lat: 24.8607,
      lng: 67.0011,
      address: '1 Main St',
      openHours: '9am - 10pm',
    );

    /// Pumps the host route + the real map screen (injected tile provider)
    /// and lands on the map. [locations] seeds the `locations` collection
    /// (defaults to the `downtown` row; pass `const []` for the empty case).
    Future<void> pumpMap(
      WidgetTester tester, {
      List<LocationModel>? locations,
    }) async {
      final rows = locations ?? const [downtown];
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
                PinDropMapScreen(tileProvider: _NoNetworkTileProvider()),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            locationsProvider.overrideWith((ref) async => rows),
            // PERF-10 T-8: the screen reports location failures through the
            // injected logger; pin it to a temp directory so the failure path
            // never touches the real app log location.
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

    testWidgets('map tap drops the pin and arms the Confirm button', (
      tester,
    ) async {
      await pumpMap(tester);

      expect(find.text('Tap on the map to select location'), findsOneWidget);
      expect(find.text('Use my location'), findsOneWidget);
      expect(find.byIcon(Icons.location_pin), findsNothing);

      // The real MapOptions.onTap handler converts the tap to a LatLng.
      // PositionedTapDetector2 holds single taps for the double-tap window
      // (~300 ms) before invoking onTap — elapse past it.
      await tester.tap(find.byType(FlutterMap));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.location_pin), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Use my location'), findsNothing);
    });

    testWidgets('Confirm pops with DeliveryLocationModel for the tapped point', (
      tester,
    ) async {
      await pumpMap(tester);

      await tester.tap(find.byType(FlutterMap));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // The popped DeliveryLocationModel carries the tapped coordinate —
      // the map's camera center == the seeded initialCenter (24.8607, 67.0011).
      expect(find.textContaining('picked: 24.861'), findsOneWidget);
      expect(find.textContaining('67.001'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // PERF-10 T-8 straggler sweep: the "Use my location" branch
  // (`_pickCurrentLocation`, pin_drop_map_screen.dart:43-59) was uncovered —
  // the location feature sat at 78.1%, and this was its largest gap. Both
  // outcomes are driven through the real widget (no production change: the
  // plugin's own `GeolocatorPlatform.instance` seam is swapped).
  // -------------------------------------------------------------------------
  group('PinDropMapScreen — Use my location (PERF-10 straggler sweep)', () {
    late GeolocatorPlatform originalPlatform;

    setUp(() => originalPlatform = GeolocatorPlatform.instance);
    tearDown(() => GeolocatorPlatform.instance = originalPlatform);

    /// Host + real map, with an EMPTY `locations` collection (the neutral
    /// center path) and the logger pinned to a temp directory.
    Future<void> pumpMap(WidgetTester tester) async {
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
                PinDropMapScreen(tileProvider: _NoNetworkTileProvider()),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            locationsProvider.overrideWith((ref) async => const []),
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

    testWidgets('a one-shot fix drops the pin and arms Confirm', (
      tester,
    ) async {
      final fake = _FakeGeolocatorPlatform();
      GeolocatorPlatform.instance = fake;

      await pumpMap(tester);
      expect(find.text('Use my location'), findsOneWidget);
      expect(find.byIcon(Icons.location_pin), findsNothing);

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(fake.currentPositionCalls, 1);
      expect(find.byIcon(Icons.location_pin), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Use my location'), findsNothing);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.textContaining('picked: 24.861'), findsOneWidget);
      expect(find.textContaining('67.001'), findsOneWidget);
    });

    testWidgets('a failed fix is surfaced to the user, never thrown', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(throwOnFix: true);

      await pumpMap(tester);
      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not get your location. Tap the map instead.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.location_pin), findsNothing);
      expect(find.text('Use my location'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // PERF-10 T-8 (§4.4): the last uncovered line of the location feature —
  // pin_drop_map_screen.dart:70, the `error:` branch of the locations stream.
  // A failed read must still render a usable map at the neutral center: the
  // pin-drop flow is the customer's only way to set a delivery point, so a
  // provider failure must never become a dead end (or a red screen).
  group(
    'PinDropMapScreen — locations read failure (PERF-10 straggler sweep)',
    () {
      testWidgets('renders the map at the neutral center instead of erroring', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              locationsProvider.overrideWith(
                (ref) async => throw StateError('locations read failed'),
              ),
              loggerProvider.overrideWithValue(_ImmediateLoggerService()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: PinDropMapScreen(tileProvider: _NoNetworkTileProvider()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FlutterMap), findsOneWidget);
        expect(find.text('Tap on the map to select location'), findsOneWidget);
        expect(find.text('Use my location'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );
}
