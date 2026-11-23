// UI-10 (p20) Phase D — reservations adoption: booking cards → BrandCard +
// StatusTile, loading → L12 tile skeletons, form → BrandCard + SectionHeader.
// Written RED before the wiring (p20 §3 phase D).
//
// L16 SANCTUARY: this file asserts PRESENTATION only. The reservations stream,
// the seat/lock transaction and the repository seams are untouched — the
// repository/perf suites stay the sanctuary guards.
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/reservations/presentation/admin_reservations_tab.dart';
import 'package:labs/features/reservations/presentation/reservation_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

/// Owner-scoped host, mirroring the legacy tab suite (RoleGate needs a role).
Widget _tab(Stream<QuerySnapshot<Map<String, dynamic>>>? stream) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith(
        (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminReservationsTab(reservationsStream: stream),
    ),
  );
}

Widget _form() {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('u1'),
      loggerProvider.overrideWithValue(
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReservationScreen(
        initialStartTime: DateTime.now().add(const Duration(hours: 3)),
      ),
    ),
  );
}

/// Seeds one upcoming booking and returns the real (fake-Firestore) stream the
/// tab renders — the same query shape the production provider uses.
Future<Stream<QuerySnapshot<Map<String, dynamic>>>> _seededStream(
  FakeFirebaseFirestore fs, {
  String customerName = 'John Doe',
  String customerPhone = '+1234567890',
  int partySize = 4,
  String? notes = 'Window seat please',
  Duration fromNow = const Duration(hours: 2),
}) async {
  await fs.collection('reservations').add({
    'customerName': customerName,
    'customerPhone': customerPhone,
    'startTime': Timestamp.fromDate(DateTime.now().add(fromNow)),
    'partySize': partySize,
    if (notes != null) 'notes': notes,
  });
  return fs
      .collection('reservations')
      .orderBy('startTime', descending: false)
      .snapshots();
}

void main() {
  group('p20 D — seating status mapping (pure)', () {
    final now = DateTime(2026, 9, 27, 18, 0);

    test('reservationStatusFor is total over the seating window', () {
      expect(
        reservationStatusFor(
          now.subtract(const Duration(minutes: 5)),
          now: now,
        ),
        TileStatus.failed,
        reason: 'a booking whose seat time has passed is flagged',
      );
      expect(reservationStatusFor(now, now: now), TileStatus.pending);
      expect(
        reservationStatusFor(now.add(const Duration(minutes: 30)), now: now),
        TileStatus.pending,
        reason: 'the guest is arriving (within the half-hour window)',
      );
      expect(
        reservationStatusFor(now.add(const Duration(minutes: 31)), now: now),
        TileStatus.ok,
      );
      expect(
        reservationStatusFor(now.add(const Duration(hours: 5)), now: now),
        TileStatus.ok,
      );
    });

    test('the StatusTile tone table stays the frozen tri-state mapping', () {
      expect(StatusTile.toneFor(TileStatus.failed), BadgeTone.negative);
      expect(StatusTile.toneFor(TileStatus.pending), BadgeTone.neutral);
      expect(StatusTile.toneFor(TileStatus.ok), BadgeTone.positive);
    });
  });

  group('p20 D — admin reservations tab adoption', () {
    testWidgets('D1: each booking is a BrandCard carrying a StatusTile badge', (
      tester,
    ) async {
      final fs = FakeFirebaseFirestore();
      final stream = await _seededStream(fs);

      await tester.pumpWidget(_tab(stream));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The booking's own details survive the restyle (L14 parity of copy).
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.textContaining('4 guests'), findsOneWidget);
      expect(find.textContaining('Window seat please'), findsOneWidget);

      expect(find.byType(BrandCard), findsAtLeastNWidgets(1));
      final tile = tester.widget<StatusTile>(find.byType(StatusTile));
      expect(
        tile.status,
        TileStatus.ok,
        reason: 'a booking 2h out is comfortably ahead',
      );
      expect(find.byType(BrandBadge), findsAtLeastNWidgets(1));
      expect(
        find.byType(Card),
        findsNothing,
        reason: 'the legacy Material Card is replaced by the token card',
      );
    });

    testWidgets('D2: the loading state renders tile skeletons, not a spinner', (
      tester,
    ) async {
      final controller =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      await tester.pumpWidget(_tab(controller.stream));
      await tester.pump();

      expect(find.byType(SkeletonLoader), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Shimmer repeats forever — unmount so no ticker outlives the test.
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.close();
    });

    testWidgets('D2: the empty state keeps its localized icon + message', (
      tester,
    ) async {
      final fs = FakeFirebaseFirestore();
      await tester.pumpWidget(_tab(fs.collection('reservations').snapshots()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('No upcoming reservations.'), findsOneWidget);
      expect(find.byIcon(Icons.table_restaurant), findsOneWidget);
      expect(find.byType(SkeletonLoader), findsNothing);
    });

    testWidgets('the call action keeps a >= 48dp tap target (L12.5)', (
      tester,
    ) async {
      final fs = FakeFirebaseFirestore();
      final stream = await _seededStream(fs);

      await tester.pumpWidget(_tab(stream));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final callButton = find.ancestor(
        of: find.byIcon(Icons.phone),
        matching: find.byType(IconButton),
      );
      expect(callButton, findsOneWidget);
      final size = tester.getSize(callButton);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('p20 D — reservation form adoption', () {
    testWidgets('the form is a BrandCard under a SectionHeader title', (
      tester,
    ) async {
      await tester.pumpWidget(_form());
      await tester.pumpAndSettle();

      expect(find.byType(BrandCard), findsOneWidget);
      expect(find.byType(SectionHeader), findsAtLeastNWidgets(1));
      expect(
        find.byType(Card),
        findsNothing,
        reason: 'the legacy Material Card is replaced by the token card',
      );

      // The form contract itself is unchanged (L14): the three fields, their
      // localized labels and the single submit button all survive.
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Party size'), findsOneWidget);
      expect(find.text('New Reservation'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}
