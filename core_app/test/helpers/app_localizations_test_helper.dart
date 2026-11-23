import 'package:flutter/material.dart';
import 'package:labs/l10n/app_localizations.dart';

/// Helper class for providing AppLocalizations in widget tests.
class AppLocalizationsTestHelper {
  static const List<LocalizationsDelegate<dynamic>> delegates =
      AppLocalizations.localizationsDelegates;

  static const List<Locale> supportedLocales =
      AppLocalizations.supportedLocales;
}
