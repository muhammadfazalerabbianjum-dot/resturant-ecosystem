// ignore_for_file: avoid_print
import 'dart:io';

/// Law 16: Permission Manifest Allowlist Enforcer
///
/// This CLI script parses the merged AndroidManifest.xml and iOS Info.plist
/// and asserts that ONLY the declared, approved permissions are present.
/// Any unknown permission → [exit(1)] → CI fails.
///
/// Run manually: dart tool/audit_permissions.dart
/// Run in CI: dart tool/audit_permissions.dart (see carnama_ci.yml tier 5)

// Approved Android permissions for Carnama app.
// If you add a plugin that requires a new permission, you MUST add it here
// with a comment explaining why it is needed.
const Set<String> _approvedAndroidPermissions = {
  'android.permission.INTERNET', // Firestore, APIs
  'android.permission.ACCESS_NETWORK_STATE', // Connectivity checks
  'android.permission.ACCESS_FINE_LOCATION', // Delivery driver GPS tracking
  'android.permission.ACCESS_COARSE_LOCATION', // Fallback location
  'android.permission.CAMERA', // Proof of Delivery photo capture
  'android.permission.RECEIVE_BOOT_COMPLETED', // WorkManager kitchen heartbeat
  'android.permission.VIBRATE', // FCM notification feedback
  // BACKEND-2 (W7.3, P-1): FOREGROUND_SERVICE / FOREGROUND_SERVICE_LOCATION /
  // ACCESS_BACKGROUND_LOCATION were REMOVED from the manifest — no consuming
  // feature (the driver stream is foreground-only) — so they must stay OUT of
  // this allowlist too (least privilege, fail-closed on reintroduction).
  'android.permission.POST_NOTIFICATIONS', // Android 13+ notification permission
  'android.permission.USE_BIOMETRIC', // Biometric login
  'android.permission.USE_FINGERPRINT', // Biometric login (legacy)
  'android.permission.NFC', // NFC terminal payment reader
  'com.android.vending.BILLING', // In-app purchases
};

// Approved iOS Info.plist NSUsageDescription keys.
const Set<String> _approvedIOSUsageKeys = {
  'NSLocationWhenInUseUsageDescription',
  'NSLocationAlwaysAndWhenInUseUsageDescription',
  'NSCameraUsageDescription',
  'NSPhotoLibraryUsageDescription',
  'NSPhotoLibraryAddUsageDescription',
  'NFCReaderUsageDescription',
  'NSFaceIDUsageDescription',
};

void main() {
  int exitCode = 0;

  // ── Android Manifest Audit ────────────────────────────────────────────────
  final manifestFile = File('android/app/src/main/AndroidManifest.xml');
  if (!manifestFile.existsSync()) {
    print(
      '⚠️  AndroidManifest.xml not found at expected path. Skipping Android audit.',
    );
  } else {
    final content = manifestFile.readAsStringSync();
    final permissionRegex = RegExp(
      r'<uses-permission[^>]+android:name="([^"]+)"',
    );
    final found = permissionRegex
        .allMatches(content)
        .map((m) => m.group(1)!)
        .toSet();

    final unknown = found.difference(_approvedAndroidPermissions);
    if (unknown.isEmpty) {
      print(
        '✅ Android permissions: All ${found.length} permissions are approved.',
      );
    } else {
      print('❌ FATAL: Unknown Android permissions detected!');
      for (final p in unknown) {
        print('   Unapproved: $p');
      }
      print(
        '   Add to _approvedAndroidPermissions in tool/audit_permissions.dart',
      );
      print('   if this permission is intentionally required.\n');
      exitCode = 1;
    }
  }

  // ── iOS Info.plist Audit ──────────────────────────────────────────────────
  final plistFile = File('ios/Runner/Info.plist');
  if (!plistFile.existsSync()) {
    print('⚠️  Info.plist not found at expected path. Skipping iOS audit.');
  } else {
    final content = plistFile.readAsStringSync();
    final usageKeyRegex = RegExp(r'<key>(NS\w+UsageDescription)</key>');
    final found = usageKeyRegex
        .allMatches(content)
        .map((m) => m.group(1)!)
        .toSet();

    final unknown = found.difference(_approvedIOSUsageKeys);
    if (unknown.isEmpty) {
      print(
        '✅ iOS permissions: All ${found.length} usage descriptions are approved.',
      );
    } else {
      print('❌ FATAL: Unknown iOS usage description keys detected!');
      for (final k in unknown) {
        print('   Unapproved: $k');
      }
      print('   Add to _approvedIOSUsageKeys in tool/audit_permissions.dart\n');
      exitCode = 1;
    }
  }

  if (exitCode == 0) {
    print(
      '\n✅ Permission manifest audit passed. No extraneous permissions found.',
    );
  } else {
    print('\n❌ Permission manifest audit FAILED. See above for violations.');
  }

  exit(exitCode);
}
