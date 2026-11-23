import 'dart:io';

import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/config/force_update_service.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// The version-check verdict the first frame renders against (STATE-3,
/// 04-P1-BOOT): status plus the store URLs needed by the lock's CTA, read
/// from Remote Config in the SAME pass as the check (no second fetch).
class ForceUpdateDecision {
  final ForceUpdateStatus status;
  final String androidUpdateUrl;
  final String iosUpdateUrl;

  const ForceUpdateDecision({
    required this.status,
    required this.androidUpdateUrl,
    required this.iosUpdateUrl,
  });
}

/// STATE-3 (04-P1-BOOT): the version check MOVED out of the first frame.
///
/// The expensive `activate()` (setConfigSettings → setDefaults →
/// `fetchAndActivate()`, worst-case a 10 s network round-trip) no longer
/// runs inside the widget tree before the first frame: [splashInitProvider]
/// starts this provider as a PARALLEL future next to its auth race
/// (fail-open), and [ForceUpdateGuard] consumes the same shared future with
/// a non-blocking mount-time watch — so the check runs exactly once per
/// launch and is bounded by the splash funnel's 30 s + retry contract.
final forceUpdateStatusProvider = FutureProvider<ForceUpdateDecision>((
  ref,
) async {
  final service = ForceUpdateService(logger: ref.watch(loggerProvider));
  await service.activate();
  final status = await service.check();
  return ForceUpdateDecision(
    status: status,
    androidUpdateUrl: service.androidUpdateUrl,
    iosUpdateUrl: service.iosUpdateUrl,
  );
});

/// Wraps the app tree and enforces a force update WITHOUT ever blocking the
/// first frame (STATE-3 / 04-P1-BOOT):
///
/// - renders [ForceUpdateGuard.child] immediately — while the check is still
///   loading, if it fails (fail-open), and when the verdict is `ok`;
/// - shows the un-dismissible lock screen ONLY when the check resolves to
///   [ForceUpdateStatus.required] — the lock appears as soon as the parallel
///   check completes, never behind a pre-check spinner.
class ForceUpdateGuard extends ConsumerWidget {
  final Widget child;

  const ForceUpdateGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // valueOrNull: loading and error states resolve to null → child
    // (fail-open — a failed/slow Remote Config must never trap the user).
    final decision = ref.watch(forceUpdateStatusProvider).valueOrNull;
    if (decision != null && decision.status == ForceUpdateStatus.required) {
      return _ForceUpdateLockScreen(decision: decision);
    }
    return child;
  }
}

class _ForceUpdateLockScreen extends StatelessWidget {
  final ForceUpdateDecision decision;

  const _ForceUpdateLockScreen({required this.decision});

  @override
  Widget build(BuildContext context) {
    // NOTE: this MaterialApp carries its own localizations delegates — the
    // guard sits ABOVE the app's MaterialApp. The localized BODY lives below
    // this MaterialApp (`_LockScreenBody`): `AppLocalizations.of` is a
    // `!`-non-null lookup, so calling it on THIS context (above the
    // MaterialApp) resolves no AppLocalizations and crashed the lock screen
    // (pre-existing latent defect, proven by the T-4 widget test).
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _LockScreenBody(decision: decision),
    );
  }
}

class _LockScreenBody extends StatelessWidget {
  final ForceUpdateDecision decision;

  const _LockScreenBody({required this.decision});

  Future<void> _openStore() async {
    final url = Platform.isAndroid
        ? decision.androidUpdateUrl
        : decision.iosUpdateUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    // COLOR-1 (08-P0-WL-3): the lock screen is brand palette-driven.
    final brand = BrandColors.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.system_update_alt, size: 64, color: brand.success),
              const SizedBox(height: 24),
              Text(
                loc.updateRequired,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                loc.forceUpdateBody(AppConfig.appName),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _openStore,
                icon: const Icon(Icons.download),
                label: Text(loc.updateNow),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 56),
                  backgroundColor: brand.success,
                  foregroundColor: brand.background,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
