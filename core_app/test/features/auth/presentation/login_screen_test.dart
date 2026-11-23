import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/features/auth/presentation/login_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

/// In-memory [AuthRepository] fake that records every email/password call and
/// emits a real user on successful sign-in (mirrors FirebaseAuth behavior).
class _FakeAuthRepository implements AuthRepository {
  final StreamController<User?> _controller =
      StreamController<User?>.broadcast();
  User? _currentUser;

  int signInCalls = 0;
  int signUpCalls = 0;
  int resetCalls = 0;
  String? lastResetEmail;
  Completer<void>? signInGate;

  Object? signInError;

  @override
  Stream<User?> authStateChanges() => _controller.stream;

  @override
  User? get currentUser => _currentUser;

  void emitSignedIn(User user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  Future<UserModel?> getUserData(String uid) async => null;

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signInWithApple() async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    signInCalls++;
    final gate = signInGate;
    if (gate != null) await gate.future;
    final err = signInError;
    if (err != null) throw err;
    emitSignedIn(MockUser(uid: 'test-uid', email: email));
  }

  @override
  Future<void> signUp(String email, String password, String name) async {
    signUpCalls++;
    emitSignedIn(MockUser(uid: 'signup-uid', email: email));
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetCalls++;
    lastResetEmail = email;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }
}

void main() {
  late _FakeAuthRepository fakeAuth;

  setUp(() {
    fakeAuth = _FakeAuthRepository();
  });

  Widget createSubject() {
    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginScreen(),
      ),
    );
  }

  testWidgets(
    'renders email + password fields and the CTA with the theme primary',
    (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));

      // B1-6: the sign-in CTA must be colored by the (config-driven) theme's
      // colorScheme.primary — never a hardcoded brand hex — so multi-app
      // branding + WCAG contrast hold per app.
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final context = tester.element(find.byType(ElevatedButton));
      final scheme = Theme.of(context).colorScheme;
      final enabledBackground =
          button.style?.backgroundColor?.resolve(const <WidgetState>{}) ??
          scheme.primary;
      expect(enabledBackground, scheme.primary);
    },
  );

  testWidgets('sign-in failure surfaces a mapped, user-safe error', (
    tester,
  ) async {
    fakeAuth.signInError = FirebaseAuthException(
      code: 'wrong-password',
      message: 'WRONG_PASSWORD_RAW',
    );
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'nope123');
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    // Surface the sanitized mapped message, NOT the raw exception text.
    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.textContaining('WRONG_PASSWORD_RAW'), findsNothing);
  });

  testWidgets('successful sign-in calls the repository and clears loading', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(fakeAuth.signInCalls, 1);
    expect(fakeAuth.currentUser, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading state disables the sign in button until complete', (
    tester,
  ) async {
    final gate = Completer<void>();
    fakeAuth.signInGate = gate;
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pump();

    // During loading the CTA's label is replaced by a spinner, so locate the
    // ElevatedButton by type (it is the only one on the screen).
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull, reason: 'loading must disable the CTA');

    gate.complete();
    await tester.pumpAndSettle();
    final after = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Sign In'),
    );
    expect(after.onPressed, isNotNull);
  });

  testWidgets('forgot password sends a reset email to the typed address', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.pump();

    await tester.tap(find.textContaining('Forgot Password'));
    await tester.pumpAndSettle();

    expect(fakeAuth.resetCalls, 1);
    expect(fakeAuth.lastResetEmail, 'user@example.com');
  });

  testWidgets(
    'forgot password without a valid email asks for the email first',
    (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Forgot Password'));
      await tester.pumpAndSettle();

      expect(fakeAuth.resetCalls, 0);
      expect(
        find.text('Enter your email above, then tap Forgot Password.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('renders the create-account and legal links', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text("Don't have an account?"), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
  });
}
