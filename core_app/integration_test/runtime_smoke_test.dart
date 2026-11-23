@Tags(['e2e', 'needs-emulator'])
library;

import 'dart:async';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/main.dart' as app;

// CARNAMA CONSTITUTION Law 30: Centralized test infrastructure
import 'test_helpers/emulator_bootstrap.dart';

void main() {
  // CARNAMA CONSTITUTION Law 30: Force all E2E to use local Emulators.
  setUpAll(() async {
    await bootstrapEmulators();
  });

  testWidgets('Runtime UI Smoke Test & Startup Benchmark', (tester) async {
    final timer = Stopwatch()..start();

    // Launch the app
    unawaited(app.main());

    // Wait for the splash to mount (bounded: init is async and the widget
    // tree can still be empty on the first pumps). The deadline is aligned
    // with the splash's own 30s init timeout (splash_screen.dart:85):
    // app.main()'s Firebase/config/Isar init all complete BEFORE runApp
    // mounts the tree, so under battery load (concurrent gradle daemon)
    // the splash can legitimately appear after the old 5s window expired
    // (red: green_r2_full_battery_v4.txt "Found 0 widgets with type
    // BrandedSplash"). This is a bounded wait on the real signal (the
    // finder), not a sleep.
    final splashDeadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(splashDeadline) &&
        find.byType(BrandedSplash).evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Verify splash screen appears. The splash renders the library
    // BrandedSplash (splash_screen.dart:133, UI-13/p21 C1) - the hand-rolled
    // Icon/Text/spinner Column was frozen into that library widget, so a raw
    // CircularProgressIndicator no longer exists anywhere in the tree
    // (red: green_r2_full_battery_v3.txt - 0 widgets of that type at :28).
    expect(
      find.byType(BrandedSplash),
      findsOneWidget,
      reason: 'splash screen (BrandedSplash) must render during init',
    );

    // Wait for up to 10 seconds for the splash to hand off to a real screen.
    // Navigated = the splash is GONE: matching the literal 'Carnama' text
    // would false-pass against the splash's own app name (BrandedSplash
    // renders AppConfig.appName), so the splash's absence is the signal.
    final endWaitTime = DateTime.now().add(const Duration(seconds: 10));
    bool navigated = false;

    while (DateTime.now().isBefore(endWaitTime)) {
      await tester.pump(const Duration(milliseconds: 500));

      if (find.byType(BrandedSplash).evaluate().isEmpty) {
        navigated = true;
        break;
      }
    }

    timer.stop();

    expect(
      navigated,
      isTrue,
      reason: 'Failed to navigate away from Splash Screen within 10 seconds',
    );
    expect(
      timer.elapsedMilliseconds,
      lessThanOrEqualTo(10000),
      reason: 'Startup time benchmark exceeded 10s',
    );
  });
}
