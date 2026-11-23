import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';
import 'package:labs/features/auth/presentation/login_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

/// PERF-1 (H-1) T-1/T-2 — the REAL error-surface contract, end to end:
/// the REAL [FirebaseAuthRepository] (mocktail-stubbed SDK boundary) fails,
/// RETHROWS the TYPED exception (H-1), and the login screen's
/// `on FirebaseAuthException` catch maps it into the user-safe copy.
///
/// Before H-1 the repository wrapped every failure into a generic
/// `Exception`, which the screen's typed catch never matched — the mapped
/// message never reached the UI (silent swallow; these two were RED, the
/// errata's source evidence at `auth_repository.dart:100`/:114).
/// Extends (never duplicates) `auth_repository_error_contract_test.dart`
/// (repository seam) and `login_error_paths_test.dart` (fake-repo screen
/// paths): this file proves the SCREEN + REPOSITORY pair together.

class _StubbedFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockLogger extends Mock implements LoggerService {}

void main() {
  late _StubbedFirebaseAuth auth;
  late _MockLogger repoLogger;
  late _MockLogger screenLogger;

  setUp(() {
    auth = _StubbedFirebaseAuth();
    repoLogger = _MockLogger();
    screenLogger = _MockLogger();
    when(
      () => repoLogger.error(any(), any(), stack: any(named: 'stack')),
    ).thenAnswer((_) async {});
    when(() => screenLogger.error(any(), any())).thenAnswer((_) async {});
  });

  Widget createSubject() {
    final repo = FirebaseAuthRepository(
      auth,
      FakeFirebaseFirestore(),
      repoLogger,

      cache: const NoOpLocalCache(),
    );
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        loggerProvider.overrideWithValue(screenLogger),
      ],
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

  testWidgets('T-1: wrong-password through the REAL repository surfaces '
      '"Incorrect email or password." on the login screen', (tester) async {
    when(
      () => auth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(
      FirebaseAuthException(code: 'wrong-password', message: 'RAW_SDK_TEXT'),
    );

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();
    await fillCredentials(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(
      find.text('Incorrect email or password.'),
      findsOneWidget,
      reason:
          'H-1: the rethrown typed exception is caught and mapped by the '
          'screen — a wrong password is no longer a silent failure',
    );
    expect(
      find.textContaining('RAW_SDK_TEXT'),
      findsNothing,
      reason: 'the screen maps the CODE; the raw SDK message never renders',
    );
    verify(
      () => repoLogger.error(any(), any(), stack: any(named: 'stack')),
    ).called(1);
  });

  testWidgets('T-2: a failed password reset through the REAL repository '
      'surfaces the mapped message in the snackbar', (tester) async {
    when(
      () => auth.sendPasswordResetEmail(email: any(named: 'email')),
    ).thenThrow(
      FirebaseAuthException(code: 'too-many-requests', message: 'RAW_TMR'),
    );

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();
    await fillCredentials(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Forgot Password?'));
    await tester.pumpAndSettle();

    expect(
      find.text('Too many attempts. Please try again later.'),
      findsOneWidget,
      reason:
          'H-1 + H-2: the typed reset failure escapes the repository and '
          'the screen maps too-many-requests to its dedicated copy',
    );
    expect(find.textContaining('RAW_TMR'), findsNothing);
    verify(
      () => repoLogger.error(any(), any(), stack: any(named: 'stack')),
    ).called(1);
    verify(() => screenLogger.error(any(), any())).called(1);
  });
}
