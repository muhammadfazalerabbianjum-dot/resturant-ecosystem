import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/features/location/presentation/pin_drop_map_screen.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/locations/presentation/location_screen.dart';
import 'package:labs/features/locations/domain/location_model.dart';
import 'package:labs/features/locations/data/location_repository.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:core/core.dart' show firestoreProvider;
import 'package:core_ui/core_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Watches the merged (branch-scoped) menu and renders item names so a test
/// can assert the branch switch re-scopes the menu streams.
class _MenuProbe extends ConsumerWidget {
  const _MenuProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(mergedMenuProvider);
    return menu.when(
      data: (items) => Text(items.map((i) => i.name).join(',')),
      loading: () => const Text('loading'),
      error: (e, s) => Text('error: $e'),
    );
  }
}

/// LocationScreen + menu probe stacked so branch selection and the menu
/// re-scope can be asserted in one widget test.
class _BranchMenuHarness extends ConsumerWidget {
  const _BranchMenuHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Column(
        children: [
          SizedBox(height: 320, child: LocationScreen()),
          Expanded(child: Center(child: _MenuProbe())),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('LocationScreen renders app bar with title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LocationScreen(),
        ),
      ),
    );

    expect(find.text('Locations'), findsWidgets);
  });

  testWidgets('LocationScreen shows no locations text', (tester) async {
    // Override the locations provider to return an empty list
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationsProvider.overrideWith((ref) async => <LocationModel>[]),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LocationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The "No locations found" text should appear
    expect(find.text('No locations found'), findsOneWidget);
  });

  testWidgets('LocationScreen renders without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LocationScreen(),
        ),
      ),
    );

    expect(find.byType(LocationScreen), findsOneWidget);
  });

  testWidgets('LocationScreen has semantic labels', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LocationScreen(),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Locations'), findsWidgets);
  });

  // ── ROUTER-2 W2.5 / T-2: branch selection re-scopes the menu ────────────
  testWidgets('tapping a location updates the branch and re-scopes the menu', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final fake = FakeFirebaseFirestore();
    // Global item (visible to every branch) + a branch-specific override.
    await fake.collection('menus').doc('m-global').set({
      'name': 'GlobalBurger',
      'priceCents': 999,
      'isAvailable': true,
      'branchId': null,
    });
    await fake.collection('menus').doc('m-branch').set({
      'name': 'BranchPizza',
      'priceCents': 1299,
      'isAvailable': true,
      'branchId': 'loc-b',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(fake),
          locationsProvider.overrideWith(
            (ref) async => const [
              LocationModel(
                id: 'loc-b',
                name: 'Downtown B',
                lat: 24.8,
                lng: 67.0,
                address: '1 Main St',
                openHours: '9am - 10pm',
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _BranchMenuHarness(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Before selection the merged menu shows the global item only.
    expect(find.text('GlobalBurger'), findsOneWidget);
    expect(find.textContaining('BranchPizza'), findsNothing);

    await tester.tap(find.text('Downtown B'));
    await tester.pumpAndSettle();

    // currentBranchIdProvider updated through the StateNotifier API...
    final container = ProviderScope.containerOf(
      tester.element(find.byType(_BranchMenuHarness)),
    );
    expect(container.read(currentBranchIdProvider), 'loc-b');
    // ...and the branch-scoped menu stream re-queried the override.
    expect(find.textContaining('BranchPizza'), findsOneWidget);
  });

  // ── ROUTER-2 W2.6 / T-3: PinDropMapScreen reachable from LocationScreen ─
  testWidgets('map icon button opens PinDropMapScreen', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, __) => const LocationScreen(),
        ),
        GoRoute(
          path: '/location/map',
          name: 'pinDropMap',
          builder: (_, __) =>
              PinDropMapScreen(tileProvider: _NoNetworkTileProvider()),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationsProvider.overrideWith(
            (ref) async => const [
              LocationModel(
                id: 'loc-a',
                name: 'Downtown A',
                lat: 24.8,
                lng: 67.0,
                address: '2 Main St',
                openHours: '9am - 10pm',
              ),
            ],
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(PinDropMapScreen), findsOneWidget);
  });

  // ── PERF-10 T-8 (§4.4): the two lines the location coverage run left open ──
  // in location_screen.dart — 51 (the empty-state CTA callback) and 56 (the
  // ListView separator closure). Both are user-reachable branches, so they get
  // real tests rather than a coverage exemption.
  testWidgets('empty-state CTA routes to the menu (never a dead end)', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'locationsHome',
          builder: (_, __) => const LocationScreen(),
        ),
        GoRoute(
          path: '/menu',
          name: RouteNames.menu,
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('MENU ROUTE'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationsProvider.overrideWith((ref) async => <LocationModel>[]),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // UX-2: the empty list is not a dead end — the CTA is live.
    expect(find.text('No locations found'), findsOneWidget);
    expect(find.text('Browse Menu'), findsOneWidget);
    await tester.tap(find.text('Browse Menu'));
    await tester.pumpAndSettle();

    expect(find.text('MENU ROUTE'), findsOneWidget);
    expect(find.byType(LocationScreen), findsNothing);
  });

  testWidgets('a multi-branch list separates rows with a gap', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationsProvider.overrideWith(
            (ref) async => const [
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
            ],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LocationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // UI-13 (p21) phase E: the rows are the frozen library `SettingTile` and the
    // separator is the library `Gap` (card-shaped tiles are separated by
    // whitespace, not a hairline rule). The assertion pins the same fact as
    // before — one row per branch, separated — against the adopted widgets.
    expect(find.byType(SettingTile), findsNWidgets(2));
    expect(find.byType(Gap), findsOneWidget);
  });
}
