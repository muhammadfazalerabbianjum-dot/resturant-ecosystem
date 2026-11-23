import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';

/// COV-4 + PERF-1 (H-1) — the REAL repository's production error contract.
/// The screen tests throw the SDK-typed [FirebaseAuthException] directly from
/// a fake; this file pins what production actually delivers to the screens.
/// PERF-1 H-1: `signInWithEmailAndPassword` and `sendPasswordResetEmail`
/// RETHROW the typed exception (mirroring the `signUp` contract) — the login
/// screen's `on FirebaseAuthException` catches map the CODE into the user-safe
/// copy. Before H-1 these two wrapped failures into a generic `Exception`,
/// which the screen's typed catch never matched: the failure surfaced nothing.

class _StubbedFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockLogger extends Mock implements LoggerService {}

void main() {
  late _StubbedFirebaseAuth auth;
  late _MockLogger logger;

  setUp(() {
    auth = _StubbedFirebaseAuth();
    logger = _MockLogger();
    when(
      () => logger.error(any(), any(), stack: any(named: 'stack')),
    ).thenAnswer((_) async {});
  });

  test('signInWithEmailAndPassword RETHROWS the typed FirebaseAuthException '
      '(PERF-1 H-1: the login screen typed catch depends on it)', () async {
    when(
      () => auth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(
      FirebaseAuthException(code: 'wrong-password', message: 'RAW_SDK_TEXT'),
    );

    final repo = FirebaseAuthRepository(
      auth,
      FakeFirebaseFirestore(),
      logger,
      cache: const NoOpLocalCache(),
    );

    Object? thrown;
    try {
      await repo.signInWithEmailAndPassword('user@example.com', 'nope123');
    } catch (e) {
      thrown = e;
    }

    expect(
      thrown,
      isA<FirebaseAuthException>(),
      reason:
          'H-1: the typed exception must escape the repository so the '
          'screen can map it — a generic wrap is silently swallowed',
    );
    expect(
      (thrown! as FirebaseAuthException).code,
      'wrong-password',
      reason: 'the screen maps the CODE (never the raw SDK message)',
    );
    verify(
      () => logger.error(any(), any(), stack: any(named: 'stack')),
    ).called(1);
  });

  test('sendPasswordResetEmail RETHROWS the typed FirebaseAuthException '
      '(PERF-1 H-1: the forgot-password snackbar path maps it)', () async {
    when(
      () => auth.sendPasswordResetEmail(email: any(named: 'email')),
    ).thenThrow(
      FirebaseAuthException(code: 'too-many-requests', message: 'RAW_TMR'),
    );

    final repo = FirebaseAuthRepository(
      auth,
      FakeFirebaseFirestore(),
      logger,
      cache: const NoOpLocalCache(),
    );

    Object? thrown;
    try {
      await repo.sendPasswordResetEmail('user@example.com');
    } catch (e) {
      thrown = e;
    }

    expect(
      thrown,
      isA<FirebaseAuthException>(),
      reason:
          'H-1: the typed exception must escape the repository so the '
          'screen can map it — a generic wrap is silently swallowed',
    );
    expect((thrown! as FirebaseAuthException).code, 'too-many-requests');
    verify(
      () => logger.error(any(), any(), stack: any(named: 'stack')),
    ).called(1);
  });

  test('signUp RETHROWS the typed FirebaseAuthException (the signup screen '
      'catches the typed exception — contract stays intact)', () async {
    when(
      () => auth.createUserWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(
      FirebaseAuthException(code: 'weak-password', message: 'RAW_WEAK'),
    );

    final repo = FirebaseAuthRepository(
      auth,
      FakeFirebaseFirestore(),
      logger,
      cache: const NoOpLocalCache(),
    );

    Object? thrown;
    try {
      await repo.signUp('new@example.com', '123', 'New User');
    } catch (e) {
      thrown = e;
    }

    expect(
      thrown,
      isA<FirebaseAuthException>(),
      reason: 'signUp rethrows the typed error so the screen can map it',
    );
    verify(
      () => logger.error(any(), any(), stack: any(named: 'stack')),
    ).called(1);
  });
}
