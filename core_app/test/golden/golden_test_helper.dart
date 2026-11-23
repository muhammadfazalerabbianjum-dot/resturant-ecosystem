import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core_ui/src/theme/app_colors.dart';

/// Wraps a widget for golden testing.
///
/// All GoogleFonts HTTP fetching is disabled. The [MaterialApp]'s [textTheme]
/// is overridden with plain [TextStyle]s so no font resolution occurs during
/// the test. This makes goldens deterministic, fast, and network-free.
Widget wrapForGolden(Widget child) {
  GoogleFonts.config.allowRuntimeFetching = false;

  // Build a TextTheme with zero font dependency — system default everywhere.
  const plainStyle = TextStyle();
  const systemTheme = TextTheme(
    displayLarge: plainStyle,
    displayMedium: plainStyle,
    displaySmall: plainStyle,
    headlineLarge: plainStyle,
    headlineMedium: plainStyle,
    headlineSmall: plainStyle,
    titleLarge: plainStyle,
    titleMedium: plainStyle,
    titleSmall: plainStyle,
    bodyLarge: plainStyle,
    bodyMedium: plainStyle,
    bodySmall: plainStyle,
    labelLarge: plainStyle,
    labelMedium: plainStyle,
    labelSmall: plainStyle,
  );

  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        // W9.1: seed from the REAL palette (AppColors.primary) so goldens
        // render the actual brand color instead of a stale near-miss literal.
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        textTheme: systemTheme,
        useMaterial3: true,
      ),
      home: Scaffold(body: child),
    ),
  );
}
