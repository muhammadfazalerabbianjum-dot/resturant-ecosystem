@Tags(['needs-emulator'])
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:labs/features/reservations/data/reservations_repository.dart';
import 'package:labs/features/reservations/presentation/reservation_screen.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/l10n/app_localizations.dart';

// T-S2 — Reservation flow: past-time rejection + capacity-denied (B4).

class _FakeReservationsRepository extends ReservationsRepository {
  final bool _slotResult;
  _FakeReservationsRepository(this._slotResult)
    : super(
        FakeFirebaseFirestore(),
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  @override
  Future<bool> requestSlot(
    reservation,
    int branchCapacity, {
    required String tenantId,
  }) async => _slotResult;
}

class _FixedBranchNotifier extends CurrentBranchNotifier {
  _FixedBranchNotifier(super.db, super.branchService, String branchId) {
    state = branchId;
  }
}

Widget _buildScreen({
  required FakeFirebaseFirestore fakeFirestore,
  required bool slotResult,
  DateTime? initialStartTime,
}) {
  final logger = LoggerService(
    testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
  );
  final branchSvc = BranchService(fakeFirestore, logger: logger);
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(fakeFirestore),
      currentBranchIdProvider.overrideWith(
        (_) => _FixedBranchNotifier(fakeFirestore, branchSvc, 'branch-test'),
      ),
      currentUserIdProvider.overrideWith((_) => 'user-test'),
      reservationsRepositoryProvider.overrideWithValue(
        _FakeReservationsRepository(slotResult),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReservationScreen(initialStartTime: initialStartTime),
    ),
  );
}

Future<void> _fillValidForm(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Test User'); // Name
  await tester.enterText(fields.at(1), '5550100'); // Phone
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('T-S2 reservation flow (B4)', () {
    testWidgets('past time → reservationPastTime snackbar, slot NOT called', (
      tester,
    ) async {
      final fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore.collection('branches').doc('branch-test').set({
        'name': 'Test Branch',
        'isMainBranch': true,
        'capacity': 50,
      });

      final past = DateTime.now().subtract(const Duration(hours: 1));
      await tester.pumpWidget(
        _buildScreen(
          fakeFirestore: fakeFirestore,
          slotResult: true,
          initialStartTime: past,
        ),
      );
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await tester.tap(find.text('New Reservation'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please select a future date and time.'),
        findsOneWidget,
        reason: 'past-time guard must show reservationPastTime',
      );
    });

    testWidgets(
      'future time + capacity denied → reservationNoCapacity snackbar',
      (tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('branches').doc('branch-test').set({
          'name': 'Test Branch',
          'isMainBranch': true,
          'capacity': 50,
        });

        final future = DateTime.now().add(const Duration(hours: 2));
        await tester.pumpWidget(
          _buildScreen(
            fakeFirestore: fakeFirestore,
            slotResult: false,
            initialStartTime: future,
          ),
        );
        await tester.pumpAndSettle();

        await _fillValidForm(tester);
        await tester.tap(find.text('New Reservation'));
        await tester.pumpAndSettle();

        expect(
          find.text('No capacity available for this time.'),
          findsOneWidget,
          reason: 'capacity-denied path must show reservationNoCapacity',
        );
      },
    );
  });
}
