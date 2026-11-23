import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:typed_data';

/// FIRESTORE SECURITY RULES TDD (Laws 12 & 30)
///
/// Asserts that `storage.rules` works as mandated. Connects to Local Storage
/// Emulator ONLY. Never hits real GCS buckets.
void main() {
  // Skip when Firebase Emulator is not running
  const emulatorAvailable = bool.fromEnvironment(
    'EMULATOR_AVAILABLE',
    defaultValue: false,
  );
  if (!emulatorAvailable) {
    test('Storage rules — requires emulator (skipped when offline)', () {
      expect(emulatorAvailable, isFalse);
    });
    return;
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    // Law 30: Emulator binding required for all integration/rules tests.
    // Ensure `firebase emulators:start` is running.
    await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  });

  tearDown(() async => FirebaseAuth.instance.signOut());

  final dummyImageData = Uint8List.fromList(
    List.filled(100, 0),
  ); // 100 bytes of zeros
  final dummyTextData = Uint8List.fromList([
    104,
    101,
    108,
    108,
    111,
  ]); // "hello"

  group('Storage Rules — Unauthenticated (Law 12)', () {
    test('UNAUTH cannot upload to menus', () async {
      await FirebaseAuth.instance.signOut();

      final ref = FirebaseStorage.instance.ref('menus/item_1/photo.jpg');

      expect(
        () => ref.putData(
          dummyImageData,
          SettableMetadata(contentType: 'image/jpeg'),
        ),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'unauthorized',
          ),
        ),
      );
    });

    test('UNAUTH cannot delete from menus', () async {
      await FirebaseAuth.instance.signOut();

      final ref = FirebaseStorage.instance.ref('menus/item_1/photo.jpg');

      expect(
        () => ref.delete(),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'unauthorized',
          ),
        ),
      );
    });
  });

  group('Storage Rules — MIME type and Size Limits (Law 12)', () {
    test('MANAGER cannot upload non-image (text)', () async {
      // Create and sign in as manager
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'mime_mgr_${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'pass1234',
      );
      // Mock the token claim in emulator for testing:
      // Note: Full emulator end-to-end rules testing with custom claims requires
      // the v002_seed_admin_user approach or using a raw HTTP call to the emulator
      // admin endpoint to set claims. For this test, we assume standard auth upload
      // will fail if the MIME type rule triggers before custom claim rules, OR
      // we just test it as a regular user expecting unauthorized, but specifically
      // for the image check. We use avatars for self-upload test instead to avoid claim setup.

      final ref = FirebaseStorage.instance.ref(
        'avatars/${cred.user!.uid}/photo.txt',
      );

      expect(
        () => ref.putData(
          dummyTextData,
          SettableMetadata(contentType: 'text/plain'),
        ),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'unauthorized',
          ),
        ),
        reason: 'Storage rules must reject non-image MIME types',
      );

      await cred.user!.delete();
    });
  });

  group('Storage Rules — User Isolation', () {
    test('User can upload their own avatar', () async {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'avatar_${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'pass1234',
      );

      final ref = FirebaseStorage.instance.ref(
        'avatars/${cred.user!.uid}/my_photo.jpg',
      );

      // Should succeed (no exception thrown)
      final task = await ref.putData(
        dummyImageData,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      expect(task.state, TaskState.success);

      // Cleanup
      await ref.delete();
      await cred.user!.delete();
    });

    test('User CANNOT upload someone else\'s avatar', () async {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'hacker_${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'pass1234',
      );

      final ref = FirebaseStorage.instance.ref(
        'avatars/SOME_OTHER_UID/hacked.jpg',
      );

      expect(
        () => ref.putData(
          dummyImageData,
          SettableMetadata(contentType: 'image/jpeg'),
        ),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'unauthorized',
          ),
        ),
      );

      await cred.user!.delete();
    });
  });
}
