import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// flutter_stripe's Android SDK hard requirements (its README), each of
/// which has bitten the fail-closed white-label boot on device (p34):
/// 1. the host Activity must extend FlutterFragmentActivity — a plain
///    FlutterActivity makes `Stripe.instance.applySettings()` throw;
/// 2. that Activity's theme must derive from Theme.AppCompat or
///    Theme.MaterialComponents — plain `@android:style/` parents throw
///    "Your theme isn't set to use Theme.AppCompat or
///    Theme.MaterialComponents".
/// Either failure ends STEP 14 of the shared bootstrap, and the shell's
/// fail-closed policy renders the blocking ConfigErrorScreen. core_app's
/// MainActivity is already the Fragment variant; the shell must match.
void main() {
  final activitySource = File(
    'android/app/src/main/kotlin/labs/carnama/halal_boyz/MainActivity.kt',
  ).readAsStringSync();

  final lightStyles = File(
    'android/app/src/main/res/values/styles.xml',
  ).readAsStringSync();

  final nightStyles = File(
    'android/app/src/main/res/values-night/styles.xml',
  ).readAsStringSync();

  final appCompatParent = RegExp(
    r'parent="[^"]*(?:Theme\.MaterialComponents|Theme\.AppCompat)[^"]*"',
  );

  test('MainActivity extends FlutterFragmentActivity so flutter_stripe can '
      'initialize', () {
    expect(activitySource, contains('FlutterFragmentActivity'));
    expect(activitySource, isNot(contains(': FlutterActivity()')));
  });

  test('LaunchTheme and NormalTheme derive from AppCompat or '
      'MaterialComponents so flutter_stripe accepts the activity theme', () {
    expect(
      appCompatParent.allMatches(lightStyles).length,
      greaterThanOrEqualTo(2),
      reason: 'values/styles.xml: LaunchTheme + NormalTheme parents',
    );
    expect(
      appCompatParent.allMatches(nightStyles).length,
      greaterThanOrEqualTo(2),
      reason: 'values-night/styles.xml: LaunchTheme + NormalTheme parents',
    );
  });
}
