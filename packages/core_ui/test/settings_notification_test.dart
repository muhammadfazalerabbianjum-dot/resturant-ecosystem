import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI-15 (p24) T-3 — the notification-echo preference STATE (L-P1/L-P2/L-P5).
///
/// The behavioural gate itself is asserted in `packages/core`'s
/// `push_notification_echo_preference_test.dart` (0 echoes with the preference
/// off, exactly 1 with it on, taps unaffected); this file pins that the row's
/// state is the SAME stored value the gate reads — no second copy of the truth.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> hydrated() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(notificationPreferenceProvider);
    await pumpEventQueue();
    return container;
  }

  test('defaults to the echo being ON (L-P2: today, unchanged)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    expect((await hydrated()).read(notificationPreferenceProvider), isTrue);
  });

  test('a stored OFF value hydrates as OFF (restart proof)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PushNotificationService.foregroundEchoPreferenceKey: false,
    });
    expect((await hydrated()).read(notificationPreferenceProvider), isFalse);
  });

  test(
    'setEchoEnabled writes through the service that owns the read',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = await hydrated();

      await container
          .read(notificationPreferenceProvider.notifier)
          .setEchoEnabled(false);

      expect(container.read(notificationPreferenceProvider), isFalse);
      expect(
        await PushNotificationService.foregroundEchoEnabled(),
        isFalse,
        reason: 'the ONE consumer must see the value the row just applied',
      );

      final fresh = await hydrated();
      expect(
        fresh.read(notificationPreferenceProvider),
        isFalse,
        reason: 'and it must survive a restart',
      );
    },
  );

  test('a non-bool stored value stays ON (L-P2)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PushNotificationService.foregroundEchoPreferenceKey: 'yes',
    });
    expect((await hydrated()).read(notificationPreferenceProvider), isTrue);
  });
}
