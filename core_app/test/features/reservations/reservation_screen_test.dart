import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:labs/features/reservations/data/reservations_repository.dart';
import 'package:labs/features/reservations/presentation/reservation_screen.dart';
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
  group('ReservationScreen Regression (TC3)', () {
    testWidgets(
      'mounted-guard catches async setState after disposal gracefully',
      (WidgetTester tester) async {
        final ValueNotifier<bool> showScreen = ValueNotifier(true);

        // 1. Conditionally push the screen so we can unmount it
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ValueListenableBuilder<bool>(
              valueListenable: showScreen,
              builder: (ctx, show, child) {
                return show
                    ? _buildScreen()
                    : const Scaffold(body: Text('Unmounted'));
              },
            ),
          ),
        );

        // Verify the Reservation Screen natively renders
        expect(find.byType(ReservationScreen), findsOneWidget);

        // 2. Verify the screen renders with its core widgets
        // 'Reservations' appears in both AppBar and body text
        expect(find.text('Reservations'), findsNWidgets(2));
        expect(find.text('Name'), findsOneWidget);
        expect(find.text('New Reservation'), findsOneWidget);

        // 3. Destructively unmount the widget
        showScreen.value = false;
        await tester.pump(); // This forces ReservationScreen to run dispose()

        // Verify it was purged
        expect(find.byType(ReservationScreen), findsNothing);

        // No crash = mounted-guard works
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
