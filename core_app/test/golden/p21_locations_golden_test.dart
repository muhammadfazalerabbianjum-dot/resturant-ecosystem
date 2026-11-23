// UI-13 (p21) phase E golden pair — M-4 locations + maps, en + ar (§3-E).
//
// Deliberate-first protocol (L12.6): baselines are captured with
// `--update-goldens` while the PRE-ADOPTION screens are in place and archived to
// `tool_uilib/p21/visual_review/p21_locations_{en,ar}_before.png` /
// `p21_pindrop_{en,ar}_before.png` (SHA-256 recorded in `p21_report.md`); after
// the adoption the plain run must FAIL against those baselines before the
// declared re-capture writes the committed AFTER pair.
import 'package:core_ui/src/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:labs/features/location/presentation/pin_drop_map_screen.dart';
import 'package:labs/features/locations/data/location_repository.dart';
import 'package:labs/features/locations/domain/location_model.dart';
import 'package:labs/features/locations/presentation/location_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

import '../features/location/presentation/hermetic_tile_provider.dart';

const List<LocationModel> _branches = [
  LocationModel(
    id: 'loc-a',
    name: 'Branch A',
    lat: 24.8607,
    lng: 67.0011,
    address: '1 A St',
    openHours: '9am - 5pm',
  ),
  LocationModel(
    id: 'loc-b',
    name: 'Branch B',
    lat: 24.9,
    lng: 67.1,
    address: '2 B St',
    openHours: '10am - 6pm',
  ),
];

/// Locks the standard Android HD viewport so goldens are device-agnostic.
void _lockViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Deterministic host: font fetching off, brand-seeded scheme, fixed locale.
Widget _wrap(
  Widget child, {
  required String locale,
  List<Override> overrides = const [],
}) {
  GoogleFonts.config.allowRuntimeFetching = false;
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
      ),
      home: child,
    ),
  );
}

List<Override> get _seededBranches => [
  locationsProvider.overrideWith((ref) async => _branches),
];

Future<void> _captureLocations(
  WidgetTester tester, {
  required String locale,
  required String golden,
}) async {
  _lockViewport(tester);
  await tester.pumpWidget(
    _wrap(const LocationScreen(), locale: locale, overrides: _seededBranches),
  );
  await tester.pumpAndSettle();

  await expectLater(find.byType(LocationScreen), matchesGoldenFile(golden));
}

Future<void> _capturePinDrop(
  WidgetTester tester, {
  required String locale,
  required String golden,
}) async {
  _lockViewport(tester);
  await tester.pumpWidget(
    _wrap(
      PinDropMapScreen(tileProvider: NoNetworkTileProvider()),
      locale: locale,
      overrides: _seededBranches,
    ),
  );
  await tester.pumpAndSettle();

  await expectLater(find.byType(PinDropMapScreen), matchesGoldenFile(golden));
}

void main() {
  testWidgets('P21 locations list golden — en', (tester) async {
    await _captureLocations(
      tester,
      locale: 'en',
      golden: 'snapshots/p21_locations_en.png',
    );
  });

  testWidgets('P21 locations list golden — ar (RTL parity)', (tester) async {
    await _captureLocations(
      tester,
      locale: 'ar',
      golden: 'snapshots/p21_locations_ar.png',
    );
  });

  testWidgets('P21 pin-drop map golden — en', (tester) async {
    await _capturePinDrop(
      tester,
      locale: 'en',
      golden: 'snapshots/p21_pindrop_en.png',
    );
  });

  testWidgets('P21 pin-drop map golden — ar (RTL parity)', (tester) async {
    await _capturePinDrop(
      tester,
      locale: 'ar',
      golden: 'snapshots/p21_pindrop_ar.png',
    );
  });
}
