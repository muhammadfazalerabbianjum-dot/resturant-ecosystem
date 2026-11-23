import 'dart:async';

import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/features/admin/presentation/owner/tabs/panic_switch_banner.dart';

import 'owner_test_harness.dart';

/// p28 lane B (T-4) — panic_switch_banner.dart sat at 34/36: the
/// `isRefreshing` Stack overlay (L67-68) never rendered because p22 only
/// pumped settled states. A broadcast StreamController drives the refresh
/// window deterministically — no sleeps, no pump luck.
void main() {
  setUpAll(setUpOwnerFirebase);

  late FakeFirebaseFirestore db;

  setUp(() async {
    await Firebase.initializeApp();
    db = FakeFirebaseFirestore();
  });

  testWidgets(
    'a provider refresh keeps the banner visible behind its skeleton overlay',
    (tester) async {
      final controller = StreamController<bool>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        ownerHarness(
          db,
          const PanicSwitchBanner(),
          extraOverrides: <Override>[
            ordersAcceptingProvider.overrideWith((ref) => controller.stream),
          ],
        ),
      );
      controller.add(true);
      await tester.pumpAndSettle();

      expect(find.byType(BrandCard), findsOneWidget, reason: 'settled banner');
      expect(find.byType(SkeletonLoader), findsNothing, reason: 'no overlay');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PanicSwitchBanner)),
      );
      container.refresh(ordersAcceptingProvider);
      await tester.pump(); // AsyncLoading carrying the previous value

      expect(find.byType(BrandCard), findsOneWidget, reason: 'banner stays up');
      expect(
        find.byType(SkeletonLoader),
        findsOneWidget,
        reason: 'refresh overlay while reloading',
      );

      controller.add(true); // the refresh stream delivers again
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonLoader), findsNothing, reason: 'refresh done');

      // L59-61: the switch's onChanged writes the panic gate through the
      // injected service — the toggle contract, not just the render.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      final config = await db
          .collection('settings')
          .doc('tenant_a_restaurantConfig')
          .get();
      expect(
        config.data()?['ordersAccepting'],
        isFalse,
        reason: 'toggling off writes ordersAccepting=false',
      );
    },
  );

  testWidgets(
    'a failed orders-accepting stream renders the mapped error line',
    (tester) async {
      final controller = StreamController<bool>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        ownerHarness(
          db,
          const PanicSwitchBanner(),
          extraOverrides: <Override>[
            ordersAcceptingProvider.overrideWith((ref) => controller.stream),
          ],
        ),
      );
      final failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      controller.addError(failure);
      await tester.pumpAndSettle();

      expect(
        find.text(FirebaseExceptionMapper.map(failure)),
        findsOneWidget,
        reason: 'the mapped, user-facing error line — no raw trace',
      );
    },
  );
}
