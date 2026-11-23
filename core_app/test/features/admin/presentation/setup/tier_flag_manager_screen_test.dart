import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/features/admin/presentation/setup/tier_flag_manager_screen.dart';
import '../../../../helpers/app_localizations_test_helper.dart';

Widget buildTestWidget(FirebaseFirestore firestore) {
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      // W2.9: TierFlagManagerScreen is owner-gated — authorize in tests.
      currentUserProvider.overrideWith(
        (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      home: TierFlagManagerScreen(),
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

  testWidgets('TierFlagManagerScreen renders app bar', (tester) async {
    await fakeFirestore.collection('settings').doc('featureFlags').set({
      'earlyBird': true,
      'happyHour': true,
    });
    await tester.pumpWidget(buildTestWidget(fakeFirestore));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('TierFlagManagerScreen shows tier flag manager title', (
    tester,
  ) async {
    await fakeFirestore.collection('settings').doc('featureFlags').set({
      'earlyBird': true,
    });
    await tester.pumpWidget(buildTestWidget(fakeFirestore));
    await tester.pumpAndSettle();
    expect(find.text('Tier & Flag Manager'), findsAtLeastNWidgets(1));
  });

  testWidgets('TierFlagManagerScreen shows flags from Firestore', (
    tester,
  ) async {
    await fakeFirestore.collection('settings').doc('featureFlags').set({
      'earlyBird': true,
      'happyHour': true,
      'studentDiscount': false,
    });
    await tester.pumpWidget(buildTestWidget(fakeFirestore));
    await tester.pumpAndSettle();
    // The screen renders a SettingTile for each flag from Firestore
    expect(find.byType(SettingTile), findsNWidgets(3));
    expect(find.text('earlyBird'), findsOneWidget);
    expect(find.text('happyHour'), findsOneWidget);
    expect(find.text('studentDiscount'), findsOneWidget);
  });

  testWidgets('TierFlagManagerScreen shows save button', (tester) async {
    await fakeFirestore.collection('settings').doc('featureFlags').set({
      'earlyBird': true,
    });
    await tester.pumpWidget(buildTestWidget(fakeFirestore));
    await tester.pumpAndSettle();
    expect(find.byType(BrandButton), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('TierFlagManagerScreen does not crash', (tester) async {
    await fakeFirestore.collection('settings').doc('featureFlags').set({
      'earlyBird': true,
    });
    await tester.pumpWidget(buildTestWidget(fakeFirestore));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('TierFlagManagerScreen shows empty state when no flags', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(fakeFirestore));
    await tester.pumpAndSettle();
    expect(find.text('No feature flags configured yet.'), findsOneWidget);
  });

  testWidgets('TierFlagManagerScreen persists toggled flag to Firestore', (
    tester,
  ) async {
    await fakeFirestore.collection('settings').doc('featureFlags').set({
      'earlyBird': true,
    });
    await tester.pumpWidget(buildTestWidget(fakeFirestore));
    await tester.pumpAndSettle();

    // Toggle the earlyBird switch off
    await tester.tap(find.byType(Switch));
    await tester.pump();

    // Tap Save — pump fixed durations instead of pumpAndSettle because the
    // _saving spinner + SnackBar keep animations alive indefinitely.
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    // Verify the flag was persisted to Firestore
    final doc = await fakeFirestore
        .collection('settings')
        .doc('featureFlags')
        .get();
    expect(doc.data()?['earlyBird'], isFalse);
  });
}
