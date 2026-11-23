// UI-13 (p21) phase B golden pair (order-tracker steps -> OrderTimeline).
//
// Deliberate-first protocol (L12.6, p16/p20 standard): BEFORE baselines are
// captured with `--update-goldens` while the PRE-WIRING widget is in place,
// archived to tool_uilib/p21/visual_review/p21_tracker_{light,dark}_before.png
// with SHA-256 recorded in p21_report.md; after the adoption the plain run
// must FAIL against those baselines before the declared re-capture writes the
// committed AFTER pair (`snapshots/order_tracker_glassmorphism*.png`).
import 'package:core_ui/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_tracker_steps_widget.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// Pump the real steps widget (preparing = index 2 of 8) and compare against
/// [golden] — everything stays inside `mockNetworkImagesFor` like the p20
/// original so image-loading hooks cover the capture too.
Future<void> _capture(
  WidgetTester tester, {
  required ThemeMode mode,
  required String golden,
}) async {
  final dummyOrder = OrderModel(
    id: 'golden_snapshot_123',
    customerId: 'user1',
    totalCents: 1500,
    createdAt: DateTime.now(),
  );
  await mockNetworkImagesFor(() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OrderTrackerStepsWidget(
            order: dummyOrder,
            currentStatus: OrderStatus.preparing,
          ),
        ),
      ),
    );
    // 300ms executes the AnimatedContainer entrances without hooking any
    // infinite cancellation timer loop (p20's rule, preserved).
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(OrderTrackerStepsWidget),
      matchesGoldenFile(golden),
    );
  });
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('OrderTracker Glassmorphism Golden Test (Law 17) — light', (
    tester,
  ) async {
    await _capture(
      tester,
      mode: ThemeMode.light,
      golden: 'snapshots/order_tracker_glassmorphism.png',
    );
  });

  testWidgets('OrderTracker Glassmorphism Golden Test (Law 17) — dark', (
    tester,
  ) async {
    await _capture(
      tester,
      mode: ThemeMode.dark,
      golden: 'snapshots/order_tracker_glassmorphism_dark.png',
    );
  });
}
