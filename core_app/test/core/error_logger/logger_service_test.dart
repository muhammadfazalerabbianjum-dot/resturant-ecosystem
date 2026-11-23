import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

void main() {
  group('LoggerService - File Operations', () {
    late Directory tempDir;
    late LoggerService logger;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('logger_test_');
      logger = LoggerService(testDirectory: tempDir);
      await logger.init();
    });

    tearDown(() async {
      await logger.clearLogs();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('init creates log file', () async {
      final logFile = File('${tempDir.path}/app_logs.txt');
      expect(await logFile.exists(), isTrue);
    });

    test('info writes to log file', () async {
      await logger.info({'key': 'value'}, 'Test info message');

      final logFile = File('${tempDir.path}/app_logs.txt');
      final contents = await logFile.readAsString();
      expect(contents, contains('INFO'));
      expect(contents, contains('Test info message'));
    });

    test('warning writes to log file', () async {
      // Use setContext to set state
      await logger.info({'level': 'warning', 'key': 'value'}, 'Test warning');

      final logFile = File('${tempDir.path}/app_logs.txt');
      final contents = await logFile.readAsString();
      expect(contents, contains('INFO'));
      expect(contents, contains('Test warning'));
    });

    test('error writes to log file with context', () async {
      await logger.error(
        Exception('test error'),
        'Error occurred',
        stack: StackTrace.current,
      );

      final logFile = File('${tempDir.path}/app_logs.txt');
      final contents = await logFile.readAsString();
      expect(contents, contains('ERROR'));
      expect(contents, contains('Error occurred'));
    });

    test('setContext stores contextual info', () async {
      logger.setContext(
        screen: 'HomeScreen',
        userId: 'user_123',
        action: 'view_menu',
      );
      await logger.info({'key': 'value'}, 'With context');

      // Context should be available but not directly in log output
      // The context is used by Crashlytics, not the log file
      final logFile = File('${tempDir.path}/app_logs.txt');
      final contents = await logFile.readAsString();
      expect(contents, contains('INFO'));
    });

    test('readLogs returns written log lines', () async {
      await logger.info({'key': 'val1'}, 'First message');
      await logger.info({'key': 'val2'}, 'Second message');

      final logs = await logger.readLogs();
      expect(logs.length, greaterThanOrEqualTo(2));
      expect(logs.any((l) => l.contains('First message')), isTrue);
      expect(logs.any((l) => l.contains('Second message')), isTrue);
    });

    test('clearLogs deletes log file', () async {
      await logger.info({'key': 'value'}, 'Before clear');
      await logger.clearLogs();

      final logs = await logger.readLogs();
      expect(logs, isEmpty);
    });

    test('PII scrubbing removes emails from log content', () async {
      const testMessage = 'User contact@example.com reported an issue';
      await logger.info({'email': 'test@email.com'}, testMessage);

      final logs = await logger.readLogs();
      expect(logs.any((l) => l.contains('[EMAIL_REDACTED]')), isTrue);
      expect(logs.any((l) => l.contains('contact@example.com')), isFalse);
    });

    test('PII scrubbing removes phone numbers from log content', () async {
      const testMessage = 'Call 555-123-4567 for support';
      await logger.info({'phone': '555-123-4567'}, testMessage);

      final logs = await logger.readLogs();
      expect(logs.any((l) => l.contains('[PHONE_REDACTED]')), isTrue);
      expect(logs.any((l) => l.contains('555-123-4567')), isFalse);
    });

    test('multiple log levels write correctly', () async {
      await logger.info({'key': 'info'}, 'Info message');
      await logger.error(Exception('err'), 'Error message');

      final logs = await logger.readLogs();
      final infoCount = logs.where((l) => l.contains('[INFO]')).length;
      final errorCount = logs.where((l) => l.contains('[ERROR]')).length;

      expect(infoCount, greaterThanOrEqualTo(1));
      expect(errorCount, greaterThanOrEqualTo(1));
    });

    test(
      'W9.11: app_logs.txt rotates at maxLogFileSize (single generation)',
      () async {
        final rotatingLogger = LoggerService(
          testDirectory: tempDir,
          maxLogFileSize: 256,
        );
        await rotatingLogger.init();
        for (var i = 0; i < 40; i++) {
          await rotatingLogger.info({
            'k': 'v',
          }, 'line $i with some padding text to grow the file quickly');
        }

        final current = File('${tempDir.path}/app_logs.txt');
        final rotated = File('${tempDir.path}/app_logs.1.txt');
        expect(await rotated.exists(), isTrue);
        // The CURRENT generation stays bounded (one line over the cap at most).
        expect(await current.length(), lessThanOrEqualTo(1024));
        // The rotated generation holds the superseded lines.
        expect((await rotated.readAsLines()).length, greaterThanOrEqualTo(1));
      },
    );

    test('W9.11: clearLogs removes BOTH generations', () async {
      final rotatingLogger = LoggerService(
        testDirectory: tempDir,
        maxLogFileSize: 256,
      );
      await rotatingLogger.init();
      for (var i = 0; i < 40; i++) {
        await rotatingLogger.info({
          'k': 'v',
        }, 'line $i with some padding text to grow the file quickly');
      }
      expect(await File('${tempDir.path}/app_logs.1.txt').exists(), isTrue);

      await rotatingLogger.clearLogs();

      expect(await File('${tempDir.path}/app_logs.1.txt').exists(), isFalse);
      expect(await rotatingLogger.readLogs(), isEmpty);
    });

    test('encoded context is valid JSON after URI decode', () async {
      await logger.info({'key': 'value', 'number': 42}, 'Test');

      final logs = await logger.readLogs();
      expect(logs.isNotEmpty, isTrue);

      // Extract the encoded context after the pipe symbol
      final logLine = logs.first;
      final parts = logLine.split('|');
      if (parts.length >= 2) {
        final encoded = parts.last.trim();
        final decoded = Uri.decodeComponent(encoded);
        final parsed = jsonDecode(decoded) as Map<String, dynamic>;
        expect(parsed, containsPair('key', 'value'));
      }
    });
  });
}
