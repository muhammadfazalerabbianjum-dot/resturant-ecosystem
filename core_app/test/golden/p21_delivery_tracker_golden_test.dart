// UI-13 (p21) phase F golden pair — M-5 delivery tracker, en + ar (§3-F).
//
// Deliberate-first protocol (L12.6): baselines are captured with
// `--update-goldens` while the PRE-ADOPTION screen is in place and archived to
// `tool_uilib/p21/visual_review/p21_delivery_tracker_{en,ar}_before.png`
// (SHA-256 recorded in `p21_report.md`); after the adoption the plain run must
// FAIL against those baselines before the declared re-capture writes the
// committed AFTER pair.
import 'package:core_ui/src/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_tracker_screen.dart'
    show singleOrderProvider;
import 'package:labs/features/tracking/presentation/delivery_tracker_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

/// A mid-flight order: stage one in progress, so the golden shows a completed,
/// a current and a future timeline step plus the pending status badge.
final OrderModel _cookingOrder = OrderModel(
  id: 'order-77',
  customerId: 'user-test',
  status: OrderStatus.cooking,
  totalCents: 1500,
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _capture(
  WidgetTester tester, {
  required String locale,
  required String golden,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        singleOrderProvider(
          'order-77',
        ).overrideWith((ref) => Stream<OrderModel?>.value(_cookingOrder)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          useMaterial3: true,
        ),
        home: const DeliveryTrackerScreen(orderId: 'order-77'),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(DeliveryTrackerScreen),
    matchesGoldenFile(golden),
  );
}

void main() {
  testWidgets('P21 delivery tracker golden — en', (tester) async {
    await _capture(
      tester,
      locale: 'en',
      golden: 'snapshots/p21_delivery_tracker_en.png',
    );
  });

  testWidgets('P21 delivery tracker golden — ar (RTL parity)', (tester) async {
    await _capture(
      tester,
      locale: 'ar',
      golden: 'snapshots/p21_delivery_tracker_ar.png',
    );
  });
}
