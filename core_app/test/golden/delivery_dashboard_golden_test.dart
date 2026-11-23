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
import 'package:labs/features/admin/presentation/delivery/delivery_dashboard.dart';
import 'package:labs/features/orders/domain/order_model.dart';

import '../helpers/app_localizations_test_helper.dart';

final mockDeliveryUser = MockUser(
  uid: 'delivery-golden-1',
  email: 'delivery-golden@test.com',
);

// Overrides the dashboard's two StreamProviders so no DeliveryService /
// DriverLocationService (which boots a real LoggerService -> path_provider
// plugin) is constructed. The REAL DeliveryDashboard widget renders its real
// "my orders" / "available" tabs from these streams.
Widget buildDeliveryGolden(FirebaseFirestore firestore, {User? authUser}) {
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      authStateProvider.overrideWith((ref) => Stream<User?>.value(authUser)),
      // W2.9: DeliveryDashboard is role-gated. The fallback auth repository
      // returns null user data, so wire the real repository to read the
      // seeded delivery role from users/{uid}.
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
      myOrdersProvider.overrideWith(
        (ref, arg) => Stream.value(const <OrderModel>[]),
      ),
      availableOrdersProvider.overrideWith(
        (ref, arg) => Stream.value(const <OrderModel>[]),
      ),
    ],
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      home: DeliveryDashboard(),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('DeliveryDashboard golden (real widget, signed-in seed)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('delivery-golden-1').set({
      'email': 'delivery-golden@test.com',
      'role': 'delivery',
      'branchId': 'branch-1',
      'name': 'Test Driver',
    });
    await tester.pumpWidget(
      buildDeliveryGolden(firestore, authUser: mockDeliveryUser),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await expectLater(
      find.byType(DeliveryDashboard),
      matchesGoldenFile('../goldens/delivery_dashboard.png'),
    );
  });
}
