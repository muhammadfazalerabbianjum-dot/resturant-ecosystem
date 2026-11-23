/// Manages onboarding tour state.
/// Tour step strings are loaded from AppLocalizations (Law 33 — i18n by Default).
class TourManager {
  final bool isFirstRun;

  TourManager({this.isFirstRun = true});

  bool get shouldShowTour => isFirstRun;

  /// Tour step keys for AppLocalizations lookup.
  /// The actual strings are resolved in the UI layer via AppLocalizations.
  List<String> get tourStepKeys => const [
    'tourStep1',
    'tourStep2',
    'tourStep3',
  ];
}
