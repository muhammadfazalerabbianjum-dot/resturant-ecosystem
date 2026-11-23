import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI-15 (p24) T-3 — the echo preference's FAIL-SAFE direction (L-P1/L-P2).
///
/// This isolate deliberately registers NO `SharedPreferences` mock, so both
/// the read and the write below hit a platform channel with no implementation
/// (`MissingPluginException`). The stored preference is therefore unreadable
/// and unwritable — the hardest real-world case (a store failing on a device
/// with a broken plugin or a locked-down profile). The contract's answer must
/// always be today's shipped behaviour: the foreground echo STAYS ON, and not
/// one call may throw into app code.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PushNotificationService.loggerForTest = LoggerService(
      testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
    );
  });

  test(
    'an unreadable preference store keeps the echo ON and never throws',
    () async {
      expect(await PushNotificationService.foregroundEchoEnabled(), isTrue);
      await PushNotificationService.setForegroundEchoEnabled(false);
      expect(
        await PushNotificationService.foregroundEchoEnabled(),
        isTrue,
        reason: 'a failed write must leave the previous, known state in place',
      );
    },
  );
}
