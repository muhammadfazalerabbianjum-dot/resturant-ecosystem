// ignore_for_file: avoid_print
/// Verifies the Firebase Emulator is reachable on localhost:8080.
/// Called by pipeline.dart at Phase 4.10 (Law 30 Compliance).
/// Exit code 0 = reachable. Exit code 1 = not running.
library;

import 'dart:io';

Future<void> main() async {
  try {
    final socket = await Socket.connect(
      'localhost',
      8080,
      timeout: const Duration(seconds: 5),
    );
    socket.destroy();
    print('✅ Firebase Emulator is reachable on localhost:8080');
    exit(0);
  } on SocketException {
    print('❌ Firebase Emulator is NOT running on localhost:8080');
    print('   Start it with: firebase emulators:start --only firestore,auth');
    exit(1);
  }
}
