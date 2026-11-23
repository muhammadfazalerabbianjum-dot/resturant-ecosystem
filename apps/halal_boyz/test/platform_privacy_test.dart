import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// BACKEND-2 (W7.3, 06-P1-6): the generated shell's platform privacy layer.
/// FILE assertions — the shell must declare exactly the least-privilege
/// Android permission set, the iOS usage descriptions, and the Apple privacy
/// manifest. A release build without INTERNET cannot reach Firebase/Stripe;
/// background-location/foreground-service permissions have no consuming
/// feature and must never come back (P-1).
void main() {
  group('AndroidManifest.xml (fixed safe set, W7.3)', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');

    test('exists', () {
      expect(
        manifest.existsSync(),
        isTrue,
        reason: 'android/app/src/main/AndroidManifest.xml must exist',
      );
    });

    test('declares the least-privilege permission set', () {
      final text = manifest.readAsStringSync();
      expect(
        text.contains('android.permission.INTERNET'),
        isTrue,
        reason:
            'the shell must reach Firebase/Stripe (release builds die '
            'without INTERNET)',
      );
      expect(
        text.contains('android.permission.ACCESS_FINE_LOCATION'),
        isTrue,
        reason: 'checkout delivery address detection needs fine location',
      );
      expect(
        text.contains('android.permission.ACCESS_COARSE_LOCATION'),
        isTrue,
      );
      expect(
        text.contains('android.permission.POST_NOTIFICATIONS'),
        isTrue,
        reason:
            'Android 13+ requires POST_NOTIFICATIONS to display FCM '
            'order/delivery notifications',
      );
    });

    test('never declares the forbidden permissions (P-1)', () {
      final text = manifest.readAsStringSync();
      expect(
        text.contains('android.permission.ACCESS_BACKGROUND_LOCATION'),
        isFalse,
      );
      expect(text.contains('android.permission.FOREGROUND_SERVICE'), isFalse);
      expect(
        text.contains('android.permission.FOREGROUND_SERVICE_LOCATION'),
        isFalse,
      );
    });
  });

  group('iOS privacy layer (W7.3/W9.11)', () {
    test('Info.plist carries the usage descriptions', () {
      final plist = File('ios/Runner/Info.plist');
      expect(
        plist.existsSync(),
        isTrue,
        reason: 'ios/Runner/Info.plist must exist',
      );
      final text = plist.readAsStringSync();
      expect(
        text.contains('NSLocationWhenInUseUsageDescription'),
        isTrue,
        reason: 'iOS aborts on first location access without the string',
      );
      expect(
        text.contains('NSCameraUsageDescription'),
        isTrue,
        reason: 'iOS aborts on first camera access without the string',
      );
      expect(
        text.contains('NSPhotoLibraryUsageDescription'),
        isTrue,
        reason: 'iOS aborts on first photo-library access without the string',
      );
      expect(
        text.contains('NSUserTrackingUsageDescription'),
        isFalse,
        reason: 'the app performs no ad-tracking (W9.11 removal)',
      );
    });

    test('PrivacyInfo.xcprivacy exists and is the W9-corrected manifest', () {
      final xcprivacy = File('ios/Runner/PrivacyInfo.xcprivacy');
      expect(
        xcprivacy.existsSync(),
        isTrue,
        reason: 'ios/Runner/PrivacyInfo.xcprivacy must exist',
      );
      final text = xcprivacy.readAsStringSync();
      expect(
        text.contains('NSPrivacyCollectedDataTypePurchaseHistory'),
        isTrue,
        reason: 'order history must be declared (W9.11)',
      );
      expect(
        text.contains('NSPrivacyCollectedDataTypeOtherUsageData'),
        isTrue,
        reason: 'funnel analytics events must be declared (W9.11)',
      );
      expect(
        text.contains('NSPrivacyCollectedDataTypePurposeAppFunctionality'),
        isTrue,
      );
      expect(
        text.contains('NSPrivacyCollectedDataTypePurposeAnalytics'),
        isTrue,
      );
      expect(
        text.contains('NSPrivacyCollectedDataTypeEmailAddress'),
        isTrue,
        reason: 'account authentication collects email (W9.11 linked=true)',
      );
      expect(text.contains('NSPrivacyCollectedDataTypeName'), isTrue);
    });
  });
}
