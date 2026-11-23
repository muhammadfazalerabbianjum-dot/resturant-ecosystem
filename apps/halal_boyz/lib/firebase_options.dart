// GENERATED FILE — white-label fleet ARCH-2. Per-project Firebase options
// for this shell, emitted by the core_app tool/whitelabel.dart from the
// client's own client_config.json. Re-run the generator to refresh;
// hand-edits are overwritten on regeneration.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for this shell's Firebase project
/// (demo-tenant).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web — '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDEMO-PLACEHOLDER-NOT-A-KEY',
    appId: '1:000000000000:android:b2177c7fda8dcfb67b3288',
    messagingSenderId: '000000000000',
    projectId: 'demo-tenant',
    storageBucket: 'demo-tenant.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDEMO-PLACEHOLDER-NOT-A-KEY',
    appId: '1:000000000000:ios:d67c1144f07cbf1d7b3288',
    messagingSenderId: '000000000000',
    projectId: 'demo-tenant',
    storageBucket: 'demo-tenant.firebasestorage.app',
  );
}
