// p32 T-3 — ops visual truth captures (p31 §Q8: the owner/manager/kitchen
// dashboards were never visually seen by a human).
//
// Each dashboard is rendered through the real theme engine
// (`AppTheme.buildTheme` on core_app's own client_config) and post-processed
// through the public `AppTheme.applyResolvedFamilies` slot table with the
// shell's REAL bundled fonts loaded via `FontLoader` (Inter/PlayfairDisplay
// from `apps/halal_boyz/assets/fonts/`, plus the MaterialIcons test fixture),
// mirroring `apps/halal_boyz/test/visual_review_capture_test.dart` (Q2/P0
// recipe). PNGs are written to `tool_uilib/p32/ops_captures/` and committed.
//
// This harness deliberately does NOT use `matchesGoldenFile`: these are
// evidence captures, not gates — the golden census must stay TOTAL=66
// (spec §1 R1 / §5.4). The committed PNGs are re-written byte-identically on
// every suite run (deterministic render), so the default suite stays green.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/cloud_function_mocks.dart';
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/admin/presentation/kitchen/kitchen_dashboard.dart';
import 'package:labs/features/admin/presentation/manager/manager_dashboard.dart';
import 'package:labs/features/admin/presentation/owner/owner_dashboard.dart';
import 'package:labs/l10n/app_localizations.dart';

import '../helpers/test_helpers.dart';
import '../support/tenant_claim_fakes.dart';

/// Output directory relative to the core_app package root (`flutter test`
/// runs with cwd = package root — the marker assertion in `setUpAll` proves it
/// before any file is written).
const String _outDir = '../tool_uilib/p32/ops_captures';

/// Loads one font family (all its weights) through [FontLoader] so captures
/// render REAL glyphs instead of the test-font blocks (p31 §Q8 visual truth).
Future<void> _loadFamily(String family, List<String> ttfPaths) async {
  final loader = FontLoader(family);
  for (final path in ttfPaths) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Writes a PNG of the finder's render to [path].
///
/// The WHOLE capture pipeline (toImage -> toByteData -> file write) runs
/// inside `WidgetTester.runAsync` - the exact architecture of flutter_test's
/// own `MatchesGoldenFile.matchAsync` (_matchers_io.dart:108-137), where the
/// golden gates' engine capture and comparator IO live. `runAsync` is the
/// only bridge that carries real async across the widget test's fake-async
/// zone: a plain `await layer.toImage(...)` in the test body hangs until the
/// 10-minute timeout (p32 T-3 diagnosis - probe bisect: pump-and-end passes,
/// capture-in-body times out; receipts in tool_uilib/p32/).
///
/// Deliberately NOT `matchesGoldenFile`: these are evidence captures, not
/// gates - the golden census must stay TOTAL=66 (spec section 1 R1 / 5.4).
Future<void> _writeCapture(
  WidgetTester tester,
  Finder root,
  String path,
) async {
  final elements = root.evaluate();
  if (elements.isEmpty) {
    fail('could not capture $path: no widget was found');
  }
  if (elements.length > 1) {
    fail('could not capture $path: matched ${elements.length} widgets');
  }
  final element = elements.single;
  final RenderObject? start = element.renderObject;
  if (start == null) {
    fail('capture root has no render object ($path)');
  }
  RenderObject current = start;
  while (!current.isRepaintBoundary) {
    final RenderObject? parent = current.parent;
    if (parent == null) {
      fail('no repaint boundary above capture root ($path)');
    }
    current = parent;
  }
  final RenderObject boundary = current;
  final layer = boundary.debugLayer;
  if (layer is! OffsetLayer) {
    fail('capture root was never painted (missing OffsetLayer, $path)');
  }
  // Everything real-async below MUST live inside runAsync: see the doc above.
  final error = await tester.runAsync<String?>(() async {
    final image = await layer.toImage(boundary.paintBounds);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return 'PNG encode returned no bytes ($path)';
      }
      final file = File(path)..createSync(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return null;
    } finally {
      image.dispose();
    }
  });
  expect(error, isNull, reason: error);
  // Pure-Dart validation; synchronous file reads are safe in the test body.
  final bytes = File(path).readAsBytesSync();
  expect(bytes.length, greaterThan(24), reason: '$path must be a PNG');
  const signature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < signature.length; i++) {
    expect(bytes[i], signature[i], reason: '$path PNG signature byte $i');
  }
  final width =
      (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
  final height =
      (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
  expect(width, greaterThan(0), reason: '$path width');
  expect(height, greaterThan(0), reason: '$path height');
}

/// Owner golden recipe double: keeps `cloudFunctionMocksProvider` inert so
/// the dashboard renders without spawning mock daemons.
class FakeCloudFunctionMocksService implements CloudFunctionMocksService {
  @override
  void startDaemons() {}

  @override
  void stopDaemons() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late Map<String, dynamic> theme;
late String headingFamily;
late String bodyFamily;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // cwd guard: every path below is relative to the core_app package root.
    expect(
      File('../WHITE_LABEL_BATCHES.md').existsSync(),
      isTrue,
      reason: 'flutter test must run from the core_app package root (cwd)',
    );
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();

    final cfg =
        jsonDecode(File('assets/client_config.json').readAsStringSync())
            as Map<String, dynamic>;
    theme = cfg['theme'] as Map<String, dynamic>;

    // REAL font families come from the white-label shell's own config (the
    // shipped client declares PlayfairDisplay/Inter). core_app's dev config
    // says "System", which `AppTheme.resolveFontFamily` maps to the built-in
    // type system — no real glyphs in a widget test — so the shell's families
    // are what "real fonts" means for these captures.
    final shellCfg =
        jsonDecode(
              File(
                '../apps/halal_boyz/assets/client_config.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final shellTheme = shellCfg['theme'] as Map<String, dynamic>;
    final typography =
        shellTheme['typography'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    headingFamily = typography['headingFont'] as String? ?? 'System';
    bodyFamily = typography['bodyFont'] as String? ?? 'System';

    await _loadFamily('Inter', <String>[
      '../apps/halal_boyz/assets/fonts/Inter-Regular.ttf',
      '../apps/halal_boyz/assets/fonts/Inter-Bold.ttf',
    ]);
    await _loadFamily('PlayfairDisplay', <String>[
      '../apps/halal_boyz/assets/fonts/PlayfairDisplay-Regular.ttf',
      '../apps/halal_boyz/assets/fonts/PlayfairDisplay-Bold.ttf',
    ]);
    // Icon glyphs (Icons.* rendered as .notdef squares without this fixture).
    await _loadFamily('MaterialIcons', <String>[
      '../apps/halal_boyz/test/fonts/MaterialIcons-Regular.otf',
    ]);
  });

  /// Production theme + the production typography slot table, bypassing only
  /// the `_isTest` guard that deliberately skips family application in tests.
  ThemeData captureTheme() {
    final base = AppTheme.buildTheme(theme);
    return base.copyWith(
      textTheme: AppTheme.applyResolvedFamilies(
        base.textTheme,
        headingFamily: headingFamily,
        bodyFamily: bodyFamily,
      ),
    );
  }

  testWidgets(
    'p32 T-3 ops capture: manager dashboard (seeded rows, real fonts)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed recipe mirrors p22_manager_dlq_goldens_test.dart (proven render of
      // the real order rows); fixed DISTINCT createdAt pins the DESC row order.
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('manager-p32').set({
        'email': 'ops-p32@test.com',
        'role': 'manager',
        'branchId': 'branch-1',
        'name': 'Ops Capture Manager',
      });
      await firestore.collection('orders').doc('o1').set({
        'tenantId': 'tenant_a',
        'branchId': 'branch-1',
        'totalCents': 1234,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 5, 12, 0)),
        'items': <Object>[],
      });
      await firestore.collection('orders').doc('o2').set({
        'tenantId': 'tenant_a',
        'branchId': 'branch-1',
        'totalCents': 5678,
        'status': 'ready',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 5, 11, 59)),
        'items': <Object>[],
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(firestore),
            authStateProvider.overrideWith(
              (ref) => Stream<User?>.value(
                MockUser(uid: 'manager-p32', email: 'ops-p32@test.com'),
              ),
            ),
            adminDataServiceProvider.overrideWithValue(
              AdminDataService(
                firestore: firestore,
                logger: FakeLogger(),
                tenantClaim: const FixedTenantClaim(),
              ),
            ),
            currentUserProvider.overrideWith(
              (ref) async => const UserModel(
                id: 'manager-p32',
                role: UserRole.manager,
                branchId: 'branch-1',
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: captureTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ManagerDashboard(),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(ManagerDashboard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _writeCapture(
        tester,
        find.byType(MaterialApp),
        '$_outDir/manager_dashboard.png',
      );
    },
  );

  testWidgets('p32 T-3 ops capture: owner dashboard (real fonts)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Owner golden recipe: role-gated dashboard authorized as owner while
    // authState stays null, so its internal signed-out empty state renders.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          currentUserProvider.overrideWith(
            (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
          ),
          cloudFunctionMocksProvider.overrideWith(
            (ref) => FakeCloudFunctionMocksService(),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OwnerDashboard(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OwnerDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _writeCapture(
      tester,
      find.byType(MaterialApp),
      '$_outDir/owner_dashboard.png',
    );
  });

  testWidgets('p32 T-3 ops capture: kitchen dashboard (real fonts)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Kitchen golden recipe: authorized kitchen user + wired kitchen service
    // over an empty fake Firestore (standard ready state).
    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          currentUserProvider.overrideWith(
            (ref) async => const UserModel(
              id: 'u1',
              role: UserRole.kitchen,
              branchId: 'branch-1',
            ),
          ),
          kitchenServiceProvider.overrideWithValue(
            KitchenService(
              firestore: firestore,
              logger: FakeLogger(),
              syncQueue: RecordingSyncQueue(),
              tenantClaim: const FixedTenantClaim(),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const KitchenDashboard(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(KitchenDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _writeCapture(
      tester,
      find.byType(MaterialApp),
      '$_outDir/kitchen_dashboard.png',
    );
  });
}
