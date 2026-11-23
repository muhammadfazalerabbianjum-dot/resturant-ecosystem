import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/presentation/analytics/revenue_chart_widget.dart';

import '../../../helpers/app_localizations_test_helper.dart';

/// COV-5 (WHITE_LABEL_b07_cov5.md acceptance #2): the revenue chart provider
/// INTEGRATION — [deliveredRevenueProvider] (W8.5 stream-in-provider +
/// W8.7 bounds: delivered-only, 7-day window, Law-10 cap 200) against a real
/// FakeFirebaseFirestore, and the production [RevenueChartWidget] branches
/// (data / empty / W8.5 fail-visible error mapped through
/// FirebaseExceptionMapper).

/// Maps a delivered order in the `orders` collection.
Future<void> seedOrder(
  FakeFirebaseFirestore firestore, {
  required String orderId,
  required DateTime createdAt,
  String status = 'delivered',
  int totalCents = 1000,
}) async {
  await firestore.collection('orders').doc(orderId).set({
    'tenantId': 'tenant_a',
    'branchId': 'branch-1',
    'status': status,
    'totalCents': totalCents,
    'createdAt': Timestamp.fromDate(createdAt),
    'items': <Object>[],
  });
}

Future<void> pumpChart(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
  Stream<QuerySnapshot<Map<String, dynamic>>>? deliveredOverride,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tenantIdProvider.overrideWith((ref) async => 'tenant_a'),
        firestoreProvider.overrideWithValue(firestore),
        if (deliveredOverride != null)
          deliveredRevenueProvider.overrideWith((ref) => deliveredOverride),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizationsTestHelper.delegates,
        supportedLocales: AppLocalizationsTestHelper.supportedLocales,
        home: Scaffold(body: RevenueChartWidget()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group(
    'COV-5 deliveredRevenueProvider — bounds + filter (provider layer)',
    () {
      test(
        '1. streams only DELIVERED orders within the 7-day window',
        () async {
          final now = DateTime.now();
          await seedOrder(
            fakeFirestore,
            orderId: 'rev-a',
            createdAt: now.subtract(const Duration(minutes: 1)),
          );
          await seedOrder(
            fakeFirestore,
            orderId: 'rev-d',
            createdAt: now.subtract(const Duration(days: 6)),
          );
          // Wrong status (fresh preparing) — excluded.
          await seedOrder(
            fakeFirestore,
            orderId: 'prep-x',
            createdAt: now.subtract(const Duration(minutes: 2)),
            status: 'preparing',
          );
          // Right status but outside the window (8 days) — excluded.
          await seedOrder(
            fakeFirestore,
            orderId: 'stale-x',
            createdAt: now.subtract(const Duration(days: 8)),
          );

          final container = ProviderContainer(
            overrides: [
              tenantIdProvider.overrideWith((ref) async => 'tenant_a'),
              firestoreProvider.overrideWithValue(fakeFirestore),
            ],
          );
          addTearDown(container.dispose);

          final snap = await container.read(deliveredRevenueProvider.future);
          expect(
            snap.docs.map((d) => d.id),
            unorderedEquals(<String>['rev-a', 'rev-d']),
          );
        },
      );

      test('2. the delivered snapshot is Law-10 capped at 200 docs', () async {
        final now = DateTime.now();
        for (var i = 0; i < kRevenueChartDeliveredCap + 5; i++) {
          await seedOrder(
            fakeFirestore,
            orderId: 'cap-o$i',
            createdAt: now.subtract(Duration(minutes: i + 1)),
          );
        }

        final container = ProviderContainer(
          overrides: [
            tenantIdProvider.overrideWith((ref) async => 'tenant_a'),
            firestoreProvider.overrideWithValue(fakeFirestore),
          ],
        );
        addTearDown(container.dispose);

        final snap = await container.read(deliveredRevenueProvider.future);
        expect(snap.docs.length, kRevenueChartDeliveredCap);
      });
    },
  );

  group('COV-5 RevenueChartWidget — render branches', () {
    testWidgets('3. data branch: renders the LineChart from delivered orders', (
      tester,
    ) async {
      final now = DateTime.now();
      await seedOrder(
        fakeFirestore,
        orderId: 'rev-a',
        createdAt: now.subtract(const Duration(minutes: 1)),
      );
      await seedOrder(
        fakeFirestore,
        orderId: 'rev-b',
        createdAt: now.subtract(const Duration(days: 1)),
      );
      await seedOrder(
        fakeFirestore,
        orderId: 'rev-c',
        createdAt: now.subtract(const Duration(days: 2)),
      );
      // Non-matching docs must not crash the chart either.
      await seedOrder(
        fakeFirestore,
        orderId: 'prep-x',
        createdAt: now.subtract(const Duration(minutes: 2)),
        status: 'preparing',
      );

      await pumpChart(tester, firestore: fakeFirestore);

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('No revenue data for the last 7 days.'), findsNothing);
    });

    testWidgets('4. empty branch: "No revenue data" when nothing matches', (
      tester,
    ) async {
      final now = DateTime.now();
      await seedOrder(
        fakeFirestore,
        orderId: 'stale-x',
        createdAt: now.subtract(const Duration(days: 8)),
      );

      await pumpChart(tester, firestore: fakeFirestore);

      expect(find.text('No revenue data for the last 7 days.'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets(
      '5. error branch: stream failures surface mapped through FirebaseExceptionMapper in the error hue (W8.5 fail-visible)',
      (tester) async {
        await pumpChart(
          tester,
          firestore: fakeFirestore,
          deliveredOverride: Stream<QuerySnapshot<Map<String, dynamic>>>.error(
            FirebaseException(
              plugin: 'firestore',
              code: 'unavailable',
              message: 'simulated stream outage',
            ),
          ),
        );

        const mapped =
            'Service is temporarily unavailable. '
            'Please check your connection.';
        final textFinder = find.text(mapped);
        expect(textFinder, findsOneWidget);
        // The empty state must NOT swallow the error (the pre-conversion
        // StreamBuilder bug W8.5 fixed).
        expect(find.text('No revenue data for the last 7 days.'), findsNothing);
        // Fail-VISIBLE: the mapped text is painted in the brand error hue.
        final element = tester.element(textFinder);
        expect(
          tester.widget<Text>(textFinder).style?.color,
          BrandColors.of(element).error,
        );
      },
    );
  });
}
