@Tags(['e2e', 'needs-emulator'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/main.dart' as app;
import 'test_helpers/navigation.dart';

// CARNAMA CONSTITUTION Law 30: Centralized test infrastructure
import 'test_helpers/emulator_bootstrap.dart';
import 'test_helpers/test_users.dart';
import 'test_helpers/cleanup.dart';

void main() {
  // CARNAMA CONSTITUTION Law 30: Strict Emulator Wrapping
  setUpAll(() async {
    await bootstrapEmulators();
  });

  // CARNAMA CONSTITUTION Law 30: Cleanup before each test
  setUp(() async => await TestCleanup.cleanCurrentUser());

  testWidgets('E2E Setup Wizard: Full configuration flow modifies state', (
    tester,
  ) async {
    // 1. Launch App as an OWNER. The setup screen lives at
    // /admin/setup/restaurant in config-mode routing (client_config.json) -
    // an authenticated route (not in publicPaths). createUser auto-signs-in
    // (Firebase contract), so boot and navigate through the REAL router.
    // The old flow created an ADMIN and drove the OwnerDashboard's Setup
    // tab, but /owner is not a route in this mode and the dashboard is
    // owner-gated anyway (red: green_r2_full_battery_v3.txt - 0 widgets
    // with text "Identity"; then GoException 'no routes for location:
    // /owner' in green_r2_setupfix3.txt).
    final ownerCred = await TestUserFactory.createOwner();
    // firestore.rules:47-51 identifies the owner BY EMAIL in
    // settings/ownerInfo - without this seed every owner-gated write is
    // denied (red: green_r2_setupfix10.txt - Save failed:
    // permission-denied on the config save).
    await seedOwnerInfo(ownerEmail: ownerCred.user!.email!);
    await app.main();
    // CARNAMA CONSTITUTION Law 8: Add timeout to prevent infinite hang
    await tester.pumpAndSettle(const Duration(seconds: 10));
    await tester.goToSetupScreen();

    // 4. Verify the setup screen rendered: the Brand tab (default) carries
    // the Identity section header.
    expect(find.text('Identity'), findsWidgets);

    // Modify Restaurant Name
    final nameField = find.widgetWithText(TextField, 'Restaurant Name *');
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'Test E2E Kitchen');

    // 5. Navigate to Delivery Tab
    await tester.tap(find.text('Delivery'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Verify Order Rules section
    expect(find.text('Order Rules'), findsOneWidget);
    // The field is labeled in CENTS (setupLabelMinimumOrderCents,
    // app_en.arb) - the old '($)' label predates the money-in-cents rule
    // (Law 2). Enter a valid integer cents value.
    final minOrderField = find.widgetWithText(
      TextField,
      'Minimum Order (cents)',
    );
    await tester.enterText(minOrderField, '1050');

    // 6. Navigate to Hours Tab - the hours are edited INLINE
    // (restaurant_setup_screen.dart:913-948: a day-switch list plus
    // open/close time fields). The old 'Edit Operating Hours' sub-screen
    // (holiday-mode toggle + popup save) no longer exists:
    // loc.editOperatingHours is dead l10n and operating_hours_screen.dart
    // has no route in config mode (red: green_r2_setupfix4.txt - 0 widgets
    // with text "Edit Operating Hours" on the Hours tab).
    // The TabBar is isScrollable with 7 tabs - 'Hours' (6th) sits outside
    // the viewport, so scroll it into view before tapping (red:
    // green_r2_setupfix5.txt - the off-screen tap never switched tabs).
    await tester.ensureVisible(find.text('Hours'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hours'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Verify hours section
    expect(find.text('Operating Hours'), findsOneWidget);

    // Set open/close times on the real inline fields. The hours ListView
    // is lazy: only the first day rows are built (dump: Monday-Friday,
    // no time fields), so scroll the fields into view first. The
    // scrollable is the ListView's own Scrollable (the last one in the
    // tree - the API casts the widget to Scrollable, ListView itself
    // throws, red: green_r2_setupfix8.txt).
    final openField = find.widgetWithText(TextField, 'Open Time (e.g. 09:00)');
    await tester.scrollUntilVisible(
      openField,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(openField, '09:00');
    final closeField = find.widgetWithText(
      TextField,
      'Close Time (e.g. 22:00)',
    );
    await tester.scrollUntilVisible(
      closeField,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(closeField, '22:00');

    // 7. Save Setup Wizard modifications (AppBar action, loc.save)
    final masterSave = find.text('Save');
    expect(masterSave, findsOneWidget);
    await tester.tap(masterSave);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Verify SnackBar success message (loc.settingsSavedSuccessfully)
    expect(find.text('Settings saved successfully'), findsOneWidget);
  });
}
