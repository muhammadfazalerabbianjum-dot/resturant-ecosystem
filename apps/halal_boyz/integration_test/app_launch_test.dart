@Tags(['e2e', 'needs-emulator'])
library;

import 'package:core/core.dart' show kGdprAnalyticsConsentKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/labs.dart' show AppConfig, HomeScreen;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halal_boyz/app/app.dart';
import '../test/helpers/router_test_harness.dart';

/// Headless integration test that proves the REAL app can launch through the
/// shell: `GeneratedApp` is a THIN WRAPPER over `CoreApp` (package:labs) —
/// the shell boots with its own bundled config hydrated into the labs
/// statics, and the REAL config-driven router renders the REAL `HomeScreen`
/// wearing the client palette (ARCH-1 T-1/T-2, on-device form).
///
/// It does NOT couple to placeholder content — the placeholder screens were
/// deleted by ARCH-1. Fixed pumps, not `pumpAndSettle` (the real splash/
/// animations never settle).
void main() {
  testWidgets('the shell launches the REAL labs app on the shell config', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // The REAL shell asset (assets/client_config.json) — not a synthetic
    // fixture: the wrapper delegates to the labs statics hydrated from it.
    await loadRealConfigMode();
    SharedPreferences.setMockInitialValues(<String, Object>{
      kGdprAnalyticsConsentKey: true,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [...routerAuthOverrides(), ...homeFeedOverrides()],
        child: const GeneratedApp(config: <String, dynamic>{}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The REAL HomeScreen from package:labs is on the entry route ('/') and
    // the shell identity hydrated from the shell's own config asset — the
    // client's own app name is interpolated from the client config.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(AppConfig.loadFailed, isFalse);
    expect(AppConfig.schemaError, isNull);
    expect(AppConfig.bundleId, isNotEmpty);
    expect(AppConfig.appName, 'Halal Boyz');
  });
}
