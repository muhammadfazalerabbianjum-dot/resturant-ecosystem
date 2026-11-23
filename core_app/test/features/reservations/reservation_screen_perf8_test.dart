// PERF-8 (W3) — reservation submit concurrency fence + last-seat clamp.
// Companion to reservation_screen_perf7_test.dart (new file keeps suites
// independent). Pins that a double-tap — and the keyboard done-action, which
// bypasses the disabled button entirely — cannot start a SECOND requestSlot
// while a submit is in flight, and that a FULL slot (real transaction via
// FakeFirebaseFirestore) is refused with zero reservation writes.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/core.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/reservations/data/reservations_repository.dart';
import 'package:labs/features/reservations/domain/reservation_model.dart';
import 'package:labs/features/reservations/presentation/reservation_screen.dart';
import '../../helpers/test_helpers.dart';

/// A counting [ReservationsRepository] whose requestSlot can be suspended on
/// a gate — the harness for driving concurrent submits at the screen level.
class _GatedReservationsRepository implements ReservationsRepository {
  int requestSlotCalls = 0;
  Completer<void>? gate;
  bool nextResult = true;

  @override
  Future<bool> requestSlot(
    ReservationModel reservation,
    int branchCapacity, {
    required String tenantId,
  }) async {
    requestSlotCalls++;
    if (gate != null) await gate!.future;
    return nextResult;
  }

  @override
  Future<int> getAvailableCapacity(
    String branchId,
    DateTime startTime,
    int branchCapacity,
  ) async => branchCapacity;

  @override
  Future<bool> cancelReservation(String reservationId) async => false;
}

Widget buildScreen(
  FakeFirebaseFirestore fs, {
  ReservationsRepository? repo,
  DateTime? initialStartTime,
}) {
  final effectiveRepo =
      repo ??
      ReservationsRepository(
        fs,
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );
  return ProviderScope(
    overrides: [
      reservationsRepositoryProvider.overrideWithValue(effectiveRepo),
      firestoreProvider.overrideWithValue(fs),
      // The REAL LoggerService performs file I/O that never completes inside
      // a testWidgets FakeAsync zone (the PERF-7 W3 lesson) — silent double.
      loggerProvider.overrideWithValue(FakeLogger()),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // NESTED routes so the success path's context.pop() has a page to
      // return to (the perf7 harness lesson).
      routerConfig: GoRouter(
        initialLocation: '/reserve',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
            routes: [
              GoRoute(
                path: 'reserve',
                builder: (context, state) =>
                    ReservationScreen(initialStartTime: initialStartTime),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Warms the async branch notifier: _resolveBranchId reads it SYNCHRONOUSLY
/// at submit time; a cold read would fail-closed even with a valid main
/// branch seeded (PERF-7 lesson).
Future<void> warmBranchSelection(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold)),
  );
  for (
    var i = 0;
    i < 20 && container.read(currentBranchIdProvider) == null;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> fillForm(WidgetTester tester, {String party = '4'}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Guest');
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Phone'),
    '555-1234',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Party size'),
    party,
  );
}

void main() {
  setUpAll(() {
    // BranchService persists the selected branch in SharedPreferences; the
    // real CurrentBranchNotifier._init reads it during screen pump.
    SharedPreferences.setMockInitialValues({});
  });

  group('ReservationScreen - submit re-entrancy fence (P8 W3)', () {
    testWidgets(
      'a double-tap while a submit is in flight fires requestSlot exactly '
      'once',
      (tester) async {
        final fs = FakeFirebaseFirestore();
        await fs.collection('branches').doc('branch-1').set({
          'isMainBranch': true,
          'capacity': 50,
        });
        final repo = _GatedReservationsRepository();
        await tester.pumpWidget(
          buildScreen(
            fs,
            repo: repo,
            initialStartTime: DateTime.now().add(const Duration(hours: 2)),
          ),
        );
        await tester.pumpAndSettle();
        await warmBranchSelection(tester);
        await fillForm(tester);

        // Two invocations in the SAME event-loop turn — exactly what a real
        // double-tap does before a frame can rebuild and disable the button.
        // (Two raw tester.tap calls without an await trip the test-async
        // guard, so the race is driven through the button's real handler.)
        final submitButton = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('New Reservation'),
            matching: find.byType(ElevatedButton),
          ),
        );
        submitButton.onPressed!();
        submitButton.onPressed!();
        await tester.pump();

        expect(
          repo.requestSlotCalls,
          1,
          reason:
              'the submit fence must absorb a same-frame double-tap — two '
              'requestSlot calls can only mean two concurrent submits',
        );
        await tester.pumpAndSettle();
        expect(find.text('Reservation confirmed!'), findsOneWidget);
        expect(
          repo.requestSlotCalls,
          1,
          reason: 'still exactly one submit after the flow settles',
        );
      },
    );

    testWidgets(
      'the keyboard done-action cannot re-submit while a submit is in '
      'flight',
      (tester) async {
        final fs = FakeFirebaseFirestore();
        await fs.collection('branches').doc('branch-1').set({
          'isMainBranch': true,
          'capacity': 50,
        });
        final repo = _GatedReservationsRepository();
        await tester.pumpWidget(
          buildScreen(
            fs,
            repo: repo,
            initialStartTime: DateTime.now().add(const Duration(hours: 2)),
          ),
        );
        await tester.pumpAndSettle();
        await warmBranchSelection(tester);
        await fillForm(tester);

        // Submit from the BUTTON: requestSlot is now in flight (suspended
        // on the gate) and the button is disabled by the spinner state.
        repo.gate = Completer<void>();
        await tester.tap(find.text('New Reservation'));
        await tester.pump();
        expect(repo.requestSlotCalls, 1);

        // The party-size field's onFieldSubmitted calls _submit() DIRECTLY,
        // bypassing the disabled button. The re-entrancy fence must cover
        // this path too.
        await tester.showKeyboard(
          find.widgetWithText(TextFormField, 'Party size'),
        );
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(
          repo.requestSlotCalls,
          1,
          reason:
              'the done-key path must be fenced exactly like the button — '
              'the disabled button alone cannot stop it',
        );
        repo.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.text('Reservation confirmed!'), findsOneWidget);
        expect(repo.requestSlotCalls, 1);
      },
    );
  });

  group('ReservationScreen - last-seat clamp (P8 W3 race)', () {
    testWidgets('a FULL slot is refused with zero reservation writes (real '
        'transaction)', (tester) async {
      final start = DateTime.now().add(const Duration(hours: 2));
      final fs = FakeFirebaseFirestore();
      await fs.collection('branches').doc('branch-1').set({
        'isMainBranch': true,
        'capacity': 50,
      });
      // The (branchId, startTime) counter is ALREADY at capacity: the
      // last seat is taken. The transaction must clamp — this is the
      // zero-overbook property, driven through the REAL repository.
      final counterId = 'branch-1_${start.millisecondsSinceEpoch}';
      await fs.collection('reservation_counters').doc(counterId).set({
        'booked': 50,
      });
      await tester.pumpWidget(buildScreen(fs, initialStartTime: start));
      await tester.pumpAndSettle();
      await warmBranchSelection(tester);
      await fillForm(tester);

      await tester.tap(find.text('New Reservation'));
      await tester.pumpAndSettle();

      expect(find.text('No capacity available for this time.'), findsOneWidget);
      final reservations = await fs.collection('reservations').get();
      expect(
        reservations.docs,
        isEmpty,
        reason: 'a full slot must never produce a reservation write',
      );
      final counter = await fs
          .collection('reservation_counters')
          .doc(counterId)
          .get();
      expect(
        counter.data()?['booked'],
        50,
        reason: 'the refused submit must not increment the counter',
      );
    });
  });
}
