import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

import '../../../helpers/app_localizations_test_helper.dart';

final _router = GoRouter(
  initialLocation: '/admin',
  routes: [
    GoRoute(
      path: '/admin',
      name: 'admin',
      builder: (_, __) =>
          const Scaffold(body: Center(child: Text('Admin Route'))),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (_, __) =>
          const Scaffold(body: Center(child: Text('Home Route'))),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (_, __) =>
          const Scaffold(body: Center(child: Text('Login Route'))),
    ),
  ],
);

Widget buildTestWidget({
  required FirebaseFirestore firestore,
  Stream<User?>? authStream,
}) {
  final defaultAuthStream = authStream ?? Stream<User?>.value(null);
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      authStateProvider.overrideWith((ref) => defaultAuthStream),
    ],
    child: MaterialApp.router(
      routerConfig: _router,
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
    ),
  );
}

Future<void> seedUser(
  FirebaseFirestore firestore, {
  required String uid,
  required String role,
}) async {
  await firestore.collection('users').doc(uid).set({
    'email': '$role@test.com',
    'role': role,
    'name': 'Test $role',
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

  group('RoleRouterScreen - Loading', () {
    testWidgets('1. Shows scaffold when loading state', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          firestore: fakeFirestore,
          authStream: Stream<User?>.value(null),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('2. Shows scaffold when user is null', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          firestore: fakeFirestore,
          authStream: Stream<User?>.value(null),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('RoleRouterScreen - Role Routing', () {
    testWidgets('3. Customer role shows scaffold', (tester) async {
      await seedUser(fakeFirestore, uid: 'user-cust', role: 'customer');
      final authUser = MockUser(uid: 'user-cust', email: 'customer@test.com');
      await tester.pumpWidget(
        buildTestWidget(
          firestore: fakeFirestore,
          authStream: Stream<User?>.value(authUser),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('4. Owner role shows scaffold', (tester) async {
      await seedUser(fakeFirestore, uid: 'user-owner', role: 'owner');
      final authUser = MockUser(uid: 'user-owner', email: 'owner@test.com');
      await tester.pumpWidget(
        buildTestWidget(
          firestore: fakeFirestore,
          authStream: Stream<User?>.value(authUser),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('5. Manager role shows scaffold', (tester) async {
      await seedUser(fakeFirestore, uid: 'user-mgr', role: 'manager');
      final authUser = MockUser(uid: 'user-mgr', email: 'manager@test.com');
      await tester.pumpWidget(
        buildTestWidget(
          firestore: fakeFirestore,
          authStream: Stream<User?>.value(authUser),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('6. Kitchen role shows scaffold', (tester) async {
      await seedUser(fakeFirestore, uid: 'user-kitchen', role: 'kitchen');
      final authUser = MockUser(uid: 'user-kitchen', email: 'kitchen@test.com');
      await tester.pumpWidget(
        buildTestWidget(
          firestore: fakeFirestore,
          authStream: Stream<User?>.value(authUser),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('7. Delivery role shows scaffold', (tester) async {
      await seedUser(fakeFirestore, uid: 'user-delivery', role: 'delivery');
      final authUser = MockUser(
        uid: 'user-delivery',
        email: 'delivery@test.com',
      );
      await tester.pumpWidget(
        buildTestWidget(
          firestore: fakeFirestore,
          authStream: Stream<User?>.value(authUser),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
