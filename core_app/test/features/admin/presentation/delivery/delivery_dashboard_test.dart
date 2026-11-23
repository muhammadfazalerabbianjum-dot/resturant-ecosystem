import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/features/admin/domain/delivery_service.dart';
import 'package:labs/features/admin/presentation/delivery/delivery_dashboard.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';
import '../../../../helpers/app_localizations_test_helper.dart';
import '../../../../helpers/test_helpers.dart';
import 'package:go_router/go_router.dart';
import '../../../../support/tenant_claim_fakes.dart';

class FakeDriverLocation extends DriverLocationService {
  FakeDriverLocation(FirebaseFirestore firestore)
    : super(
        firestore,
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  @override
  Future<void> startTracking(String orderId) async {}
  @override
  Future<void> stopTracking() async {}
}

final mockDeliveryUser = MockUser(
  uid: 'delivery-test-1',
  email: 'delivery@test.com',
);

Widget buildTestWidget({required FirebaseFirestore firestore, User? authUser}) {
  final authStream = Stream<User?>.value(authUser);
  final locationService = FakeDriverLocation(firestore);
  final deliveryService = DeliveryService(
    firestore: firestore,
    locationService: locationService,
    logger: FakeLogger(),
    syncQueue: RecordingSyncQueue(),
    tenantClaim: const FixedTenantClaim(),
  );

  final overrides = <Override>[
    firestoreProvider.overrideWithValue(firestore),
    authStateProvider.overrideWith((ref) => authStream),
    deliveryServiceProvider.overrideWithValue(deliveryService),
  ];
  // W2.9: see owner/manager harnesses — RoleGate authorizes the signed-in
  // role; resolve currentUserProvider directly because the fallback auth
  // repository returns null user data.
  if (authUser != null) {
    overrides.add(
      currentUserProvider.overrideWith(
        (ref) async => const UserModel(
          id: 'delivery-test-1',
          role: UserRole.delivery,
          branchId: 'branch-1',
        ),
      ),
    );
  }

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      // ROUTER-2 W2.9: wrong/absent role navigates home via goNamed('home').
      // The dashboard lives at /dashboard so navigation actually moves away
      // from it (a same-route redirect would keep the redirect spinner alive).
      routerConfig: GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (_, __) => const DeliveryDashboard(),
          ),
          GoRoute(
            path: '/',
            name: 'home',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('Home Route'))),
          ),
        ],
      ),
    ),
  );
}

Future<void> seedDeliveryUser(FirebaseFirestore firestore) async {
  await firestore.collection('users').doc('delivery-test-1').set({
    'email': 'delivery@test.com',
    'role': 'delivery',
    'branchId': 'branch-1',
    'name': 'Test Driver',
  });
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

  group('DeliveryDashboard - Loading', () {
    testWidgets('1. Shows loading indicator with no auth state', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: null),
      );
      await tester.pump();
      expect(find.byType(SkeletonLoader), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('2. Shows scaffold when user has no doc', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockDeliveryUser),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('3. Shows scaffold when user has no branch', (tester) async {
      await fakeFirestore.collection('users').doc('delivery-test-1').set({
        'email': 'delivery@test.com',
        'role': 'delivery',
        'name': 'Test Driver',
      });
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockDeliveryUser),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('DeliveryDashboard - Data', () {
    testWidgets('4. Shows scaffold with fully loaded data', (tester) async {
      await seedDeliveryUser(fakeFirestore);
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockDeliveryUser),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('5. Shows scaffold with empty state', (tester) async {
      await seedDeliveryUser(fakeFirestore);
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockDeliveryUser),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('6. Shows scaffold with order data', (tester) async {
      await seedDeliveryUser(fakeFirestore);
      await fakeFirestore.collection('orders').doc('o1').set({
        'branchId': 'branch-1',
        'totalCents': 2500,
        'status': 'ready',
        'createdAt': Timestamp.now(),
        'items': [
          {'name': 'Burger', 'quantity': 1, 'priceCents': 2500},
        ],
        'userId': 'cust-1',
        'userName': 'C1',
        'userPhone': '+1234567890',
      });
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockDeliveryUser),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('DeliveryDashboard - Error', () {
    testWidgets('7. Shows scaffold on error state', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: null),
      );
      // W2.9: null auth → NoPermissionRedirect → goNamed(home). Wait for the
      // route transition so the final tree holds the single home Scaffold.
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
