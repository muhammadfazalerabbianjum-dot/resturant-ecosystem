// PERF-7 — reservation screen: validator boundaries, past-time reject,
// the B4-2 branch fail-closed chain, and the confirmed submit. Extension of
// reservation_screen_test.dart (new file keeps suites independent).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/core.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/reservations/data/reservations_repository.dart';
import 'package:labs/features/reservations/presentation/reservation_screen.dart';
import '../../helpers/test_helpers.dart';

Widget buildScreen(FakeFirebaseFirestore fs, {DateTime? initialStartTime}) {
  final repo = ReservationsRepository(
    fs,
    LoggerService(
      testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
    ),
  );
  return ProviderScope(
    overrides: [
      reservationsRepositoryProvider.overrideWithValue(repo),
      firestoreProvider.overrideWithValue(fs),
      // PERF-7: the REAL LoggerService is awaited by the screen's error paths
      // and `_writeLog` performs real file I/O. Inside a testWidgets FakeAsync
      // zone that future never completes, so the submit button's spinner
      // animates forever and `pumpAndSettle` times out (observed). The house
      // pattern (~14 suites) is this silent FakeLogger override.
      loggerProvider.overrideWithValue(FakeLogger()),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // NESTED routes (not two flat ones) so the success path's
      // `context.pop()` has a real page to return to — a flat
      // `initialLocation: '/reserve'` stack has nothing to pop, and the
      // post-confirm `find.text('Home')` assertion could never pass.
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

Future<void> fillAndSubmit(WidgetTester tester, {String party = '4'}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Guest');
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Phone'),
    '555-1234',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Party size'),
    party,
  );
  await tester.tap(find.text('New Reservation'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    // BranchService persists the selected branch in SharedPreferences; the
    // real CurrentBranchNotifier._init reads it during screen pump.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('party size outside 1-20 shows the range error', (tester) async {
    final fs = FakeFirebaseFirestore();
    await tester.pumpWidget(
      buildScreen(
        fs,
        initialStartTime: DateTime.now().add(const Duration(hours: 2)),
      ),
    );
    await tester.pumpAndSettle();

    await fillAndSubmit(tester, party: '21');
    expect(find.text('Party size must be 1-20'), findsOneWidget);

    await fillAndSubmit(tester, party: '0');
    expect(find.text('Party size must be 1-20'), findsOneWidget);
  });

  testWidgets('a past time is rejected before any write', (tester) async {
    final fs = FakeFirebaseFirestore();
    await tester.pumpWidget(
      buildScreen(
        fs,
        initialStartTime: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    );
    await tester.pumpAndSettle();

    await fillAndSubmit(tester);
    expect(find.text('Please select a future date and time.'), findsOneWidget);
    final snap = await fs.collection('reservations').get();
    expect(
      snap.docs,
      isEmpty,
      reason: 'a rejected submit must never write a reservation doc',
    );
  });

  testWidgets('no resolvable branch fails closed (B4-2)', (tester) async {
    // The bundled configs declare an EMPTY defaultBranchId and the fake has
    // NO branches docs, so CurrentBranchNotifier stays null and the
    // resolution chain must end in the fail-closed copy — never a write
    // under a made-up branch id.
    await AppConfig.loadConfig();
    final fs = FakeFirebaseFirestore();
    await tester.pumpWidget(
      buildScreen(
        fs,
        initialStartTime: DateTime.now().add(const Duration(hours: 2)),
      ),
    );
    await tester.pumpAndSettle();

    await fillAndSubmit(tester);
    expect(
      find.text('Please select a branch before making a reservation.'),
      findsOneWidget,
    );
    final snap = await fs.collection('reservations').get();
    expect(snap.docs, isEmpty);
  });

  testWidgets('a valid submit writes the reservation and confirms', (
    tester,
  ) async {
    final fs = FakeFirebaseFirestore();
    // Seed the main branch: CurrentBranchNotifier resolves it (isMainBranch)
    // and _resolveBranchCapacity reads the same doc for capacity.
    await fs.collection('branches').doc('branch-1').set({
      'isMainBranch': true,
      'capacity': 50,
    });
    await tester.pumpWidget(
      buildScreen(
        fs,
        initialStartTime: DateTime.now().add(const Duration(hours: 2)),
      ),
    );
    await tester.pumpAndSettle();

    // Warm the async branch notifier: _resolveBranchId reads it
    // SYNCHRONOUSLY at submit time; a cold read would race _init and
    // fail-closed even with a valid main branch seeded (real users take
    // seconds to fill the form — the test must pump until init lands).
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

    await fillAndSubmit(tester);
    expect(find.text('Reservation confirmed!'), findsOneWidget);

    final docs = await fs.collection('reservations').get();
    expect(docs.docs, hasLength(1));
    expect(docs.docs.first.data()['partySize'], 4);
    expect(docs.docs.first.data()['branchId'], 'branch-1');

    // requestSlot success pops back via context.pop (go_router).
    expect(find.text('Home'), findsOneWidget);
  });
}
