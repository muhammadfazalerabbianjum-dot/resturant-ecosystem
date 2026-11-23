// UI-13 (p21) phase G adoption receipts — M-6 compliance (contract §3-G).
//
// Every expectation below is RED against the pre-adoption screens and GREEN
// after the library composition lands:
//  G1 `delete_account_screen.dart` -> brand shell (SectionHeader / InfoBanner /
//      BrandButton) carrying the GDPR wording VERBATIM, plus the destructive
//      confirmation rendered by the library `BrandDialog`; the raw
//      `CircularProgressIndicator` inside the old button is gone.
//  G2 `privacy_policy_screen.dart` -> readable brand typography
//      (SectionHeader + BrandCard + BrandButton), wording verbatim.
//
// The two pre-existing behaviour suites keep every assertion they had: the only
// edit made to them is that the destructive path now routes through the
// confirmation step the contract mandates (tap -> dialog -> confirm). No
// assertion was deleted, weakened or skipped.
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/admin/presentation/privacy_policy_screen.dart';
import 'package:labs/features/compliance/presentation/delete_account_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/l10n/app_localizations_ar.dart';

/// The pre-existing compliance suite's fakes are private to its file; these are
/// the same shapes, declared here so this receipt never edits that suite's
/// helpers.
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

class _RecordingGdprService implements GdprService {
  _RecordingGdprService({this.shouldSucceed = true});

  final bool shouldSucceed;
  int deleteMyDataCalls = 0;

  @override
  Future<bool> deleteMyData() async {
    deleteMyDataCalls++;
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
  Future<void> signOut() async => signOutCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `/login` is registered so the local-cleanup chain's `context.go('/login')`
/// really navigates instead of throwing inside the screen's own try/catch.
GoRouter _deleteAccountRouter() => GoRouter(
  initialLocation: '/delete-account',
  routes: <RouteBase>[
    GoRoute(
      path: '/delete-account',
      builder: (_, __) => const DeleteAccountScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (_, __) => const Scaffold(body: Text('SignInSurface')),
    ),
  ],
);

Future<void> _pumpDeleteScreen(
  WidgetTester tester, {
  required _RecordingGdprService gdpr,
  required _RecordingAuthRepository auth,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        gdprServiceProvider.overrideWithValue(gdpr),
        loggerProvider.overrideWithValue(_FakeLogger()),
        authRepositoryProvider.overrideWithValue(auth),
      ],
      child: MaterialApp.router(
        routerConfig: _deleteAccountRouter(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the destructive confirmation by tapping the screen's own action.
Future<void> _openConfirmation(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
  await tester.pumpAndSettle();
}

Future<void> _pumpPrivacyScreen(
  WidgetTester tester, {
  String? privacyUrl,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        restaurantConfigProvider.overrideWith(
          (ref) => Stream<RestaurantConfigModel>.value(
            RestaurantConfigModel(privacyUrl: privacyUrl),
          ),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PrivacyPolicyScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('G1 delete_account_screen — brand shell, GDPR wording verbatim', () {
    testWidgets('composes the library shell and drops the raw spinner', (
      tester,
    ) async {
      await _pumpDeleteScreen(
        tester,
        gdpr: _RecordingGdprService(),
        auth: _RecordingAuthRepository(),
      );

      expect(find.byType(SectionHeader), findsOneWidget);
      expect(find.byType(InfoBanner), findsOneWidget);
      expect(find.byType(BrandButton), findsOneWidget);
      // F3-09 (customer side): the hand-rolled button spinner is gone.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('keeps the GDPR wording verbatim (en)', (tester) async {
      await _pumpDeleteScreen(
        tester,
        gdpr: _RecordingGdprService(),
        auth: _RecordingAuthRepository(),
      );

      expect(find.text('Delete My Account'), findsAtLeastNWidgets(1));
      expect(find.text('This action cannot be undone.'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
    });

    testWidgets('keeps the GDPR wording verbatim (ar)', (tester) async {
      await _pumpDeleteScreen(
        tester,
        gdpr: _RecordingGdprService(),
        auth: _RecordingAuthRepository(),
        locale: const Locale('ar'),
      );
      final ar = AppLocalizationsAr();

      expect(find.text(ar.deleteMyAccount), findsAtLeastNWidgets(1));
      expect(find.text(ar.cannotBeUndone), findsOneWidget);
      expect(find.text(ar.deleteAccount), findsOneWidget);
    });

    testWidgets('the destructive confirmation is the library BrandDialog', (
      tester,
    ) async {
      final gdpr = _RecordingGdprService();
      await _pumpDeleteScreen(
        tester,
        gdpr: gdpr,
        auth: _RecordingAuthRepository(),
      );

      await _openConfirmation(tester);

      expect(find.byType(BrandDialog), findsOneWidget);
      expect(find.text('Confirm Account Deletion'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      // Nothing is erased before the customer confirms.
      expect(gdpr.deleteMyDataCalls, 0);
    });

    testWidgets('cancelling the confirmation erases nothing', (tester) async {
      final gdpr = _RecordingGdprService();
      final auth = _RecordingAuthRepository();
      await _pumpDeleteScreen(tester, gdpr: gdpr, auth: auth);

      await _openConfirmation(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(BrandDialog), findsNothing);
      expect(gdpr.deleteMyDataCalls, 0);
      expect(auth.signOutCalls, 0);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('the barrier is dismissible (deliberate non-money choice)', (
      tester,
    ) async {
      final gdpr = _RecordingGdprService();
      final auth = _RecordingAuthRepository();
      await _pumpDeleteScreen(tester, gdpr: gdpr, auth: auth);

      await _openConfirmation(tester);
      // G1: `moneyConfirming: false` in the contract's vocabulary — the
      // library's expression of that opt-out is `barrierDismissible: true`.
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(find.byType(BrandDialog), findsNothing);
      expect(gdpr.deleteMyDataCalls, 0);
      expect(auth.signOutCalls, 0);
    });

    testWidgets('confirming erases the account and completes the cleanup', (
      tester,
    ) async {
      final gdpr = _RecordingGdprService();
      final auth = _RecordingAuthRepository();
      await _pumpDeleteScreen(tester, gdpr: gdpr, auth: auth);

      await _openConfirmation(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(gdpr.deleteMyDataCalls, 1);
      // W9.11: the local cleanup chain still runs after a CF success.
      expect(auth.signOutCalls, 1);
      // The pre-existing navigation contract is unchanged.
      expect(find.text('SignInSurface'), findsOneWidget);
    });

    testWidgets('a failing erasure surfaces the snackbar, skips the cleanup', (
      tester,
    ) async {
      final gdpr = _RecordingGdprService(shouldSucceed: false);
      final auth = _RecordingAuthRepository();
      await _pumpDeleteScreen(tester, gdpr: gdpr, auth: auth);

      await _openConfirmation(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(gdpr.deleteMyDataCalls, 1);
      expect(auth.signOutCalls, 0);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
    });
  });

  group('G2 privacy_policy_screen — readable brand typography', () {
    testWidgets('composes SectionHeader + BrandCard + BrandButton', (
      tester,
    ) async {
      await _pumpPrivacyScreen(tester);

      expect(find.byType(SectionHeader), findsOneWidget);
      expect(find.byType(BrandCard), findsOneWidget);
      // The Back action is the only action without a configured policy URL.
      expect(find.byType(BrandButton), findsOneWidget);
      // The description lives on the token-driven card surface, not on a bare
      // centred Column.
      expect(
        find.descendant(
          of: find.byType(BrandCard),
          matching: find.text(
            'Please review our privacy policy to understand how we handle '
            'your data.',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('keeps the wording verbatim (en)', (tester) async {
      await _pumpPrivacyScreen(tester);

      expect(find.text('Privacy Policy'), findsAtLeastNWidgets(1));
      expect(
        find.text(
          'Please review our privacy policy to understand how we handle your '
          'data.',
        ),
        findsOneWidget,
      );
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('keeps the wording verbatim (ar)', (tester) async {
      await _pumpPrivacyScreen(tester, locale: const Locale('ar'));
      final ar = AppLocalizationsAr();

      expect(find.text(ar.privacyPolicyTitle), findsAtLeastNWidgets(1));
      expect(find.text(ar.privacyDescription), findsOneWidget);
      expect(find.text(ar.back), findsOneWidget);
    });

    testWidgets('hides the policy CTA when no URL is configured', (
      tester,
    ) async {
      await _pumpPrivacyScreen(tester);

      // Pre-existing behaviour, unchanged: no URL => no CTA.
      expect(find.text('View Privacy Policy'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a configured-but-unlaunchable URL surfaces the snackbar', (
      tester,
    ) async {
      // A scheme-less value never reaches url_launcher: the screen reports the
      // existing `privacyUnavailable` copy instead (hermetic — no platform
      // channel is touched).
      await _pumpPrivacyScreen(tester, privacyUrl: 'privacy');

      final cta = find.widgetWithText(ElevatedButton, 'View Privacy Policy');
      expect(cta, findsOneWidget);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      // `privacyUnavailable`, byte-identical to the ARB value.
      expect(
        find.text(
          'Privacy policy is currently unavailable. Please try again later.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('preserves the Back action', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            restaurantConfigProvider.overrideWith(
              (ref) => Stream<RestaurantConfigModel>.value(
                const RestaurantConfigModel(),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  ),
                  child: const Text('open-privacy'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open-privacy'));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyPolicyScreen), findsNothing);
      expect(find.text('open-privacy'), findsOneWidget);
    });
  });
}
