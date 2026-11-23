import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:core/core.dart';

/// Checks Firebase Remote Config for minimum required app version.
/// If current version is below the minimum, returns [ForceUpdateStatus.required].
enum ForceUpdateStatus { ok, required }

class ForceUpdateService {
  final FirebaseRemoteConfig _rc;
  final LoggerService? _logger;

  ForceUpdateService({
    FirebaseRemoteConfig? remoteConfig,
    LoggerService? logger,
  }) : _rc = remoteConfig ?? FirebaseRemoteConfig.instance,
       _logger = logger;

  /// Call once at app startup (after Firebase.initializeApp).
  Future<void> activate() async {
    await _rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await _rc.setDefaults(const {
      'min_required_version': '0.0.0',
      'update_url_android':
          'https://play.google.com/store/apps/details?id=com.carnama.app',
      'update_url_ios': 'https://apps.apple.com/app/carnama/id000000000',
      'deployment_cohort': 'stable', // Law 42 (Canary)
    });
    await _rc.fetchAndActivate();

    // Law 42: Stamp the current cohort into Crashlytics to enable automated Remote Config rollback thresholds
    final cohort = _rc.getString('deployment_cohort');
    try {
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.setCustomKey('cohort', cohort);
      }
    } catch (e, stack) {
      // DI: never construct an inline logger here. If no logger was injected,
      // still fail-closed outward to debugPrint (never swallow silently).
      final logger = _logger;
      if (logger != null) {
        await logger.error(e, 'RemoteConfigCohortError', stack: stack);
      } else {
        debugPrint('RemoteConfigCohortError: $e');
      }
    }
  }

  /// Compares current build version against Remote Config minimum.
  Future<ForceUpdateStatus> check() async {
    final info = await PackageInfo.fromPlatform();
    final currentParts = info.version.split('.').map(int.tryParse).toList();
    final minVersion = _rc.getString('min_required_version');
    final minParts = minVersion.split('.').map(int.tryParse).toList();

    for (var i = 0; i < 3; i++) {
      final current = i < currentParts.length ? (currentParts[i] ?? 0) : 0;
      final min = i < minParts.length ? (minParts[i] ?? 0) : 0;
      if (current < min) return ForceUpdateStatus.required;
      if (current > min) return ForceUpdateStatus.ok;
    }
    return ForceUpdateStatus.ok;
  }

  String get androidUpdateUrl => _rc.getString('update_url_android');
  String get iosUpdateUrl => _rc.getString('update_url_ios');
}
