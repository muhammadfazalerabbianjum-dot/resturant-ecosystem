import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/core.dart';
import 'package:labs/features/waitlist/presentation/waitlist_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

/// Builds the WaitlistScreen with a hermetic ProviderScope.
///
/// The screen reads [currentUserIdProvider] (signed-in uid) and
/// [currentBranchIdProvider] (resolved from seeded Firestore branches), so the
/// harness overrides auth/firestore/logger and seeds an active branch â€” real
/// production wiring, no stubs.
Future<Widget> _harness(
  FakeFirebaseFirestore firestore, {
  String? userId = 'user1',
}) async {
  SharedPreferences.setMockInitialValues({});
  await firestore.collection('branches').doc('branch1').set({
    'name': 'Downtown',
    'isActive': true,
    'isMainBranch': true,
  });
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue(userId),
      firestoreProvider.overrideWithValue(firestore),
      loggerProvider.overrideWithValue(
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: WaitlistScreen(),
    ),
  );
}

/// Fully retires a shown SnackBar: completes the entrance animation, lets the
/// 4 s auto-hide timer fire, then completes the exit animation. Without the
/// final settle the exit ticker never finishes under the fake clock and the
/// NEXT showSnackBar silently QUEUES behind the dying one.
Future<void> _drainSnackbar(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WaitlistScreen', () {
    testWidgets('renders title + party size selector with default 2', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(await _harness(firestore));
      // Let the CurrentBranchNotifier resolve asynchronously.
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Waitlist'), findsWidgets);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('party size respects 1..12 bounds', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(await _harness(firestore));
      await tester.pump(const Duration(milliseconds: 200));

      // Increment to 3.
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      expect(find.text('3'), findsOneWidget);

      // Min bound: decrement to 1, then cannot go below.
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      // Max bound: hammer add -> stays at 12.
      for (var i = 0; i < 15; i++) {
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pump();
      }
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('shows the Join Waitlist button', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(await _harness(firestore));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Join Waitlist'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Join writes a waitlist entry for the signed-in user', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(await _harness(firestore));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Join Waitlist'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final snap = await firestore.collection('waitlist').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['userId'], 'user1');
      expect(snap.docs.first.data()['branchId'], 'branch1');
      expect(snap.docs.first.data()['partySize'], 2);
    });

    testWidgets('shows the live branch-scoped queue position ("You are #2")', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      // T-2: user2 already queued ahead (myTicket 1) — the branch ordinal doc
      // says the next ticket is 2 and nobody is served. user1's join takes
      // ticket 2 → position = 2 − 0 − 1 = 1 person ahead → display "#2".
      await firestore.collection('waitlist').doc('branch1_user2').set({
        'userId': 'user2',
        'branchId': 'branch1',
        'partySize': 2,
        'myTicket': 1,
        'status': 'waiting',
      });
      await firestore
          .collection('branches')
          .doc('branch1')
          .collection('waitlist_meta')
          .doc('meta')
          .set({'nextTicket': 2, 'nowServing': 0});

      await tester.pumpWidget(await _harness(firestore));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Join Waitlist'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('You are #2 in line'), findsOneWidget);

      // Fully retire the join snackbar so the test ends with no pending
      // timers and the messenger idle.
      await _drainSnackbar(tester);
    });

    testWidgets('re-join surfaces the honest alreadyJoined state (no dupe)', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(await _harness(firestore));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Join Waitlist'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('You are on the waitlist!'), findsOneWidget);
      // Fully retire the first snackbar — a queued second showSnackBar would
      // otherwise never surface within the next pumps.
      await _drainSnackbar(tester);

      await tester.tap(find.text('Join Waitlist'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('You are already on the waitlist for this branch.'),
        findsOneWidget,
      );

      final snap = await firestore.collection('waitlist').get();
      expect(
        snap.docs.length,
        1,
        reason: 'a re-join must never create a second waitlist doc',
      );

      await _drainSnackbar(tester);
    });

    testWidgets(
      'fail-closed: a signed-out user cannot join (no fake success)',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        await tester.pumpWidget(await _harness(firestore, userId: null));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('Join Waitlist'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Signed-out -> _join throws -> the catch maps the raw exception
        // through FirebaseExceptionMapper (a non-Firebase error maps to the
        // generic user-safe message).
        expect(
          find.text('An unexpected error occurred. Please try again.'),
          findsOneWidget,
        );
        expect(
          (await firestore.collection('waitlist').get()).docs,
          isEmpty,
          reason: 'no uid -> no write, the join fails closed',
        );

        await _drainSnackbar(tester);
      },
    );
  });
}
