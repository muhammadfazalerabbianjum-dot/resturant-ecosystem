import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

import 'package:core_ui/core_ui.dart';

/// Minimal file-backed logger double (mirrors LogsScreen's own test).
class _FakeLogger extends LoggerService {
  @override
  Future<void> init() async {}

  @override
  Future<List<String>> readLogs() async => const <String>[
    '[INFO] hello from the logs screen',
  ];
}

/// CORE-COV Tier-3 BUG_REPORTER suite (B6-2): the release seam — the FAB /
/// logs escape hatch is compiled OUT (no LogsScreen access in release builds)
/// — and the debug-mode FAB flows into the real LogsScreen.
void main() {
  Widget host(BugReporterOverlay overlay) =>
      // ProviderScope must sit ABOVE MaterialApp: the bottom sheet is pushed
      // on the ROOT navigator, whose context is outside `home:`.
      ProviderScope(
        overrides: [loggerProvider.overrideWithValue(_FakeLogger())],
        child: MaterialApp(home: overlay),
      );

  testWidgets(
    'release builds carry NO bug-reporter FAB (B6-2: logs stay off-limits)',
    (tester) async {
      await tester.pumpWidget(
        host(
          const BugReporterOverlay(
            debugShowBugReporter: false,
            child: Scaffold(body: Text('The app works fine')),
          ),
        ),
      );

      expect(find.text('The app works fine'), findsOneWidget);
      expect(find.byKey(const Key('global_bug_reporter_fab')), findsNothing);
    },
  );

  testWidgets('debug builds show the FAB and open the real LogsScreen', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const BugReporterOverlay(
          debugShowBugReporter: true,
          child: Scaffold(body: Text('The app')),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.bug_report));
    // Bounded pumps — the sheet's route + LogsScreen's async log load.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The sheet hosts the real LogsScreen (raw logs + stack traces).
    expect(find.byKey(const Key('logsTitle')), findsOneWidget);
    expect(find.textContaining('hello from the logs screen'), findsOneWidget);
  });
}
