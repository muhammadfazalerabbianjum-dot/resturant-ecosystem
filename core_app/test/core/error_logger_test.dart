import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'dart:io';

void main() {
  late LoggerService logger;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('logger_test');
    logger = LoggerService(testDirectory: tempDir);
    await logger.init();
  });

  tearDown(() async {
    await logger.clearLogs();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Logger writes INFO correctly securely storing context_json as URI string',
    () async {
      await logger.info({'userId': '123'}, 'UserLogin');
      final logs = await logger.readLogs();

      expect(logs.length, 1);
      expect(logs.first, contains('[INFO]'));
      expect(logs.first, contains('UserLogin'));
      expect(
        logs.first,
        contains('%7B%22userId%22%3A%22123%22%7D'),
      ); // {"userId":"123"} URI encoded
    },
  );

  test('Logger writes ERROR correctly capturing exception details', () async {
    final fakeError = Exception('Database Failed');
    await logger.error(fakeError, 'DbCrash', stack: null);
    final logs = await logger.readLogs();

    expect(logs.length, 1);
    expect(logs.first, contains('[ERROR]'));
    expect(logs.first, contains('DbCrash'));

    final parts = logs.first.split(' | ');
    expect(parts.length, 2);
    final decodedJson = Uri.decodeComponent(parts[1]);
    expect(decodedJson, contains('Database Failed'));
  });
}
