import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/features/admin/presentation/owner/owner_dashboard.dart';

import '../../../helpers/app_localizations_test_helper.dart';
import '../../../helpers/test_helpers.dart';
import '../../../support/tenant_claim_fakes.dart';

/// COV-5 (WHITE_LABEL_b07_cov5.md acceptance #4): the panic switch
/// INTEGRATION — orders-accepting toggle behavior through the REAL chain:
/// the owner dashboard's banner Switch -> [PanicSwitchService.setOrdersAccepting]
/// -> settings/restaurantConfig.ordersAccepting (merge-set + panicUpdatedAt)
/// -> the live [ordersAcceptingProvider] stream re-rendering the banner.
/// Gap-8 contract: a MISSING config doc/field defaults to true (open).

final mockAuthUser = MockUser(uid: 'owner-test-1', email: 'owner@test.com');

const _configPath = 'settings/tenant_a_restaurantConfig';

Widget buildTestWidget({
  required FirebaseFirestore firestore,
  Stream<bool>? acceptingOverride,
}) {
  final overrides = <Override>[
    firestoreProvider.overrideWithValue(firestore),
    // The banner consumes the REAL panic chain end-to-end — only the
    // transport is faked. NO ordersAcceptingProvider override by default.
    panicSwitchServiceProvider.overrideWithValue(
      PanicSwitchService(
        firestore: firestore,
        tenantClaim: const FixedTenantClaim(),
      ),
    ),
    adminDataServiceProvider.overrideWithValue(
      AdminDataService(
        firestore: firestore,
        logger: FakeLogger(),
        tenantClaim: const FixedTenantClaim(),
      ),
    ),
    authStateProvider.overrideWith((ref) => Stream<User?>.value(mockAuthUser)),
    currentUserProvider.overrideWith(
      (ref) async => const UserModel(id: 'owner-test-1', role: UserRole.owner),
    ),
  ];
  // Failure injection for the banner's error branch: FakeFirebaseFirestore
  // cannot produce a stream outage on its own.
  if (acceptingOverride != null) {
    overrides.add(
      ordersAcceptingProvider.overrideWith((ref) => acceptingOverride),
    );
  }

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (_, __) => const OwnerDashboard(),
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

  group('COV-5 panic switch — orders-accepting toggle', () {
    testWidgets(
      '1. missing config doc defaults OPEN: banner renders the accepting state',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(firestore: fakeFirestore));
        await tester.pump();
        await tester.pumpAndSettle();

        // Gap-8 default-open contract, proven through the live UI.
        expect(find.text('Accepting Orders'), findsOneWidget);
        expect(
          find.text('Store is open and checkout is active.'),
          findsOneWidget,
        );
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      },
    );

    testWidgets(
      '2. toggling the banner Switch PAUSES orders: config doc flips to false + panicUpdatedAt stamped + banner flips to panic mode',
      (tester) async {
        await fakeFirestore.doc(_configPath).set({'ordersAccepting': true});

        await tester.pumpWidget(buildTestWidget(firestore: fakeFirestore));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('Accepting Orders'), findsOneWidget);

        // The owner flips the panic switch.
        await tester.tap(find.byType(Switch));
        await tester.pump();
        await tester.pumpAndSettle();

        // The REAL setOrdersAccepting merge-set landed in Firestore.
        final config = await fakeFirestore.doc(_configPath).get();
        expect(config.data()!['ordersAccepting'], isFalse);
        expect(config.data()!['panicUpdatedAt'], isA<Timestamp>());

        // The live stream re-rendered the banner into panic mode.
        expect(find.text('KITCHEN PANIC MODE'), findsOneWidget);
        expect(
          find.text('Incoming checkouts are halted globally.'),
          findsOneWidget,
        );
        expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      },
    );

    testWidgets(
      '3. resuming from panic mode: the toggle flips back to open and both surfaces agree',
      (tester) async {
        final panicService = PanicSwitchService(
          firestore: fakeFirestore,
          tenantClaim: const FixedTenantClaim(),
        );
        await panicService.setOrdersAccepting(false);

        await tester.pumpWidget(buildTestWidget(firestore: fakeFirestore));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('KITCHEN PANIC MODE'), findsOneWidget);

        await tester.tap(find.byType(Switch));
        await tester.pump();
        await tester.pumpAndSettle();

        final config = await fakeFirestore.doc(_configPath).get();
        expect(config.data()!['ordersAccepting'], isTrue);
        expect(find.text('Accepting Orders'), findsOneWidget);
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      },
    );

    test(
      '4. checkout-guard parity: the one-shot isOrdersAccepting reader sees the SAME doc the banner toggles',
      () async {
        final panicService = PanicSwitchService(
          firestore: fakeFirestore,
          tenantClaim: const FixedTenantClaim(),
        );

        // Missing doc -> default open.
        expect(await panicService.isOrdersAccepting(), isTrue);

        // The banner toggles OFF...
        await panicService.setOrdersAccepting(false);
        expect(await panicService.isOrdersAccepting(), isFalse);
        // ...and back ON.
        await panicService.setOrdersAccepting(true);
        expect(await panicService.isOrdersAccepting(), isTrue);
      },
    );

    testWidgets(
      '5. banner error branch: a failed accepting-stream surfaces the mapped message (fail-visible)',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            firestore: fakeFirestore,
            acceptingOverride: Stream<bool>.error(
              FirebaseException(
                plugin: 'firestore',
                code: 'unavailable',
                message: 'simulated stream outage',
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Service is temporarily unavailable. Please check your connection.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
