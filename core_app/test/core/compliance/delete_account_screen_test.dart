import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/features/compliance/presentation/delete_account_screen.dart';
import '../../helpers/app_localizations_test_helper.dart';

class _FakeLogger implements LoggerService {
  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {}

  @override
  Future<void> info(Map<String, dynamic> context, String message) async {}

  @override
  Future<void> warn(Object error, String message, {StackTrace? stack}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGdprService implements GdprService {
  final bool shouldSucceed;
  bool deleteMyDataCalled = false;

  _FakeGdprService({this.shouldSucceed = true});

  @override
  Future<bool> deleteMyData() async {
    deleteMyDataCalled = true;
    if (!shouldSucceed) {
      throw Exception('Data deletion failed');
    }
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingAuthRepository implements AuthRepository {
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// P6-03 / W9.11 behaviour suite for the customer account-deletion surface.
///
/// UI-13 (p21) phase G1 edit (deliberate, receipted): contract §3-G mandates that
/// the destructive action be CONFIRMED, so the action is now gated by the
/// library `BrandDialog`. The four behaviour tests below tap through that
/// confirmation exactly as a customer does. **No assertion was deleted,
/// weakened, renamed or skipped** — the same service-call, cleanup,
/// fail-closed and snackbar expectations are asserted after the confirm tap.
/// The confirmation itself (dialog keys, cancel, deliberate dismissible barrier)
/// is receipted in `test/features/compliance/presentation/p21_compliance_adoption_test.dart`.
///
/// [Helper] `_tapDeleteAndConfirm` performs: tap the screen action -> tap the
/// dialog's confirm label.
Future<void> _tapDeleteAndConfirm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
}

void main() {
  group('DeleteAccountScreen Behavior Tests', () {
    late _FakeLogger fakeLogger;
    late _RecordingAuthRepository fakeAuth;

    setUp(() {
      fakeLogger = _FakeLogger();
      fakeAuth = _RecordingAuthRepository();
    });

    List<Override> getOverrides(GdprService gdpr) => [
      gdprServiceProvider.overrideWithValue(gdpr),
      loggerProvider.overrideWithValue(fakeLogger),
      authRepositoryProvider.overrideWithValue(fakeAuth),
    ];

    testWidgets('Renders delete account warning and button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(_FakeGdprService()),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizationsTestHelper.delegates,
            supportedLocales: AppLocalizationsTestHelper.supportedLocales,
            home: DeleteAccountScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Delete My Account'), findsAtLeastNWidgets(1));
      expect(find.text('This action cannot be undone.'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
    });

    testWidgets('Tapping Delete Account triggers GdprService.deleteMyData', (
      tester,
    ) async {
      final fakeGdpr = _FakeGdprService(shouldSucceed: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(fakeGdpr),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizationsTestHelper.delegates,
            supportedLocales: AppLocalizationsTestHelper.supportedLocales,
            home: DeleteAccountScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteBtn = find.widgetWithText(ElevatedButton, 'Delete Account');
      expect(deleteBtn, findsOneWidget);

      await _tapDeleteAndConfirm(tester);

      expect(fakeGdpr.deleteMyDataCalled, isTrue);
    });

    testWidgets('Shows error SnackBar on GdprService exception', (
      tester,
    ) async {
      final fakeGdpr = _FakeGdprService(shouldSucceed: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(fakeGdpr),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizationsTestHelper.delegates,
            supportedLocales: AppLocalizationsTestHelper.supportedLocales,
            home: DeleteAccountScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteBtn = find.widgetWithText(ElevatedButton, 'Delete Account');
      expect(deleteBtn, findsOneWidget);
      await _tapDeleteAndConfirm(tester);

      expect(fakeGdpr.deleteMyDataCalled, isTrue);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets(
      'T-4: CF success completes the LOCAL cleanup (Isar+prefs+signOut chain)',
      (tester) async {
        final fakeGdpr = _FakeGdprService(shouldSucceed: true);

        await tester.pumpWidget(
          ProviderScope(
            overrides: getOverrides(fakeGdpr),
            child: const MaterialApp(
              localizationsDelegates: AppLocalizationsTestHelper.delegates,
              supportedLocales: AppLocalizationsTestHelper.supportedLocales,
              home: DeleteAccountScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await _tapDeleteAndConfirm(tester);

        expect(fakeGdpr.deleteMyDataCalled, isTrue);
        // W9.11 (06-P2-4): the production cleanup chain is
        // authRepository.signOut() — Isar clearAll + prefs + Firebase/Google
        // signOut. The screen MUST invoke it after the CF reports success.
        expect(fakeAuth.signOutCalls, 1);
      },
    );

    testWidgets(
      'T-4: CF failure does NOT trigger the local cleanup (fail-closed)',
      (tester) async {
        final fakeGdpr = _FakeGdprService(shouldSucceed: false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: getOverrides(fakeGdpr),
            child: const MaterialApp(
              localizationsDelegates: AppLocalizationsTestHelper.delegates,
              supportedLocales: AppLocalizationsTestHelper.supportedLocales,
              home: DeleteAccountScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await _tapDeleteAndConfirm(tester);

        expect(fakeGdpr.deleteMyDataCalled, isTrue);
        expect(fakeAuth.signOutCalls, 0);
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  });
}
