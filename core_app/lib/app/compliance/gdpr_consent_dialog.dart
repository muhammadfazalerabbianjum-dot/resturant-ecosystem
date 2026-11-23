import 'dart:async';
import 'package:core/core.dart' show kGdprAnalyticsConsentKey;
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/l10n/app_localizations.dart';

/// GDPR consent dialog — shown once on first launch before any analytics or
/// push notification tracking begins. Persists decision in SharedPreferences.
///
/// W9.8 (06-P1-3): the consent key is the ONE canonical
/// [kGdprAnalyticsConsentKey] (the same constant TelemetryService reads).
/// Before UX-3 this dialog wrote a DIFFERENT key (the legacy key) than the
/// one telemetry read, so an ACCEPTED dialog never enabled telemetry.
/// The decision is also THREE-state now: absent = not asked yet, false =
/// declined (durable opt-out, never re-prompted), true = accepted — the old
/// showIfNeeded treated "declined" as "not asked" and would re-prompt
/// forever.
class GdprConsentDialog extends StatelessWidget {
  const GdprConsentDialog({super.key});

  static const String _key = kGdprAnalyticsConsentKey;

  // Stream for broadcasting consent changes (analytics listener: `core_app/lib/app_bootstrap.dart:671`)
  static final _consentController = StreamController<bool>.broadcast();
  static Stream<bool> get onConsentChangedStream => _consentController.stream;

  /// True only when the user explicitly accepted.
  static Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  /// True when the user has made a decision (accepted OR declined) — the
  /// "asked once" flag of the consent chain.
  static Future<bool> isConsentDecided() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) != null;
  }

  static Future<void> _saveConsent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    _consentController.add(value);
  }

  /// Show the dialog and wait for user response — at most ONCE per install:
  /// a stored decision (accept or decline) suppresses the prompt.
  static Future<void> showIfNeeded(BuildContext context) async {
    if (await isConsentDecided()) return;
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const GdprConsentDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.gdprTitle),
      content: Text(loc.gdprBody(AppConfig.appName)),
      actions: [
        TextButton(
          onPressed: () async {
            await _saveConsent(false);
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(
            loc.decline,
            // COLOR-1: muted text follows the client palette (BrandColors),
            // falling back to AppColors only under foreign test themes.
            style: TextStyle(color: BrandColors.of(context).textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            await _saveConsent(true);
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(loc.accept),
        ),
      ],
    );
  }
}
