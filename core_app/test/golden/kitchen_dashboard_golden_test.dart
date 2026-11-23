import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/admin/presentation/kitchen/kitchen_dashboard.dart';

import '../helpers/app_localizations_test_helper.dart';
import '../helpers/test_helpers.dart';
import '../support/tenant_claim_fakes.dart';

final mockKitchenUser = MockUser(
  uid: 'kitchen-golden-1',
  email: 'kitchen-golden@test.com',
);

// Mirrors the kitchen feature-test widget so the REAL KitchenDashboard renders
// its real green "ready" order content (AppColors.success rounded green).
Widget buildKitchenGolden(FirebaseFirestore firestore, {User? authUser}) {
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      authStateProvider.overrideWith((ref) => Stream<User?>.value(authUser)),
      // W2.9: KitchenDashboard is role-gated. The fallback auth repository
      // returns null user data, so wire the real repository to read the
      // seeded kitchen role from users/{uid}.
      authRepositoryProvider.overrideWith(
        (ref) => FirebaseAuthRepository(
          FirebaseAuth.instance,
          firestore,
          LoggerService(
            testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
          ),

          cache: const NoOpLocalCache(),
        ),
      ),
      loggerProvider.overrideWithValue(
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      ),
      restaurantConfigProvider.overrideWith(
        (ref) => Stream.value(const RestaurantConfigModel(currency: 'USD')),
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
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      home: KitchenDashboard(),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('KitchenDashboard golden (real widget, ready-order seed)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('kitchen-golden-1').set({
      'email': 'kitchen-golden@test.com',
      'role': 'kitchen',
      'branchId': 'branch-1',
      'name': 'Test Chef',
    });
    await firestore.collection('orders').doc('o1').set({
      'tenantId': 'tenant_a',
      'branchId': 'branch-1',
      'totalCents': 2500,
      'status': 'confirmed',
      'createdAt': Timestamp.now(),
      'items': [
        {'name': 'Burger', 'quantity': 2, 'priceCents': 1250},
      ],
      'userId': 'cust-1',
      'userName': 'C1',
      'userPhone': '+1234567890',
    });
    await tester.pumpWidget(
      buildKitchenGolden(firestore, authUser: mockKitchenUser),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await expectLater(
      find.byType(KitchenDashboard),
      matchesGoldenFile('../goldens/kitchen_dashboard.png'),
    );
  });
}
