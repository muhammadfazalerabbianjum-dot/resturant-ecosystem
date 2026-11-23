// ============================================================================
// CARNAMA INTEGRATION TEST BUNDLE
// Single entry point — compiles & installs ONE APK, fires all suites.
// Constitution Law 30: Emulator isolation enforced globally here.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// CARNAMA CONSTITUTION Law 30: Centralized test infrastructure
import 'test_helpers/emulator_bootstrap.dart';
import 'test_helpers/test_users.dart';
import 'test_helpers/cleanup.dart';

// --- Import all test suites as named prefixes ---
import 'admin_e2e_flow_test.dart' as admin_e2e;
import 'auth_permission_ui_test.dart' as auth_ui;
import 'checkout_e2e_flow_test.dart' as checkout;
import 'e2e_constitution_flow_test.dart' as constitution;
import 'e2e_flow_test.dart' as e2e;
import 'kitchen_e2e_flow_test.dart' as kitchen;
import 'live_tracking_e2e_flow_test.dart' as live_tracking;
import 'manager_e2e_flow_test.dart' as manager;
import 'offline_integration_test.dart' as offline;
import 'push_notification_integration_test.dart' as push;
import 'realtime_update_test.dart' as realtime;
import 'runtime_smoke_test.dart' as smoke;
import 'security_rules_integration_test.dart' as security_rules;
import 'setup_wizard_e2e_test.dart' as setup_wizard;
import 'sweep_form_boundaries_test.dart' as form_sweep;
import 'sweep_golden_theme_test.dart' as golden_sweep;
import 'sweep_network_chaos_test.dart' as network_chaos;
import 'waitlist_e2e_flow_test.dart' as waitlist;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // CARNAMA CONSTITUTION Law 30: Global emulator bootstrap — runs ONCE before any suite.
  // ADB reverse tunnel maps device localhost → laptop via Wi-Fi.
  setUpAll(() async {
    await bootstrapEmulators();

    // ── CRITICAL: Pre-seed GDPR consent before any app boot ──────────────────
    // WHY: GdprConsentDialog fires asynchronously via unawaited() in SplashScreen
    // AFTER pumpAndSettle() completes — making tap-based fixes a race condition.
    // Pre-seeding SharedPreferences causes showIfNeeded() to return immediately
    // without ever rendering the dialog during ANY test in the entire suite.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gdpr_consent_given', true);
  });

  tearDownAll(() async {
    // CARNAMA CONSTITUTION Law 30: Deterministic cleanup
    await TestCleanup.cleanCurrentUser();

    // Clean GDPR flag so real app users are unaffected
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gdpr_consent_given');

    // Reset test user counter for next run
    TestUserFactory.resetCounter();
  });

  // Fire all suites, each calling their own internal main()
  admin_e2e.main();
  auth_ui.main();
  checkout.main();
  constitution.main();
  e2e.main();
  kitchen.main();
  live_tracking.main();
  manager.main();
  offline.main();
  push.main();
  realtime.main();
  smoke.main();
  security_rules.main();
  setup_wizard.main();
  form_sweep.main();
  golden_sweep.main();
  network_chaos.main();
  waitlist.main();
}
