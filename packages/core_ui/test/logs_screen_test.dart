import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';

/// P6-03: Stub-screen behavior test — LogsScreen.
/// Must render logs from loggerProvider.readLogs() (not static 'No logs').
void main() {
  group('LogsScreen — renders real logs (P6-03)', () {
    testWidgets('renders title and empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [loggerProvider.overrideWithValue(_FakeLogger(logs: []))],
          child: const MaterialApp(home: LogsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('logsTitle')), findsOneWidget);
      // Empty logs → empty state text
      expect(find.text('No logs available'), findsOneWidget);
    });

    testWidgets('renders log lines when logs exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loggerProvider.overrideWithValue(
              _FakeLogger(logs: ['[INFO] Test log message']),
            ),
          ],
          child: const MaterialApp(home: LogsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      // The log line should render
      expect(find.textContaining('Test log message'), findsOneWidget);
    });
  });
}

/// A logger that returns canned logs without touching the file system.
/// Avoids platform channel / file I/O hangs in widget tests.
class _FakeLogger extends LoggerService {
  final List<String> _logs;
  _FakeLogger({List<String> logs = const []}) : _logs = logs;

  @override
  Future<void> init() async {}

  @override
  Future<List<String>> readLogs() async => _logs;
}
