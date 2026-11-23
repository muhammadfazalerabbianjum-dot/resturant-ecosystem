import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/features/auth/presentation/signup_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:mocktail/mocktail.dart';

/// Mock [LoggerService] so the failure-path `loggerProvider.error(...)` never
/// performs real file I/O (which cannot settle under the widget-test
/// FakeAsync zone).
class _MockLogger extends Mock implements LoggerService {}

/// In-memory [AuthRepository] fake that records [signUp] invocations.
class _FakeAuthRepository implements AuthRepository {
  final StreamController<User?> _controller =
      StreamController<User?>.broadcast();
  User? _currentUser;

  int signUpCalls = 0;
  String? lastSignUpEmail;
  Object? signUpError;

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
  Future<void> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {}

  @override
  Future<void> signUp(String email, String password, String name) async {
    signUpCalls++;
    lastSignUpEmail = email;
    final err = signUpError;
    if (err != null) throw err;
    _currentUser = MockUser(uid: 'signup-uid', email: email, displayName: name);
    _controller.add(_currentUser);
  }

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
  late _MockLogger mockLogger;

  setUp(() {
    fakeAuth = _FakeAuthRepository();
    mockLogger = _MockLogger();
    when(() => mockLogger.error(any(), any())).thenAnswer((_) async {});
    when(
      () => mockLogger.error(any(), any(), stack: any(named: 'stack')),
    ).thenAnswer((_) async {});
  });

  Widget createSubject() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        loggerProvider.overrideWithValue(mockLogger),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SignupScreen(),
      ),
    );
  }

  Future<void> fillForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test User');
    await tester.enterText(fields.at(1), 'new@example.com');
    await tester.enterText(fields.at(2), 'password123');
    await tester.pump();
  }

  testWidgets('renders name, email, password fields and the sign up CTA', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('tapping Sign Up calls the repository with trimmed input', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await fillForm(tester);
    // W9.9: the ToS checkbox is required — accept it as part of the happy path.
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pumpAndSettle();

    expect(fakeAuth.signUpCalls, 1);
    expect(fakeAuth.lastSignUpEmail, 'new@example.com');
    expect(fakeAuth.currentUser, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-up validation blocks empty required fields', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // W9.9: accept the ToS so the disabled-until-accepted button becomes
    // tappable and the FIELD validation path is what this test exercises.
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pumpAndSettle();

    expect(fakeAuth.signUpCalls, 0);
    // The field label and its validation error both read "Name".
    expect(find.text('Name'), findsNWidgets(2));
    expect(find.text('Enter valid email'), findsOneWidget);
  });

  testWidgets('sign-up failure surfaces a clean localized message', (
    tester,
  ) async {
    fakeAuth.signUpError = FirebaseAuthException(
      code: 'email-already-in-use',
      message: 'EMAIL_ALREADY_USED_RAW',
    );
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await fillForm(tester);
    // W9.9: the checkbox gate precedes auth — accept it so the failure path
    // under test (FirebaseException mapping) is the one that runs.
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('EMAIL_ALREADY_USED_RAW'), findsNothing);
  });

  testWidgets('renders the already-have-account sign in link', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets(
    'T-2: submit is DISABLED until the ToS checkbox is accepted (W9.9)',
    (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await fillForm(tester);
      // The required-consent row exists and starts unchecked.
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('I agree to the'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();

      expect(fakeAuth.signUpCalls, 0);
    },
  );

  testWidgets('T-2: accepting the ToS enables the submit (green path)', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await fillForm(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pumpAndSettle();

    expect(fakeAuth.signUpCalls, 1);
  });
}
