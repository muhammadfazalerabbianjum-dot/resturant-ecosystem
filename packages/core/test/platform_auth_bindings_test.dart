import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core/core.dart';

import 'helpers/recording_logger.dart';

/// p27 T-3 — the composition-root bindings (`createPlatformAuthRepository`,
/// `usePlatformAuthEmulator`) are the ONLY places `FirebaseAuth.instance`
/// may live (Law 12/DI), and the capability extension is the only place the
/// presentation `role ==` maps live (Law 3). Both directions are pinned:
/// the extension answers every role correctly, and the bindings FAIL CLOSED
/// — they throw the SDK's typed [FirebaseException] when no Firebase app is
/// configured instead of returning a half-wired repository or no-op'ing.
/// [FirebaseException] itself comes from `package:core`'s auth export, so
/// this suite also pins the export surface p27 added.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserRolePresentationCapabilities', () {
    test(
      'isBackOfficeRole is true for every staff role, false for customer',
      () {
        expect(UserRole.owner.isBackOfficeRole, isTrue);
        expect(UserRole.manager.isBackOfficeRole, isTrue);
        expect(UserRole.kitchen.isBackOfficeRole, isTrue);
        expect(UserRole.delivery.isBackOfficeRole, isTrue);
        expect(UserRole.customer.isBackOfficeRole, isFalse);
      },
    );

    test('canViewDeadLetterQueue is owner/manager only', () {
      expect(UserRole.owner.canViewDeadLetterQueue, isTrue);
      expect(UserRole.manager.canViewDeadLetterQueue, isTrue);
      expect(UserRole.kitchen.canViewDeadLetterQueue, isFalse);
      expect(UserRole.delivery.canViewDeadLetterQueue, isFalse);
      expect(UserRole.customer.canViewDeadLetterQueue, isFalse);
    });
  });

  group('platform auth bindings fail closed without a configured app', () {
    test('createPlatformAuthRepository rejects instead of returning a '
        'half-wired repository', () {
      expect(
        () => createPlatformAuthRepository(
          firestore: FakeFirebaseFirestore(),
          logger: RecordingLogger(),
          cache: const NoOpLocalCache(),
        ),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('usePlatformAuthEmulator rejects instead of silently no-oping', () {
      expect(
        () => usePlatformAuthEmulator('127.0.0.1', 9099),
        throwsA(isA<FirebaseException>()),
      );
    });
  });
}
