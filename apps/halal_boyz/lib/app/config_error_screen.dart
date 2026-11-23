import 'package:flutter/material.dart';
import 'package:labs/l10n/app_localizations.dart';

/// Blocking boot screen shown when the shell cannot boot safely:
/// - the Firebase API key is missing or a documented placeholder (W6.1), or
/// - Firebase.initializeApp failed (fail-closed), or
/// - assets/client_config.json could not be loaded (W6.3).
///
/// The shell NEVER silently boots into an auth/Firestore/FCM-less UI; the
/// operator must supply the real per-client configuration.
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.cloud_off, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      l10n.firebaseConfigMissing,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
