// UI-13 (p21) phase G golden pair — M-6 compliance (contract §3-G), light + dark.
//
// Deliberate-first protocol (L12.6): the BEFORE baselines are captured with
// `--update-goldens` while the PRE-ADOPTION screens are in place (throwaway
// worktree at `8e99da5`, this file copied in verbatim) and archived to
// `tool_uilib/p21/visual_review/p21_{delete_account,privacy_policy}_{light,dark}_before.png`
// with their SHA-256 recorded in `p21_report.md`; after the adoption the plain
// run must FAIL against those baselines before the declared re-capture writes
// the committed AFTER pair (`test/golden/snapshots/p21_*.png`).
//
// Light + dark is the chosen variant here: the compliance change is a brand
// shell / typography change (G1/G2), while the en+ar wording parity that the
// contract actually guards is asserted textually in
// `test/features/compliance/presentation/p21_compliance_adoption_test.dart`.
import 'package:core/core.dart';
import 'package:core_ui/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/admin/presentation/privacy_policy_screen.dart';
import 'package:labs/features/compliance/presentation/delete_account_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

/// No-op GDPR/auth/log fakes: the golden renders the surface, it does not
/// exercise the erasure chain (that is the behaviour suite's job).
class _QuietLogger implements LoggerService {
  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {}

  @override
  Future<void> info(Map<String, dynamic> context, String message) async {}

  @override
  Future<void> warn(Object error, String message, {StackTrace? stack}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuietGdprService implements GdprService {
  @override
  Future<bool> deleteMyData() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuietAuthRepository implements AuthRepository {
  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `/login` is registered exactly as in the behaviour suite so the screen's
/// `context.go('/login')` path would resolve if it ever ran.
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

/// Locks the standard Android HD viewport so goldens are device-agnostic.
void _lockViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Deterministic host: font fetching off, the real brand theme at the requested
/// brightness, fixed locale. When [router] is given the app is a
/// `MaterialApp.router` (the delete-account surface navigates via GoRouter).
Widget _wrap(
  Widget child, {
  required ThemeData theme,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  GoRouter? router,
}) {
  GoogleFonts.config.allowRuntimeFetching = false;
  final Widget app = router == null
      ? MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        )
      : MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: theme,
          locale: locale,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        );
  return ProviderScope(overrides: overrides, child: app);
}

Future<void> _captureDeleteAccount(
  WidgetTester tester, {
  required bool dark,
  required String golden,
}) async {
  _lockViewport(tester);
  await tester.pumpWidget(
    _wrap(
      const DeleteAccountScreen(),
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      overrides: <Override>[
        gdprServiceProvider.overrideWithValue(_QuietGdprService()),
        loggerProvider.overrideWithValue(_QuietLogger()),
        authRepositoryProvider.overrideWithValue(_QuietAuthRepository()),
      ],
      router: _deleteAccountRouter(),
    ),
  );
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(DeleteAccountScreen),
    matchesGoldenFile(golden),
  );
}

Future<void> _capturePrivacyPolicy(
  WidgetTester tester, {
  required bool dark,
  required String golden,
}) async {
  _lockViewport(tester);
  await tester.pumpWidget(
    _wrap(
      const PrivacyPolicyScreen(),
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      overrides: <Override>[
        restaurantConfigProvider.overrideWith(
          (ref) => Stream<RestaurantConfigModel>.value(
            const RestaurantConfigModel(
              privacyUrl: 'https://example.com/privacy',
            ),
          ),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(PrivacyPolicyScreen),
    matchesGoldenFile(golden),
  );
}

void main() {
  testWidgets('P21 delete-account golden — light', (tester) async {
    await _captureDeleteAccount(
      tester,
      dark: false,
      golden: 'snapshots/p21_delete_account_light.png',
    );
  });

  testWidgets('P21 delete-account golden — dark', (tester) async {
    await _captureDeleteAccount(
      tester,
      dark: true,
      golden: 'snapshots/p21_delete_account_dark.png',
    );
  });

  testWidgets('P21 privacy-policy golden — light', (tester) async {
    await _capturePrivacyPolicy(
      tester,
      dark: false,
      golden: 'snapshots/p21_privacy_policy_light.png',
    );
  });

  testWidgets('P21 privacy-policy golden — dark', (tester) async {
    await _capturePrivacyPolicy(
      tester,
      dark: true,
      golden: 'snapshots/p21_privacy_policy_dark.png',
    );
  });
}
