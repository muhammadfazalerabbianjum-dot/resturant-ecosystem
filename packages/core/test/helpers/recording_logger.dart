import 'dart:io';

import 'package:core/core.dart';

/// CORE-COV test double for [LoggerService] (mirrors core_app's FakeLogger
/// pattern): records messages per level so a test can assert on logged
/// behavior without touching Crashlytics or the filesystem. Every service
/// under test receives it through its constructor injection point — no bare
/// `LoggerService()` in test code.
class RecordingLogger implements LoggerService {
  final List<String> infos = <String>[];
  final List<String> warns = <String>[];
  final List<String> errors = <String>[];

  @override
  Directory? get testDirectory => Directory.systemTemp;

  @override
  int get maxLogFileSize => LoggerService.kMaxLogFileSize;

  @override
  void setContext({String? screen, String? userId, String? action}) {}

  @override
  Future<void> init() async {}

  @override
  Future<void> info(Map<String, dynamic> context, String message) async {
    infos.add(message);
  }

  @override
  Future<void> warn(Object error, String message, {StackTrace? stack}) async {
    warns.add(message);
  }

  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {
    errors.add(message);
  }

  @override
  Future<List<String>> readLogs() async => const <String>[];

  @override
  Future<void> clearLogs() async {}
}
