import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/loyalty/domain/loyalty_model.dart';
import 'package:labs/features/loyalty/presentation/loyalty_provider.dart';

/// COV-4 — provider invalidation on ORDER EVENTS + auth switches.
///
/// The production write shape is the Cloud Function's delivered-hook
/// transaction (functions/src/index.ts:1586-1614): it writes ONLY
/// `totalPoints` (+ `updatedAt`) into `loyalty/{customerId}`. These tests
/// replay that exact write shape against a FakeFirebaseFirestore and assert
/// `userLoyaltyProvider` re-emits through its snapshots() stream (the
/// client does NOT poll — the stream IS the invalidation), plus the tier
/// ladder Bronze→Silver→Gold computed by the client from the config
/// thresholds, plus auth sign-out/sign-in switching (empty-uid default,
/// per-user doc isolation).

const int _silver = 500;
const int _gold = 2000;

Future<void> _drainUntil(
  ProviderContainer container,
  bool Function(LoyaltyModel?) condition,
) async {
  for (var i = 0; i < 500; i++) {
    final state = container.read(userLoyaltyProvider).value;
    if (condition(state)) return;
    await Future<void>.delayed(Duration.zero);
    if (i % 25 == 24) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }
  fail(
    'userLoyaltyProvider never reached the expected state; last = '
    '${container.read(userLoyaltyProvider)}',
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late StreamController<User?> authController;
  late ProviderContainer container;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    authController = StreamController<User?>.broadcast();
    container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(firestore),
        authStateProvider.overrideWith((ref) => authController.stream),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await authController.close();
  });

  test('an order-delivered write (CF shape: totalPoints + updatedAt) makes the '
      'provider re-emit through the tier ladder Bronze→Silver→Gold', () async {
    await firestore.collection('loyalty').doc('u1').set({
      'userId': 'u1',
      'totalPoints': 100,
    });
    // Keep the autoDispose provider alive for the whole scenario.
    container.listen(userLoyaltyProvider, (_, _) {});
    authController.add(MockUser(uid: 'u1', email: 'u1@test.com'));

    await _drainUntil(container, (m) => m?.totalPoints == 100);
    var state = container.read(userLoyaltyProvider).value!;
    expect(state.uid, 'u1');
    expect(
      state.tierFor(silverThreshold: _silver, goldThreshold: _gold),
      'Bronze',
    );

    // First delivered order event (mirrors index.ts:1609-1612).
    await firestore.collection('loyalty').doc('u1').update({
      'totalPoints': 600,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _drainUntil(container, (m) => m?.totalPoints == 600);
    state = container.read(userLoyaltyProvider).value!;
    expect(
      state.tierFor(silverThreshold: _silver, goldThreshold: _gold),
      'Silver',
      reason: '600 >= silver(500) and < gold(2000)',
    );

    // Second delivered order event crosses the gold threshold.
    await firestore.collection('loyalty').doc('u1').update({
      'totalPoints': 2100,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _drainUntil(container, (m) => m?.totalPoints == 2100);
    state = container.read(userLoyaltyProvider).value!;
    expect(
      state.tierFor(silverThreshold: _silver, goldThreshold: _gold),
      'Gold',
    );
  });

  test(
    'auth sign-out invalidates to the empty-uid default model, and a '
    'sign-in switches to THAT user\u2019s document (per-user isolation)',
    () async {
      await firestore.collection('loyalty').doc('u2').set({
        'userId': 'u2',
        'totalPoints': 50,
      });
      container.listen(userLoyaltyProvider, (_, _) {});
      authController.add(MockUser(uid: 'u1', email: 'u1@test.com'));
      await _drainUntil(container, (m) => m?.uid == 'u1');

      // Sign out → empty uid → the designed default model (no crash).
      authController.add(null);
      await _drainUntil(
        container,
        (m) => m != null && m.uid.isEmpty && m.totalPoints == 0,
      );
      expect(container.read(userLoyaltyProvider).value!.uid, '');

      // Sign in as another user → THEIR doc is read, not the previous one.
      authController.add(MockUser(uid: 'u2', email: 'u2@test.com'));
      await _drainUntil(container, (m) => m?.uid == 'u2');
      expect(container.read(userLoyaltyProvider).value!.totalPoints, 50);
    },
  );

  test('redeemedRewardIds survive the stream (redemption state is preserved '
      'through provider emissions)', () async {
    await firestore.collection('loyalty').doc('u3').set({
      'userId': 'u3',
      'totalPoints': 2100,
      'redeemedRewardIds': ['free_coffee'],
    });
    container.listen(userLoyaltyProvider, (_, _) {});
    authController.add(MockUser(uid: 'u3', email: 'u3@test.com'));

    await _drainUntil(
      container,
      (m) => m?.redeemedRewardIds.contains('free_coffee') == true,
    );
    final state = container.read(userLoyaltyProvider).value!;
    expect(state.redeemedRewardIds, ['free_coffee']);
    expect(state.totalPoints, 2100);
  });

  test('a forged negative-points document FAILS CLOSED to 0/Bronze '
      '(PERF-1 H-3: clamped at the model parse — tier math deterministic '
      'under attack payloads)', () async {
    await firestore.collection('loyalty').doc('u4').set({
      'userId': 'u4',
      'totalPoints': -50,
    });
    container.listen(userLoyaltyProvider, (_, _) {});
    authController.add(MockUser(uid: 'u4', email: 'u4@test.com'));

    // H-3: the model clamps the forged negative to 0 at fromJson — the
    // provider stream carries the CLAMPED value, never the raw negative.
    await _drainUntil(container, (m) => m?.totalPoints == 0);
    final state = container.read(userLoyaltyProvider).value!;
    expect(state.totalPoints, 0);
    expect(
      state.tierFor(silverThreshold: _silver, goldThreshold: _gold),
      'Bronze',
      reason: 'negative points must never unlock Silver/Gold',
    );
  });
}
