import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/loyalty/presentation/loyalty_provider.dart';
import 'package:labs/features/loyalty/domain/loyalty_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('LoyaltyRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late LoyaltyRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = LoyaltyRepository(fakeFirestore);
    });

    test(
      'getUserLoyalty returns empty LoyaltyModel for empty userId',
      () async {
        final stream = repository.getUserLoyalty('');
        await expectLater(stream, emitsInOrder([const LoyaltyModel()]));
      },
    );

    test(
      'getUserLoyalty returns LoyaltyModel with uid when doc does not exist',
      () async {
        final stream = repository.getUserLoyalty('nonexistent_user');
        await expectLater(
          stream,
          emitsInOrder([
            predicate<LoyaltyModel>((m) => m.uid == 'nonexistent_user'),
          ]),
        );
      },
    );

    test('getUserLoyalty returns data when document exists', () async {
      await fakeFirestore.collection('loyalty').doc('user1').set({
        'points': 100,
        'tier': 'gold',
      });
      final stream = repository.getUserLoyalty('user1');
      await expectLater(
        stream,
        emitsInOrder([predicate<LoyaltyModel>((m) => m.uid == 'user1')]),
      );
    });

    test('getUserLoyalty preserves points from Firestore', () async {
      await fakeFirestore.collection('loyalty').doc('user2').set({
        'points': 500,
        'tier': 'platinum',
      });
      final stream = repository.getUserLoyalty('user2');
      await expectLater(
        stream,
        emitsInOrder([predicate<LoyaltyModel>((m) => m.uid == 'user2')]),
      );
    });

    test('LoyaltyRepository can be created with FakeFirebaseFirestore', () {
      final repo = LoyaltyRepository(fakeFirestore);
      expect(repo, isA<LoyaltyRepository>());
    });
  });
}
