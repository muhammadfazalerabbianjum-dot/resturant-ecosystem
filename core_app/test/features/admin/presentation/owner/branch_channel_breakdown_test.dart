import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/presentation/owner/breakdown/branch_channel_breakdown.dart';

import '../../../../helpers/app_localizations_test_helper.dart';

/// P1-7 — the owner dashboard's branch × channel breakdown at the two supported
/// width classes (handoff: 390 px phone, 1024 px tablet/web).
///
/// The card's assertion is "widget test at both sizes; no overflow errors". An
/// overflow is a FlutterError raised during layout, so each case captures
/// `FlutterError.onError` and fails on anything that arrives — merely pumping
/// without error would pass even if the framework logged the overflow to the
/// console instead of throwing.
List<Map<String, dynamic>> _rows() => <Map<String, dynamic>>[
  {
    'kind': 'sale',
    'branchId': 'branch_main',
    'channel': 'counter',
    'totalCents': 4200,
  },
  {
    'kind': 'sale',
    'branchId': 'branch_main',
    'channel': 'app',
    'totalCents': 1800,
  },
  {
    'kind': 'sale',
    'branchId': 'branch_downtown_market_hall',
    'channel': 'waiter',
    'totalCents': 990000,
  },
  {
    'kind': 'reversal',
    'branchId': 'branch_main',
    'channel': 'counter',
    'totalCents': -1200,
  },
];

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  addTearDown(() => FlutterError.onError = previous);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: BranchChannelBreakdownPanel(
            data: BranchChannelBreakdown.fromRows(_rows()),
            currencyCode: 'CAD',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // An overflow is reported as a FlutterError; a silent RenderFlex exception
  // would otherwise only appear in the console.
  expect(
    errors,
    isEmpty,
    reason:
        'layout errors at ${size.width.toInt()} px: ${errors.map((e) => e.exceptionAsString()).join(' | ')}',
  );
  expect(tester.takeException(), isNull);
}

void main() {
  group('P1-7 branch × channel breakdown', () {
    testWidgets('renders at 390 px (phone) without overflow', (tester) async {
      await _pumpAt(tester, const Size(390, 844));

      expect(find.text('branch_main'), findsOneWidget);
      expect(
        find.textContaining('branch_downtown_market_hall'),
        findsOneWidget,
        reason:
            'a long branch id must be present, and ellipsised rather than '
            'overflowing',
      );
      // 4200 + 1800 - 1200 = 4800 in the main branch.
      expect(find.textContaining('48.00'), findsWidgets);
    });

    testWidgets('renders at 1024 px (tablet/web) without overflow', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(1024, 768));

      expect(find.text('branch_main'), findsOneWidget);
      expect(find.textContaining('48.00'), findsWidgets);
      // The wide layout puts the summary beside the branch list: both the
      // revenue header and a branch row exist in the same row of the tree.
      expect(find.byType(Card), findsNWidgets(2));
    });

    testWidgets('an empty day shows the localised empty state, not a crash', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizationsTestHelper.delegates,
          supportedLocales: AppLocalizationsTestHelper.supportedLocales,
          home: Scaffold(
            body: BranchChannelBreakdownPanel(
              data: BranchChannelBreakdown.fromRows(const []),
              currencyCode: 'CAD',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('P1-7 aggregation mirrors rollups.ts', () {
    test('a reversal subtracts revenue but never erases the sale', () {
      final breakdown = BranchChannelBreakdown.fromRows(_rows());

      expect(breakdown.ordersCount, 3);
      expect(breakdown.refundsCents, 1200);
      expect(breakdown.revenueCents, 4200 + 1800 - 1200 + 990000);
      expect(breakdown.revenueByChannel['counter'], 4200 - 1200);
      expect(breakdown.revenueByChannel['app'], 1800);

      final main = breakdown.branches.firstWhere(
        (b) => b.branchId == 'branch_main',
      );
      expect(main.ordersCount, 2);
      expect(main.refundsCents, 1200);
      expect(main.revenueCents, 4800);
    });

    test('branches are ordered by revenue, unknown bucket is kept', () {
      final breakdown = BranchChannelBreakdown.fromRows([
        {'kind': 'sale', 'totalCents': 100},
        {'kind': 'sale', 'branchId': 'b1', 'channel': 'app', 'totalCents': 500},
      ]);

      expect(breakdown.branches.first.branchId, 'b1');
      expect(breakdown.branches.last.branchId, 'unknown');
      expect(breakdown.revenueByChannel[kUnknownChannel], 100);
    });

    test('a row without an integer totalCents is ignored, not zero-filled', () {
      final breakdown = BranchChannelBreakdown.fromRows([
        {'kind': 'sale', 'branchId': 'b1', 'totalCents': '4200'},
        {'kind': 'sale', 'branchId': 'b1', 'totalCents': 700},
      ]);

      expect(breakdown.ordersCount, 1);
      expect(breakdown.revenueCents, 700);
    });
  });
}
