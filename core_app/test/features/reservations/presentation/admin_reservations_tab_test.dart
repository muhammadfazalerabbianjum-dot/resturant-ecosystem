import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/features/reservations/presentation/admin_reservations_tab.dart';
import 'package:labs/l10n/app_localizations.dart';

Widget _buildTab(Stream<QuerySnapshot<Map<String, dynamic>>>? stream) {
  return ProviderScope(
    overrides: [
      // W2.9: AdminReservationsTab is owner/manager-gated — authorize.
      currentUserProvider.overrideWith(
        (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminReservationsTab(reservationsStream: stream),
    ),
  );
}

void main() {
  group('AdminReservationsTab', () {
    testWidgets('shows loading indicator initially', (tester) async {
      // Create a stream that never completes to test loading state
      final controller =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      await tester.pumpWidget(_buildTab(controller.stream));

      // E1 F3-09: the RoleGate loading branch renders the library skeleton.
      expect(find.byType(SkeletonLoader), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await controller.close();
    });

    testWidgets('shows empty state when no reservations', (tester) async {
      final fakeFirestore = FakeFirebaseFirestore();
      final stream = fakeFirestore.collection('reservations').snapshots();

      await tester.pumpWidget(_buildTab(stream));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show localized empty state
      expect(find.text('No upcoming reservations.'), findsOneWidget);
      expect(find.byIcon(Icons.table_restaurant), findsOneWidget);
    });

    testWidgets('shows error state when stream has error', (tester) async {
      final errorStream = Stream<QuerySnapshot<Map<String, dynamic>>>.error(
        Exception('Test error'),
      );

      await tester.pumpWidget(_buildTab(errorStream));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show error message
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('shows reservation list when data is available', (
      tester,
    ) async {
      final fakeFirestore = FakeFirebaseFirestore();
      final futureTime = DateTime.now().add(const Duration(hours: 2));
      await fakeFirestore.collection('reservations').add({
        'customerName': 'John Doe',
        'customerPhone': '+1234567890',
        'startTime': Timestamp.fromDate(futureTime),
        'partySize': 4,
        'notes': 'Window seat please',
      });

      final stream = fakeFirestore
          .collection('reservations')
          .orderBy('startTime', descending: false)
          .snapshots();

      await tester.pumpWidget(_buildTab(stream));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show reservation details
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.textContaining('4 guests'), findsOneWidget);
      expect(find.textContaining('Window seat please'), findsOneWidget);
    });

    testWidgets('shows call button when phone is available', (tester) async {
      final fakeFirestore = FakeFirebaseFirestore();
      final futureTime = DateTime.now()
          .add(const Duration(hours: 3))
          .toIso8601String();
      await fakeFirestore.collection('reservations').add({
        'customerName': 'Jane Smith',
        'customerPhone': '+9876543210',
        'startTime': futureTime,
        'partySize': 2,
      });

      final stream = fakeFirestore
          .collection('reservations')
          .orderBy('startTime', descending: false)
          .snapshots();

      await tester.pumpWidget(_buildTab(stream));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show phone icon button
      expect(find.byIcon(Icons.phone), findsOneWidget);
    });

    testWidgets('hides call button when phone is empty', (tester) async {
      final fakeFirestore = FakeFirebaseFirestore();
      final futureTime = DateTime.now()
          .add(const Duration(hours: 3))
          .toIso8601String();
      await fakeFirestore.collection('reservations').add({
        'customerName': 'No Phone',
        'customerPhone': '',
        'startTime': futureTime,
        'partySize': 2,
      });

      final stream = fakeFirestore
          .collection('reservations')
          .orderBy('startTime', descending: false)
          .snapshots();

      await tester.pumpWidget(_buildTab(stream));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should NOT show phone icon button
      expect(find.byIcon(Icons.phone), findsNothing);
    });
  });
}
