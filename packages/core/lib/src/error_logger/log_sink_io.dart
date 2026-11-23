import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log_directory.dart';
import 'log_sink_base.dart';

export 'log_sink_base.dart';

/// VM sink: `app_logs.txt` with single-generation rotation.
Future<LogSink> openLogSink(LogDirectory? directory, int maxBytes) async {
  final dir = directory ?? await getApplicationDocumentsDirectory();
  final sink = FileLogSink(File('${dir.path}/app_logs.txt'), maxBytes);
  await sink.open();
  return sink;
}

class FileLogSink implements LogSink {
  FileLogSink(this._file, this._maxBytes);

  File _file;
  final int _maxBytes;

  @override
  Future<void> open() async {
    if (!await _file.exists()) {
      await _file.create(recursive: true);
    }
  }

  @override
  Future<void> append(String line) async {
    // W9.11: rotate BEFORE appending once the cap is exceeded — app_logs.txt
    // never grows unbounded; the superseded generation survives as
    // app_logs.1.txt (single generation, bounded disk).
    //
    // WHY the existence probe first: a per-test directory starts empty and
    // concurrent fire-and-forget writes can probe while open() is still in
    // flight — length() on a missing file throws PathNotFoundException.
    if (await _file.exists() && await _file.length() > _maxBytes) {
      final rotated = File('${_file.parent.path}/app_logs.1.txt');
      if (await rotated.exists()) {
        await rotated.delete();
      }
      await _file.rename(rotated.path);
      _file = File('${_file.parent.path}/app_logs.txt');
    }
    await _file.writeAsString(line, mode: FileMode.append);
  }

  @override
  Future<List<String>> readLines() async {
    if (!await _file.exists()) return <String>[];
    return _file.readAsLines();
  }

  @override
  Future<void> clear() async {
    // W9.11: a user-requested clear removes BOTH generations — the rotated
    // archive must not outlive the explicit clear.
    final rotated = File('${_file.parent.path}/app_logs.1.txt');
    if (await rotated.exists()) {
      await rotated.delete();
    }
    if (await _file.exists()) {
      await _file.delete();
    }
  }
}
