import 'package:flutter/material.dart';

import 'client_config.dart';

/// W6.5 fail-closed boot screen: rendered instead of the app when
/// `client_config.json` PARSES but violates the REQUIRED-field schema
/// (`ClientConfig.fromMap` threw [ConfigException]). A malformed REQUIRED
/// config must never silently boot on in-code defaults — the operator has to
/// fix the config.
///
/// NOTE (recorded in the WL-2 addendum): the heading is an English literal on
/// purpose. The only content that matters on this screen is the DYNAMIC
/// [ConfigException] detail, which is inherently unlocalizable; the static
/// ARB files are owned by another window (fleet §3.6, W5) and were not
/// touched by WL-2.
class ConfigValidationErrorScreen extends StatelessWidget {
  const ConfigValidationErrorScreen({super.key, required this.error});

  /// The schema failure to show the operator.
  final ConfigException error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.rule, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Invalid client configuration',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'client_config.json failed schema validation. '
                  'The app cannot start until the operator fixes it.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      error.toString(),
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// W6.4(2) debug banner: overlaid on the running app (debug builds only) when
/// the client config failed to LOAD (missing/malformed asset) and the boot
/// continued on the safe defaults + dotenv layer. Release builds log the
/// failure via `LoggerService.error` only — never a silent fallback.
class ConfigLoadFailureBanner extends StatelessWidget {
  const ConfigLoadFailureBanner({super.key});

  /// Neutral on-error white (Law 3): named const so the declaration line
  /// carries the guard's `const` exemption and the banner references the
  /// name, never a raw `Colors.` literal at the use site.
  static const Color _kBannerTextColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Banner(
      message: 'CONFIG LOAD FAILED',
      location: BannerLocation.topEnd,
      color: Theme.of(context).colorScheme.error,
      textStyle: const TextStyle(
        color: _kBannerTextColor,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }
}
