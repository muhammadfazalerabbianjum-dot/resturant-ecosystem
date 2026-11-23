// ignore_for_file: unnecessary_brace_in_string_interps
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/whitelabel.dart' as whitelabel;

/// BACKEND-2 (W7.3/T-2/T-5): unit tests for `alignPlatformPrivacy` against a
/// real temp-dir fixture shaped like a `flutter create` tree. Proves:
///   T-P1 the manifest is rewritten to EXACTLY the fixed safe set
///        (forbidden P-1 permissions stripped, POST_NOTIFICATIONS added)
///   T-P2 the plist gains the usage strings (app.name injected) and loses
///        NSUserTrackingUsageDescription (W9.11)
///   T-P3 idempotency — a second (regenerate) pass is byte-identical
///   T-P4 the W9-corrected PrivacyInfo.xcprivacy template is copied
///        byte-identical (T-5)
///   T-P5 fail-closed on missing inputs
void main() {
  late Directory fixture;

  const manifestWithForbidden = r'''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <application android:label="Old"/>
</manifest>
''';

  const plistWithTracking = r'''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>NSUserTrackingUsageDescription</key>
	<string>stale tracking copy</string>
	<key>CFBundleDisplayName</key>
	<string>Fixture</string>
</dict>
</plist>
''';

  setUp(() {
    fixture = Directory.systemTemp.createTempSync('b2_privacy_');
    final manifest = File(
      '${fixture.path}${Platform.pathSeparator}android'
      '${Platform.pathSeparator}app${Platform.pathSeparator}src'
      '${Platform.pathSeparator}main${Platform.pathSeparator}AndroidManifest.xml',
    );
    manifest.createSync(recursive: true);
    manifest.writeAsStringSync(manifestWithForbidden);
    final plist = File(
      '${fixture.path}${Platform.pathSeparator}ios'
      '${Platform.pathSeparator}Runner${Platform.pathSeparator}Info.plist',
    );
    plist.createSync(recursive: true);
    plist.writeAsStringSync(plistWithTracking);
  });

  tearDown(() {
    fixture.deleteSync(recursive: true);
  });

  /// The repo template the generator copies (test CWD = core_app root).
  File xcprivacyTemplate() => File(
    'ios${Platform.pathSeparator}Runner'
    '${Platform.pathSeparator}PrivacyInfo.xcprivacy',
  );

  File fixtureManifest() => File(
    '${fixture.path}${Platform.pathSeparator}android'
    '${Platform.pathSeparator}app${Platform.pathSeparator}src'
    '${Platform.pathSeparator}main${Platform.pathSeparator}AndroidManifest.xml',
  );

  File fixturePlist() => File(
    '${fixture.path}${Platform.pathSeparator}ios'
    '${Platform.pathSeparator}Runner${Platform.pathSeparator}Info.plist',
  );

  void runAlignment() => whitelabel.alignPlatformPrivacy(
    appPath: fixture.path,
    displayName: 'Fixture App',
    xcprivacyTemplatePath: xcprivacyTemplate().path,
  );

  test('T-P1 manifest is rewritten to EXACTLY the fixed safe set', () {
    runAlignment();
    final text = fixtureManifest().readAsStringSync();
    expect(text.contains('android.permission.INTERNET'), isTrue);
    expect(text.contains('android.permission.ACCESS_FINE_LOCATION'), isTrue);
    expect(text.contains('android.permission.ACCESS_COARSE_LOCATION'), isTrue);
    expect(text.contains('android.permission.POST_NOTIFICATIONS'), isTrue);
    // P-1: the forbidden set is gone and nothing else survived.
    expect(text.contains('ACCESS_BACKGROUND_LOCATION'), isFalse);
    expect(text.contains('FOREGROUND_SERVICE'), isFalse);
    final declared = RegExp('android:name="([^"]+)"')
        .allMatches(text)
        .map((m) => m.group(1)!)
        .where((n) => n.startsWith('android.permission.'))
        .toSet();
    expect(declared, hasLength(4));
  });

  test('T-P2 plist gains usage strings and loses the tracking key (W9.11)', () {
    runAlignment();
    final text = fixturePlist().readAsStringSync();
    expect(
      text.contains('<key>NSLocationWhenInUseUsageDescription</key>'),
      isTrue,
    );
    expect(text.contains('<key>NSCameraUsageDescription</key>'), isTrue);
    expect(text.contains('<key>NSPhotoLibraryUsageDescription</key>'), isTrue);
    // The client's app name is injected into the copy.
    expect(
      text.contains('Fixture App uses your location to find the nearest'),
      isTrue,
    );
    expect(text.contains('NSUserTrackingUsageDescription'), isFalse);
    expect(text.contains('stale tracking copy'), isFalse);
    // Pre-existing, non-usage entries are untouched.
    expect(text.contains('<string>Fixture</string>'), isTrue);
  });

  test('T-P3 idempotent: a regenerate pass is byte-identical', () {
    runAlignment();
    final manifest1 = fixtureManifest().readAsBytesSync();
    final plist1 = fixturePlist().readAsBytesSync();
    runAlignment();
    expect(fixtureManifest().readAsBytesSync(), manifest1);
    expect(fixturePlist().readAsBytesSync(), plist1);
    final plistText = fixturePlist().readAsStringSync();
    expect(
      'NSLocationWhenInUseUsageDescription'.allMatches(plistText).length,
      1,
    );
  });

  test('T-P4 the W9-corrected xcprivacy is copied byte-identical (T-5)', () {
    runAlignment();
    final copied = File(
      '${fixture.path}${Platform.pathSeparator}ios'
      '${Platform.pathSeparator}Runner'
      '${Platform.pathSeparator}PrivacyInfo.xcprivacy',
    );
    expect(copied.existsSync(), isTrue);
    expect(copied.readAsBytesSync(), xcprivacyTemplate().readAsBytesSync());
    final text = copied.readAsStringSync();
    expect(text.contains('NSPrivacyCollectedDataTypePurchaseHistory'), isTrue);
    expect(text.contains('NSPrivacyCollectedDataTypeOtherUsageData'), isTrue);
  });

  test('T-P5 fail-closed: missing manifest or xcprivacy template throws', () {
    fixtureManifest().deleteSync();
    expect(() => runAlignment(), throwsA(isA<StateError>()));
    // Restore the manifest, remove the template instead.
    fixtureManifest().writeAsStringSync(manifestWithForbidden);
    expect(
      () => whitelabel.alignPlatformPrivacy(
        appPath: fixture.path,
        displayName: 'Fixture App',
        xcprivacyTemplatePath:
            '${fixture.path}${Platform.pathSeparator}nope.xcprivacy',
      ),
      throwsA(isA<StateError>()),
    );
  });
}
