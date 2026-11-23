import 'dart:async';
import 'package:core/core.dart' show kGdprAnalyticsConsentKey;
import 'package:core_ui/src/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GDPR consent dialog — shown once on first launch before any analytics or
/// push notification tracking begins. Persists decision in SharedPreferences.
///
/// W9.8 (06-P1-3): mirrors the core_app dialog — the ONE canonical
/// [kGdprAnalyticsConsentKey] and THREE-state decision semantics (absent =
/// not asked, false = declined/durable opt-out, true = accepted). Before
/// UX-3 this copy wrote a DIFFERENT key (the legacy key) than the one
/// telemetry read. This package copy must never drift from the canonical
/// key: it is kept in sync by the shared constant plus the consent-chain
/// tests.
class GdprConsentDialog extends StatelessWidget {
  /// Display name of the application, injected by the host app.
  final String appName;

  const GdprConsentDialog({super.key, this.appName = 'Carnama'});

  static const String _key = kGdprAnalyticsConsentKey;

  // Stream for broadcasting consent changes (the host app listens on its labs copy at app_bootstrap.dart:671)
  static final _consentController = StreamController<bool>.broadcast();
  static Stream<bool> get onConsentChangedStream => _consentController.stream;

  /// True only when the user explicitly accepted.
  static Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  /// True when the user has made a decision (accepted OR declined).
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
    return AlertDialog(
      title: const Text('Data & Privacy'),
      content: Text(
        '$appName uses analytics and push notifications to improve your experience. '
        'No personally identifiable data is sold to third parties.\n\n'
        'Do you agree to our use of analytics and notifications?',
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await _saveConsent(false);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text(
            'Decline',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            await _saveConsent(true);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Accept'),
        ),
      ],
    );
  }
}
