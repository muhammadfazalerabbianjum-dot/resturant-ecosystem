import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// OPS-CONFIG-1 truth guard (P0-WL-1 ops half, recorded in FIX_VERIFICATION.md).
///
/// The shell initializes Firebase with ITS OWN per-project
/// `lib/firebase_options.dart` (emitted from `assets/client_config.json` by
/// ARCH-2), so the tracked native platform files —
/// `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`
/// — must be mirrored by BOTH the config and the emitted options. If either
/// stops mirroring the native truth, the mismatch is invisible until the boot
/// fails closed (W6.1) or the app talks to the wrong Firebase project.
void main() {
  final packageRoot = Directory.current.path;

  Map<String, dynamic> readJson(String relativePath) =>
      jsonDecode(File('$packageRoot/$relativePath').readAsStringSync())
          as Map<String, dynamic>;

  Map<String, String> readPlistStrings(String relativePath) {
    final raw = File('$packageRoot/$relativePath').readAsStringSync();
    final pattern = RegExp(r'<key>([A-Z_]+)</key>\s*<string>([^<]+)</string>');
    return <String, String>{
      for (final match in pattern.allMatches(raw))
        match.group(1)!: match.group(2)!,
    };
  }

  /// Pulls the `key: 'value'` pairs out of one FirebaseOptions group in the
  /// emitted lib/firebase_options.dart so the statics can be compared with
  /// the native truth. The file has TWO groups (android, ios) that repeat
  /// the same identifiers (apiKey, appId, ...) — parse a SINGLE group or the
  /// ios values would silently shadow the android ones.
  Map<String, String> readFirebaseOptionsGroup(String groupSignature) {
    final raw = File(
      '$packageRoot/lib/firebase_options.dart',
    ).readAsStringSync();
    final start = raw.indexOf(groupSignature);
    if (start < 0) {
      return <String, String>{};
    }
    final end = raw.indexOf(');', start);
    final block = raw.substring(start, end);
    final pattern = RegExp(r"(\w+): '([^']*)'");
    return <String, String>{
      for (final match in pattern.allMatches(block))
        match.group(1)!: match.group(2)!,
    };
  }

  final config = readJson('assets/client_config.json');
  final googleServices = readJson('android/app/google-services.json');
  final plist = readPlistStrings('ios/Runner/GoogleService-Info.plist');
  final androidOptions = readFirebaseOptionsGroup(
    'static const FirebaseOptions android =',
  );
  final iosOptions = readFirebaseOptionsGroup(
    'static const FirebaseOptions ios =',
  );

  final environment = config['environment'] as Map<String, dynamic>;
  final firebase = config['firebase'] as Map<String, dynamic>;
  final app = config['app'] as Map<String, dynamic>;
  final bundleId = app['bundleId'] as String;

  final projectInfo = googleServices['project_info'] as Map<String, dynamic>;
  final androidClient = (googleServices['client'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere(
        (client) =>
            ((client['client_info']
                    as Map<String, dynamic>)['android_client_info']
                as Map<String, dynamic>)['package_name'] ==
            bundleId,
      );
  final androidClientInfo =
      androidClient['client_info'] as Map<String, dynamic>;

  test('firebase.projectId mirrors both native platform files', () {
    final expected = projectInfo['project_id'] as String;
    expect(
      firebase['projectId'] as String,
      expected,
      reason: 'client_config.json must mirror google-services.json project_id',
    );
    expect(
      plist['PROJECT_ID'],
      expected,
      reason:
          'GoogleService-Info.plist and google-services.json must be the '
          'same Firebase project',
    );
  });

  test('messagingSenderId mirrors the project number and GCM_SENDER_ID', () {
    final expected = projectInfo['project_number'] as String;
    expect(firebase['messagingSenderId'] as String, expected);
    expect(plist['GCM_SENDER_ID'], expected);
  });

  test('storageBucket mirrors both native platform files', () {
    final expected = projectInfo['storage_bucket'] as String;
    expect(firebase['storageBucket'] as String, expected);
    expect(plist['STORAGE_BUCKET'], expected);
  });

  test('androidAppId mirrors the google-services mobilesdk_app_id', () {
    expect(
      firebase['androidAppId'] as String,
      androidClientInfo['mobilesdk_app_id'] as String,
    );
  });

  test('iosAppId mirrors the plist GOOGLE_APP_ID', () {
    expect(firebase['iosAppId'] as String, plist['GOOGLE_APP_ID']);
  });

  test('firebaseAndroidApiKey mirrors the google-services current_key', () {
    expect(
      environment['firebaseAndroidApiKey'] as String,
      (androidClient['api_key'] as List).first['current_key'] as String,
    );
  });

  test('firebaseIosApiKey mirrors the plist API_KEY', () {
    // The iOS key is a DIFFERENT Firebase key from the Android one (the
    // project issues one key per platform). Mirroring the Android key into
    // the iOS slot looks "real", passes the W6.1 placeholder gate, and then
    // fails iOS identity — exactly the trap this guard exists for.
    expect(environment['firebaseIosApiKey'] as String, plist['API_KEY']);
  });

  test('iosClientId mirrors the plist CLIENT_ID', () {
    expect(firebase['iosClientId'] as String, plist['CLIENT_ID']);
  });

  test('bundle identity matches both platform registrations', () {
    expect(bundleId, plist['BUNDLE_ID']);
    expect(
      (androidClientInfo['android_client_info']
              as Map<String, dynamic>)['package_name']
          as String,
      bundleId,
    );
  });

  group(
    'ARCH-2: the emitted firebase_options.dart mirrors the native truth',
    () {
      test('android options carry the google-services identity', () {
        expect(
          androidOptions['apiKey'],
          environment['firebaseAndroidApiKey'] as String,
          reason: 'the emitted android apiKey must be the config/android key',
        );
        expect(
          androidOptions['appId'],
          firebase['androidAppId'] as String,
          reason: 'the emitted android appId must be the mobilesdk_app_id',
        );
        expect(
          androidOptions['messagingSenderId'],
          firebase['messagingSenderId'] as String,
        );
        expect(androidOptions['projectId'], firebase['projectId'] as String);
        expect(
          androidOptions['storageBucket'],
          firebase['storageBucket'] as String,
        );
      });

      test('ios options carry the GoogleService-Info.plist identity', () {
        expect(
          iosOptions['apiKey'],
          environment['firebaseIosApiKey'] as String,
          reason:
              'the emitted ios apiKey must be the config/ios key — '
              'never the android key',
        );
        expect(iosOptions['appId'], firebase['iosAppId'] as String);
      });
    },
  );

  test('zero foreign-project identity tokens anywhere in the config', () {
    final raw = File(
      '$packageRoot/assets/client_config.json',
    ).readAsStringSync();
    for (final token in const <String>[
      '000000000000', // Carnama project number
      'resturants-8547d', // Carnama Firebase project id
      'com.carnama.app', // Carnama application id
    ]) {
      expect(
        raw.contains(token),
        isFalse,
        reason: 'Carnama token "$token" leaked into the shell config',
      );
    }
  });
}
