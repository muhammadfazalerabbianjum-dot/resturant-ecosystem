import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/l10n/app_localizations.dart';

/// Onboarding tour overlay.
///
/// UI-13 (p21 C3 / D-3): WIRED — `OnboardingScreen._getStarted` presents this
/// overlay on a real pushed route exactly when [TourManager.shouldShowTour]
/// says yes (the first-run decision read from `onboarding_completed` BEFORE
/// the flow's single write — see the gate's comment), and never otherwise;
/// the pushed route lands one frame after the go_router navigation settles so
/// the router's page-list update cannot discard it. It must never fake
/// success and all strings are localized (Law 33). Dismissal (Skip / Finish)
/// pops the route and persists NOTHING — no tour flag exists (Law 9; the
/// `onboarding_completed` write is the whole idempotency story, asserted by
/// `p21_d3_tour_wiring_test.dart` + `tour_dismissal_test.dart`).
class TourOverlay extends ConsumerStatefulWidget {
  const TourOverlay({super.key});

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends ConsumerState<TourOverlay> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final steps = _resolveSteps(loc);
    final isLast = _currentStep >= steps.length - 1;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                loc.tourStepCounter(
                  (_currentStep + 1).toString(),
                  steps.length.toString(),
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                steps[_currentStep],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    Semantics(
                      label: loc.previous,
                      button: true,
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep--),
                        child: Text(loc.previous),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  if (!isLast)
                    Semantics(
                      label: loc.next,
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => setState(() => _currentStep++),
                        child: Text(loc.next),
                      ),
                    )
                  else
                    Semantics(
                      label: loc.finish,
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(loc.finish),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                label: loc.skip,
                button: true,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(loc.skip),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resolves each localised tour step key (Law 33 — i18n by Default).
///
/// The step set mirrors TourManager.tourStepKeys, but the UI layer maps each
/// key to the corresponding AppLocalizations getter so the user sees real
/// descriptive text, never a raw key (Law 4 — no stub strings).
List<String> _resolveSteps(AppLocalizations loc) =>
    const ['tourStep1', 'tourStep2', 'tourStep3'].map((key) {
      return switch (key) {
        'tourStep1' => loc.tourStep1,
        'tourStep2' => loc.tourStep2,
        'tourStep3' => loc.tourStep3,
        _ => key,
      };
    }).toList();
