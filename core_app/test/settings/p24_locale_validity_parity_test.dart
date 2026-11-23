import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/l10n/app_localizations.dart';

/// UI-15 (p24) T-1 — the L-P2 validity mirror, fail-closed.
///
/// The settings state lives in `core_ui`, which cannot see the app's generated
/// `AppLocalizations`; it therefore carries its own set of shipped language
/// codes. This test is the seam between the two: if a locale is added to or
/// removed from `AppLocalizations.supportedLocales`, the settings set must
/// change with it — otherwise a stored language could be applied that the app
/// does not ship (an `ar`/`fr` mismatch would silently render English chrome),
/// or a shipped language could become unreachable from the UI (L-P1).
void main() {
  test('the settings language set EQUALS AppLocalizations.supportedLocales', () {
    final shipped = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();

    expect(
      kSupportedSettingsLanguageCodes,
      shipped,
      reason:
          'kSupportedSettingsLanguageCodes (packages/core_ui) must mirror the '
          'generated supportedLocales exactly',
    );
  });
}
