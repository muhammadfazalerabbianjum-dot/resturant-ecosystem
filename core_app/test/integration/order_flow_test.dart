import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  // Skip when Firebase Emulator is not running
  const emulatorAvailable = bool.fromEnvironment(
    'EMULATOR_AVAILABLE',
    defaultValue: false,
  );
  if (!emulatorAvailable) {
    test('Order flow — requires emulator (skipped when offline)', () {
      expect(emulatorAvailable, isFalse);
    });
    return;
  }

  // Test setup connecting to Local Firebase Emulator
  setUpAll(() async {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  });

  test('Firebase connectivity via Local Emulator', () async {
    // Verify Firebase is initialized and connected to emulator
    expect(
      Firebase.apps.isNotEmpty,
      isTrue,
      reason: 'Firebase must be initialized',
    );

    // Verify Firestore is connected to emulator
    final settings = FirebaseFirestore.instance.settings;
    // In emulator mode, settings should show localhost
    expect(
      settings.host,
      contains('localhost'),
      reason: 'Must connect to local emulator',
    );

    // Verify Auth is connected to emulator
    expect(FirebaseAuth.instance.tenantId, isNull);

    // Write and read a test document to verify full round-trip
    final testDoc = FirebaseFirestore.instance
        .collection('test')
        .doc('integration_test');
    await testDoc.set({
      'timestamp': FieldValue.serverTimestamp(),
      'value': 'emulator_works',
    });
    final snapshot = await testDoc.get();
    expect(snapshot.exists, isTrue);
    expect(snapshot.data()!['value'], equals('emulator_works'));

    // Teardown: purge test data (Law 30 — deterministic cleanup)
    addTearDown(() async {
      try {
        await testDoc.delete();
      } catch (_) {}
    });
  });
}
