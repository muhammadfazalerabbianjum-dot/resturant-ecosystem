import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// P34 boot-blocker regression (white screen on device):
/// STEP 14 of `initCarnamaApp` must pass the NEW `*AppCheckProvider` classes
/// to `FirebaseAppCheck.activate`. Casting the legacy `AndroidProvider` /
/// `AppleProvider` enums to those interfaces compiles but throws `_TypeError`
/// at runtime, and the fail-closed policy turns that throw into the blocking
/// ConfigErrorScreen ("Firebase configuration missing") observed on the
/// emulator — even when client_config.json and firebase_options.dart are
/// perfectly valid.
void main() {
  final source = File('lib/app_bootstrap.dart').readAsStringSync();

  test('App Check activation never casts legacy provider enums to provider '
      'interfaces', () {
    expect(source, isNot(contains('as AndroidAppCheckProvider')));
    expect(source, isNot(contains('as AppleAppCheckProvider')));
  });

  test('App Check activation passes the new-style provider classes', () {
    expect(source, contains('providerAndroid:'));
    expect(source, contains('const AndroidDebugProvider()'));
    expect(source, contains('const AndroidPlayIntegrityProvider()'));
    expect(source, contains('const AppleDebugProvider()'));
    expect(source, contains('const AppleAppAttestProvider()'));
  });
}
