library;

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/features/admin/presentation/owner/owner_dashboard.dart';
import 'package:labs/l10n/app_localizations.dart';
import '../support/tenant_claim_fakes.dart';

/// UI-10 (p20) phase E golden: the owner KPI block after StatTile adoption.
///
/// Deterministic inputs only — two seeded orders in the 24 h window, an
/// accepting panic switch, an owner role gate. The metrics themselves are
/// display-only, so the picture is stable across runs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('p20 owner dashboard golden (E1 StatTile KPIs)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final firestore = FakeFirebaseFirestore();
    await firestore.collection('orders').doc('o1').set({
      'tenantId': 'tenant_a',
      'totalCents': 2500,
      'status': 'delivered',
      'createdAt': Timestamp.now(),
    });
    await firestore.collection('orders').doc('o2').set({
      'tenantId': 'tenant_a',
      'totalCents': 1500,
      'status': 'preparing',
      'createdAt': Timestamp.now(),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          loggerProvider.overrideWithValue(
            LoggerService(
              testDirectory: Directory.systemTemp.createTempSync(
                'carnama_logs_',
              ),
            ),
          ),
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(MockUser(uid: 'owner-1')),
          ),
          adminDataServiceProvider.overrideWithValue(
            AdminDataService(
              firestore: firestore,
              logger: LoggerService(
                testDirectory: Directory.systemTemp.createTempSync(
                  'carnama_logs_',
                ),
              ),
              tenantClaim: const FixedTenantClaim(),
            ),
          ),
          panicSwitchServiceProvider.overrideWithValue(
            PanicSwitchService(
              firestore: firestore,
              tenantClaim: const FixedTenantClaim(),
            ),
          ),
          ordersAcceptingProvider.overrideWith(
            (ref) => Stream<bool>.value(true),
          ),
          currentUserProvider.overrideWith(
            (ref) async => const UserModel(id: 'owner-1', role: UserRole.owner),
          ),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OwnerDashboard(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/p20_owner_dashboard.png'),
    );
  });
}
