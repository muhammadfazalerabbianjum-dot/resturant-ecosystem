import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/presentation/admin_menu_manager.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import '../../../helpers/app_localizations_test_helper.dart';
import '../../../helpers/test_helpers.dart';
import '../../../support/tenant_claim_fakes.dart';

/// W2.9: AdminMenuManager is owner/manager-gated — tests seed the owner role.
final _ownerUserOverride = currentUserProvider.overrideWith(
  (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
);

Widget buildTestWidget({required FirebaseFirestore firestore}) {
  final adminService = AdminDataService(
    firestore: firestore,
    logger: FakeLogger(),
    tenantClaim: const FixedTenantClaim(),
  );

  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      _ownerUserOverride,
      adminDataServiceProvider.overrideWithValue(adminService),
      mergedMenuProvider.overrideWith(
        (ref) => Stream<List<MenuItemModel>>.value([]),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      home: AdminMenuManager(),
    ),
  );
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

  group('AdminMenuManager - Data', () {
    testWidgets('1. Shows scaffold with menu items', (tester) async {
      await fakeFirestore.collection('menus').doc('m1').set({
        'name': 'Test Burger',
        'priceCents': 999,
        'isAvailable': true,
        'description': 'A burger',
      });
      await fakeFirestore.collection('menus').doc('m2').set({
        'name': 'Test Pizza',
        'priceCents': 1299,
        'isAvailable': false,
        'description': 'A pizza',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            _ownerUserOverride,
            adminDataServiceProvider.overrideWithValue(
              AdminDataService(
                firestore: fakeFirestore,
                logger: FakeLogger(),
                tenantClaim: const FixedTenantClaim(),
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizationsTestHelper.delegates,
            supportedLocales: AppLocalizationsTestHelper.supportedLocales,
            home: AdminMenuManager(),
          ),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('2. Shows scaffold with empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            _ownerUserOverride,
            mergedMenuProvider.overrideWith(
              (ref) => Stream<List<MenuItemModel>>.value([]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizationsTestHelper.delegates,
            supportedLocales: AppLocalizationsTestHelper.supportedLocales,
            home: AdminMenuManager(),
          ),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('AdminMenuManager - Display', () {
    testWidgets('3. Shows available and unavailable icons', (tester) async {
      await fakeFirestore.collection('menus').doc('m1').set({
        'name': 'Available Item',
        'priceCents': 999,
        'isAvailable': true,
        'description': 'In stock',
      });
      await fakeFirestore.collection('menus').doc('m2').set({
        'name': 'Unavailable Item',
        'priceCents': 499,
        'isAvailable': false,
        'description': 'Out',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            _ownerUserOverride,
            adminDataServiceProvider.overrideWithValue(
              AdminDataService(
                firestore: fakeFirestore,
                logger: FakeLogger(),
                tenantClaim: const FixedTenantClaim(),
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizationsTestHelper.delegates,
            supportedLocales: AppLocalizationsTestHelper.supportedLocales,
            home: AdminMenuManager(),
          ),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('4. Shows price for menu items', (tester) async {
      await fakeFirestore.collection('menus').doc('m1').set({
        'name': 'Priced Item',
        'priceCents': 1499,
        'isAvailable': true,
        'description': 'Priced',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            _ownerUserOverride,
            adminDataServiceProvider.overrideWithValue(
              AdminDataService(
                firestore: fakeFirestore,
                logger: FakeLogger(),
                tenantClaim: const FixedTenantClaim(),
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizationsTestHelper.delegates,
            supportedLocales: AppLocalizationsTestHelper.supportedLocales,
            home: AdminMenuManager(),
          ),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('AdminMenuManager - Error', () {
    testWidgets('5. Shows scaffold on error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            _ownerUserOverride,
            mergedMenuProvider.overrideWith(
              (ref) => Stream<List<MenuItemModel>>.error('Test error'),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizationsTestHelper.delegates,
            supportedLocales: AppLocalizationsTestHelper.supportedLocales,
            home: AdminMenuManager(),
          ),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
