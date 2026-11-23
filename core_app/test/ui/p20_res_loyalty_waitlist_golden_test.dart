library;

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/loyalty/domain/loyalty_model.dart';
import 'package:labs/features/loyalty/presentation/loyalty_provider.dart';
import 'package:labs/features/loyalty/presentation/loyalty_screen.dart';
import 'package:labs/features/reservations/presentation/admin_reservations_tab.dart';
import 'package:labs/features/reservations/presentation/reservation_screen.dart';
import 'package:labs/features/waitlist/presentation/waitlist_screen.dart';
import 'package:labs/features/waitlist/data/waitlist_repository.dart';
import 'package:labs/l10n/app_localizations.dart';

Widget _pumpWithTheme(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('p20 admin reservations golden (D1 card + StatusTile)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    final firestore = FakeFirebaseFirestore();
    // FIXED far-future seat time: the card renders the booking's own date and
    // the derived seating tone, so the picture must not drift with the clock.
    await firestore.collection('reservations').add({
      'customerName': 'John Doe',
      'customerPhone': '+1234567890',
      'startTime': Timestamp.fromDate(DateTime(2030, 1, 1, 18, 30)),
      'partySize': 4,
      'notes': 'Window seat please',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) async => const UserModel(id: 'u-owner', role: UserRole.owner),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminReservationsTab(
            reservationsStream: firestore
                .collection('reservations')
                .snapshots(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/p20_admin_reservations.png'),
    );
  });

  testWidgets('p20 reservations golden', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _pumpWithTheme(
        ReservationScreen(initialStartTime: DateTime(2026, 10, 1, 18, 30)),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/p20_reservations.png'),
    );
  });

  testWidgets('p20 loyalty golden', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _pumpWithTheme(
        const LoyaltyScreen(),
        overrides: [
          authStateProvider.overrideWith(
            (ref) =>
                Stream.value(MockUser(uid: 'u-1', email: 'customer@test.com')),
          ),
          userLoyaltyProvider.overrideWith(
            (ref) =>
                Stream.value(const LoyaltyModel(totalPoints: 250, uid: 'u-1')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/p20_loyalty.png'),
    );
  });

  testWidgets('p20 waitlist golden', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    final firestore = FakeFirebaseFirestore();
    await firestore.collection('branches').doc('branch-1').set({
      'name': 'Downtown',
      'isActive': true,
      'isMainBranch': true,
    });

    await tester.pumpWidget(
      _pumpWithTheme(
        const WaitlistScreen(),
        overrides: [
          currentUserIdProvider.overrideWithValue('u-1'),
          firestoreProvider.overrideWithValue(firestore),
          loggerProvider.overrideWithValue(
            LoggerService(
              testDirectory: Directory.systemTemp.createTempSync(
                'carnama_logs_',
              ),
            ),
          ),
          waitlistPositionProvider((
            branchId: 'branch-1',
            userId: 'u-1',
          )).overrideWith((ref) => Stream.value(2)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/p20_waitlist.png'),
    );
  });
}
