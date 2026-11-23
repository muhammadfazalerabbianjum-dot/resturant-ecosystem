import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/admin/presentation/kitchen/kitchen_dashboard.dart';
import 'package:core/core.dart';

import '../helpers/test_helpers.dart';
import '../support/tenant_claim_fakes.dart';

void main() {
  group('KitchenDashboard Golden Tests (TC2)', () {
    testWidgets('KitchenDashboard renders standard ready state', (
      WidgetTester tester,
    ) async {
      // Configure uniform physical size for consistent golden snapshots
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            // W2.9: KitchenDashboard is role-gated. Authorize the RoleGate with
            // a kitchen user + branch so the real dashboard (with empty orders)
            // renders as the committed golden intends.
            currentUserProvider.overrideWith(
              (ref) async => const UserModel(
                id: 'u1',
                role: UserRole.kitchen,
                branchId: 'branch-1',
              ),
            ),
            // The authorized dashboard renders the kitchen tabs, which read
            // kitchenServiceProvider — wire it like the feature/golden tests.
            kitchenServiceProvider.overrideWithValue(
              KitchenService(
                firestore: firestore,
                logger: FakeLogger(),
                syncQueue: RecordingSyncQueue(),
                tenantClaim: const FixedTenantClaim(),
              ),
            ),
          ],
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: KitchenDashboard(),
          ),
        ),
      );

      // Wait for stream to yield
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(KitchenDashboard),
        matchesGoldenFile('goldens/kitchen_dashboard.png'),
      );
    });
  });
}
