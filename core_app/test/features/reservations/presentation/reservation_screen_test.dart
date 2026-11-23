import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:labs/features/reservations/data/reservations_repository.dart';
import 'package:labs/features/reservations/presentation/reservation_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';

Widget _buildScreen() {
  return ProviderScope(
    overrides: [
      tenantClaimProvider.overrideWithValue(_FixedTenantClaim()),
      reservationsRepositoryProvider.overrideWithValue(
        ReservationsRepository(
          FakeFirebaseFirestore(),
          LoggerService(
            testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
          ),
        ),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReservationScreen(),
    ),
  );
}

void main() {
  group('ReservationScreen Widget Tests', () {
    testWidgets('1. Shows reservations title in app bar', (tester) async {
      await tester.pumpWidget(_buildScreen());

      await tester.pump();
      await tester.pump();

      expect(find.text('Reservations'), findsAtLeastNWidgets(1));
    });

    testWidgets('2. Shows reservation form fields', (tester) async {
      await tester.pumpWidget(_buildScreen());

      await tester.pump();
      await tester.pump();

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Party size'), findsOneWidget);
    });

    testWidgets('3. Shows new reservation button', (tester) async {
      await tester.pumpWidget(_buildScreen());

      await tester.pump();
      await tester.pump();

      expect(find.text('New Reservation'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('4. New reservation button is tappable', (tester) async {
      await tester.pumpWidget(_buildScreen());

      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('New Reservation'));
      await tester.pump();

      // Should not throw; validation errors show because fields are empty
      expect(find.text('New Reservation'), findsOneWidget);
    });

    testWidgets('5. Renders without crashing', (tester) async {
      await tester.pumpWidget(_buildScreen());

      await tester.pump();
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
