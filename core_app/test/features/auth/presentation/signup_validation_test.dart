import 'dart:async';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';
import 'package:labs/features/auth/presentation/signup_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

/// COV-4 — signup VALIDATION + error paths not covered by
/// signup_screen_test.dart (which covers empty-fields, ToS gate and
/// email-already-in-use): weak password / invalid email field rules and
/// the weak-password / network / profile-persistence failure paths.

class _MockLogger extends Mock implements LoggerService {}

/// In-memory [AuthRepository] fake that records [signUp] invocations and can
/// be armed with the exact failure each test needs.
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

  Future<void> acceptToS(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  testWidgets(
    'a password shorter than 6 characters is blocked before the repository '
    'is called',
    (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'ok@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'abc');
      await tester.pump();
      await acceptToS(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Min 6 characters'), findsOneWidget);
      expect(fakeAuth.signUpCalls, 0);
    },
  );

  testWidgets('an email without @ is blocked before the repository is called', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
    await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.pump();
    await acceptToS(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Enter valid email'), findsOneWidget);
    expect(fakeAuth.signUpCalls, 0);
  });

  testWidgets(
    'server weak-password rejection surfaces a user-safe snackbar, never '
    'the raw SDK message, and is audit-logged',
    (tester) async {
      fakeAuth.signUpError = FirebaseAuthException(
        code: 'weak-password',
        message: 'RAW_WEAK_PASSWORD',
      );
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'new@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'abc123');
      await tester.pump();
      await acceptToS(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      // PERF-1 H-2: weak-password now maps to its DEDICATED user-safe copy
      // (was: the generic "unexpected server error" fallback). The raw SDK
      // message still never surfaces.
      expect(
        find.text('That password is too weak. Please choose a stronger one.'),
        findsOneWidget,
      );
      expect(find.textContaining('RAW_WEAK_PASSWORD'), findsNothing);
      verify(() => mockLogger.error(any(), any())).called(1);
    },
  );

  testWidgets(
    'network failure during sign-up surfaces the connection snackbar',
    (tester) async {
      fakeAuth.signUpError = FirebaseAuthException(
        code: 'network-request-failed',
        message: 'NETWORK_RAW',
      );
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'new@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.pump();
      await acceptToS(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please check your internet connection.'),
        findsOneWidget,
      );
      expect(find.textContaining('NETWORK_RAW'), findsNothing);
    },
  );

  testWidgets('profile-persistence failure (non-auth error) surfaces the retry '
      'snackbar and is audit-logged', (tester) async {
    fakeAuth.signUpError = Exception('PROFILE_SYNC_FAILED_RAW');
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
    await tester.enterText(find.byType(TextFormField).at(1), 'new@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.pump();
    await acceptToS(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Sign up failed. Please try again.'), findsOneWidget);
    expect(find.textContaining('PROFILE_SYNC_FAILED_RAW'), findsNothing);
    verify(
      () => mockLogger.error(any(), any(), stack: any(named: 'stack')),
    ).called(1);
  });
}
