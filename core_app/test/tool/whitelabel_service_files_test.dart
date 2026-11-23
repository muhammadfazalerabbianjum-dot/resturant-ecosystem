// ignore_for_file: unnecessary_brace_in_string_interps
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/whitelabel.dart' as whitelabel;

/// p34 gen_proof / p36 A6 (S3-close): the `--skip-firebase` lane.
///
/// The `_maybeRunFlutterFire` skip branch prints "the stamp carries the
/// config-bundle google-services files (p36 A6)" and returns WITHOUT running
/// `flutterfire configure` — but the generator never actually emitted those
/// files, so the emitted `firebase_config_truth_test.dart` (which reads
/// `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`
/// unconditionally) crashed on a fresh skip-firebase stamp. This pins the fix:
/// `emitServiceFilesFromConfig` writes BOTH native files from the config
/// bundle, mirroring every field the truth guard asserts, so a skip-firebase
/// stamp completes its own guard battery honestly.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('whitelabel_service_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Directory scratchApp() {
    final app = Directory(
      '${tempDir.path}${Platform.pathSeparator}scratch_app',
    );
    // Minimal platform skeleton the emitter writes into (real directories,
    // mirroring the backend-bundle test's fixture shape).
    Directory(
      '${app.path}${Platform.pathSeparator}android${Platform.pathSeparator}app',
    ).createSync(recursive: true);
    Directory(
      '${app.path}${Platform.pathSeparator}ios${Platform.pathSeparator}Runner',
    ).createSync(recursive: true);
    return app;
  }

  Map<String, dynamic> configFixture() => <String, dynamic>{
    'app': <String, dynamic>{'bundleId': 'labs.scratch.client'},
    'environment': <String, dynamic>{
      'firebaseAndroidApiKey': 'AIzaSyDEMO-PLACEHOLDER-NOT-A-KEY',
      'firebaseIosApiKey': 'AIzaSyDEMO-PLACEHOLDER-NOT-A-KEY',
    },
    'firebase': <String, dynamic>{
      'projectId': 'scratch-project-1234',
      'androidAppId': '1:222333444555:android:scratchandroid0001',
      'iosAppId': '1:222333444555:ios:scratchios000000002',
      'messagingSenderId': '222333444555',
      'storageBucket': 'scratch-project-1234.firebasestorage.app',
      'iosClientId': '222333444555-scratchproof.apps.googleusercontent.com',
    },
  };

  test('emits google-services.json + GoogleService-Info.plist from config', () {
    final app = scratchApp();
    whitelabel.emitServiceFilesFromConfig(
      appPath: app.path,
      config: configFixture(),
    );

    final sep = Platform.pathSeparator;
    final googleServices = File(
      '${app.path}${sep}android${sep}app${sep}google-services.json',
    );
    final plist = File(
      '${app.path}${sep}ios${sep}Runner${sep}GoogleService-Info.plist',
    );

    expect(
      googleServices.existsSync(),
      isTrue,
      reason: 'skip-firebase stamp must carry android/app/google-services.json',
    );
    expect(
      plist.existsSync(),
      isTrue,
      reason:
          'skip-firebase stamp must carry ios/Runner/GoogleService-Info.plist',
    );

    final gs =
        jsonDecode(googleServices.readAsStringSync()) as Map<String, dynamic>;
    final projectInfo = gs['project_info'] as Map<String, dynamic>;
    expect(projectInfo['project_id'], 'scratch-project-1234');
    expect(projectInfo['project_number'], '222333444555');
    expect(
      projectInfo['storage_bucket'],
      'scratch-project-1234.firebasestorage.app',
    );

    final client = (gs['client'] as List).cast<Map<String, dynamic>>();
    final androidClient = client.firstWhere(
      (c) =>
          ((c['client_info'] as Map<String, dynamic>)['android_client_info']
              as Map<String, dynamic>)['package_name'] ==
          'labs.scratch.client',
    );
    final androidClientInfo =
        androidClient['client_info'] as Map<String, dynamic>;
    expect(
      androidClientInfo['mobilesdk_app_id'],
      '1:222333444555:android:scratchandroid0001',
    );
    expect(
      ((androidClient['api_key'] as List).first
          as Map<String, dynamic>)['current_key'],
      'AIzaSyDEMO-PLACEHOLDER-NOT-A-KEY',
    );

    final plistRaw = plist.readAsStringSync();
    expect(plistRaw, contains('<key>PROJECT_ID</key>'));
    expect(plistRaw, contains('<string>scratch-project-1234</string>'));
    expect(plistRaw, contains('<string>222333444555</string>'));
    expect(
      plistRaw,
      contains('<string>1:222333444555:ios:scratchios000000002</string>'),
    );
    expect(
      plistRaw,
      contains('<string>AIzaSyDEMO-PLACEHOLDER-NOT-A-KEY</string>'),
    );
    expect(
      plistRaw,
      contains(
        '<string>222333444555-scratchproof.apps.googleusercontent.com</string>',
      ),
    );
    expect(plistRaw, contains('<string>labs.scratch.client</string>'));
  });
}
