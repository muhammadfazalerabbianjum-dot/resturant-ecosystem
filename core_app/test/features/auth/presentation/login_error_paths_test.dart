import 'dart:async';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/auth/presentation/login_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

/// COV-4 — login ERROR paths not covered by login_screen_test.dart:
/// the mapped SDK failure variants beyond wrong-password (network,
/// disabled, unavailable), the post-error loading reset, and the
/// client-side field-validation contract.

/// In-memory [AuthRepository] fake — throws the [FirebaseAuthException] the
/// Firebase SDK delivers for each scenario (the screen's
/// `on FirebaseAuthException` catch is the contract under test).
class _FakeAuthRepository implements AuthRepository {
  final StreamController<User?> _controller =
      StreamController<User?>.broadcast();
  User? _currentUser;

  int signInCalls = 0;
  Object? signInError;

  @override
  Stream<User?> authStateChanges() => _controller.stream;

  @override
  User? get currentUser => _currentUser;

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
    final err = signInError;
    if (err != null) throw err;
    _currentUser = MockUser(uid: 'test-uid', email: email);
    _controller.add(_currentUser);
  }

  @override
  Future<void> signUp(String email, String password, String name) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

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

  Future<void> fillCredentials(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.pump();
  }

  testWidgets('network-request-failed surfaces the connection message, '
      'never the raw SDK text', (tester) async {
    fakeAuth.signInError = FirebaseAuthException(
      code: 'network-request-failed',
      message: 'NETWORK_RAW_PAYLOAD',
    );
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();
    await fillCredentials(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Please check your internet connection.'), findsOneWidget);
    expect(find.textContaining('NETWORK_RAW_PAYLOAD'), findsNothing);
  });

  testWidgets('user-disabled surfaces the support message', (tester) async {
    fakeAuth.signInError = FirebaseAuthException(
      code: 'user-disabled',
      message: 'DISABLED_ACCOUNT_RAW',
    );
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();
    await fillCredentials(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(
      find.text('This account has been disabled. Please contact support.'),
      findsOneWidget,
    );
    expect(find.textContaining('DISABLED_ACCOUNT_RAW'), findsNothing);
  });

  testWidgets('unavailable surfaces the retry message', (tester) async {
    fakeAuth.signInError = FirebaseAuthException(
      code: 'unavailable',
      message: 'BACKEND_DOWN_RAW',
    );
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();
    await fillCredentials(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Service is temporarily unavailable. Please check your connection.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('BACKEND_DOWN_RAW'), findsNothing);
  });

  testWidgets('the CTA is re-enabled after a failure (loading always clears)', (
    tester,
  ) async {
    fakeAuth.signInError = FirebaseAuthException(
      code: 'network-request-failed',
      message: 'NETWORK_RAW_PAYLOAD',
    );
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();
    await fillCredentials(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Sign In'),
    );
    expect(
      button.onPressed,
      isNotNull,
      reason: 'a failed sign-in must never leave the CTA stuck disabled',
    );
    expect(fakeAuth.signInCalls, 1);
  });

  testWidgets(
    'a password shorter than 6 characters is blocked before the repository '
    'is called',
    (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'abc');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Min 6 characters'), findsOneWidget);
      expect(
        fakeAuth.signInCalls,
        0,
        reason: 'invalid credentials must never reach the repository',
      );
    },
  );

  testWidgets('an email without @ is blocked before the repository is called', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Enter valid email'), findsOneWidget);
    expect(fakeAuth.signInCalls, 0);
  });
}
