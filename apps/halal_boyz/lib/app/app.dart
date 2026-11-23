import 'package:flutter/material.dart';
import 'package:labs/labs.dart';

/// The generated shell's app root — a THIN WRAPPER (white-label fleet
/// ARCH-1/ARCH-2).
///
/// The shell's own responsibility is `main.dart`: client config load +
/// fail-fast gates (W6.1/W6.3) + its per-project Firebase options. Every
/// SCREEN, the 27-screen config-driven router, the config palette, and the
/// full en+ar l10n come from the REAL app in `package:labs` (core_app).
/// The real app reads the SAME bundled config through the `AppConfig`
/// statics hydrated inside the shared `initCarnamaApp` (STEP 07), so the
/// client palette/typography/navigation registry flow into the real
/// screens.
class GeneratedApp extends StatelessWidget {
  const GeneratedApp({super.key, required this.config});

  final Map<String, dynamic> config;

  @override
  Widget build(BuildContext context) {
    return const CoreApp();
  }
}
