// UI-13 (p21 D) — auth-funnel adoption receipts (M-3).
//
// D1/D2: login + signup compose through the frozen core_ui library
// (BrandTextField, BrandButton, InfoBanner, BrandCard).
// D3: the TOS screen renders through the brand shell with wording that is
// byte-identical to the ARB copy in BOTH locales (compliance copy is not a
// style choice — the parity tests pin the exact ARB strings).
//
// These tests are RED against the pre-adoption screens (hand-rolled
// TextFormField/ElevatedButton/plain-Text error) and GREEN after adoption.
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/auth/presentation/login_screen.dart';
import 'package:labs/features/auth/presentation/signup_screen.dart';
import 'package:labs/features/auth/presentation/terms_of_service_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

/// Auth repository that fails every email/password sign-in with a MAPPED
/// (user-safe) network error — exercises the login inline error surface.
class _ThrowingAuthRepository implements AuthRepository {
  @override
  Stream<User?> authStateChanges() => const Stream<User?>.empty();

  @override
  User? get currentUser => null;

  @override
  Future<UserModel?> getUserData(String uid) async => null;

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signInWithApple() async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) =>
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'NETWORK_RAW_PAYLOAD',
      );

  @override
  Future<void> signUp(String email, String password, String name) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {}
}

Widget _loginApp({AuthRepository? repository}) => ProviderScope(
  overrides: [
    if (repository != null)
      authRepositoryProvider.overrideWithValue(repository),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: LoginScreen(),
  ),
);

Widget _signupApp() => const ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SignupScreen(),
  ),
);

Widget _tosApp(Locale locale) => ProviderScope(
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const TermsOfServiceScreen(),
  ),
);

void main() {
  group('P21 D1 — login library composition', () {
    testWidgets('the two credential fields render through BrandTextField', (
      tester,
    ) async {
      await tester.pumpWidget(_loginApp());
      await tester.pumpAndSettle();

      expect(find.byType(BrandTextField), findsNWidgets(2));
      // The platform autofill contract is unchanged: the inner TextFormField
      // still exists for every consumer (form validation + a11y finders).
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('the primary CTA renders through BrandButton', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pumpAndSettle();

      expect(find.byType(BrandButton), findsOneWidget);
      expect(
        find.widgetWithText(BrandButton, 'Sign In'),
        findsOneWidget,
        reason: 'the frozen button keeps the localized Sign In label',
      );
    });

    testWidgets('the inline sign-in error renders through InfoBanner', (
      tester,
    ) async {
      await tester.pumpWidget(_loginApp(repository: _ThrowingAuthRepository()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.pump();
      await tester.tap(find.widgetWithText(BrandButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.byType(InfoBanner), findsOneWidget);
      expect(
        find.text('Please check your internet connection.'),
        findsOneWidget,
        reason: 'the mapped, user-safe message is preserved byte-identically',
      );
      expect(find.textContaining('NETWORK_RAW_PAYLOAD'), findsNothing);
    });
  });

  group('P21 D2 — signup library composition', () {
    testWidgets('the three credential fields render through BrandTextField', (
      tester,
    ) async {
      await tester.pumpWidget(_signupApp());
      await tester.pumpAndSettle();

      expect(find.byType(BrandTextField), findsNWidgets(3));
      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    testWidgets('the sign-up CTA renders through BrandButton', (tester) async {
      await tester.pumpWidget(_signupApp());
      await tester.pumpAndSettle();

      expect(find.byType(BrandButton), findsOneWidget);
      expect(find.widgetWithText(BrandButton, 'Sign Up'), findsOneWidget);
    });
  });

  group('P21 D3 — TOS brand shell + wording parity', () {
    testWidgets('the body renders through BrandCard and BrandButton', (
      tester,
    ) async {
      await tester.pumpWidget(_tosApp(const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.byType(BrandCard), findsOneWidget);
      expect(find.byType(BrandButton), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('en: every rendered string is byte-identical to the ARB copy', (
      tester,
    ) async {
      await tester.pumpWidget(_tosApp(const Locale('en')));
      await tester.pumpAndSettle();

      const allowed = <String>{
        'Terms of Service',
        'Please review our terms of service before using the app.',
        'Back',
      };
      final strays = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            !allowed.contains(widget.data),
        skipOffstage: false,
      );
      expect(
        strays,
        findsNothing,
        reason: 'compliance wording may not drift from app_en.arb',
      );
      expect(find.text('Terms of Service'), findsNWidgets(2));
      expect(
        find.text('Please review our terms of service before using the app.'),
        findsOneWidget,
      );
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('ar: every rendered string is byte-identical to the ARB copy', (
      tester,
    ) async {
      await tester.pumpWidget(_tosApp(const Locale('ar')));
      await tester.pumpAndSettle();

      const allowed = <String>{
        'شروط الخدمة',
        'يرجى مراجعة شروط الخدمة قبل استخدام التطبيق.',
        'رجوع',
      };
      final strays = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            !allowed.contains(widget.data),
        skipOffstage: false,
      );
      expect(
        strays,
        findsNothing,
        reason: 'compliance wording may not drift from app_ar.arb',
      );
      expect(find.text('شروط الخدمة'), findsNWidgets(2));
      expect(
        find.text('يرجى مراجعة شروط الخدمة قبل استخدام التطبيق.'),
        findsOneWidget,
      );
      expect(find.text('رجوع'), findsOneWidget);
    });
  });
}
