import 'package:flutter/foundation.dart' show debugPrint;

import 'log_directory.dart';
import 'log_sink_base.dart';

export 'log_sink_base.dart';

/// Lines kept in memory on the web. Bounded for the same reason the file is
/// capped: an unbounded log is a memory leak with extra steps.
const int kWebLogBufferLines = 500;

/// Web sink: no filesystem, so a bounded in-memory buffer for this session.
///
/// Honest limit: web logs do NOT survive a reload, and they are not shipped to
/// Crashlytics from here (the logger's own `!kIsWeb` guard already skips that).
Future<LogSink> openLogSink(LogDirectory? directory, int maxBytes) async =>
    MemoryLogSink();

class MemoryLogSink implements LogSink {
  final List<String> _lines = <String>[];

  @override
  Future<void> open() async {}

  @override
  Future<void> append(String line) async {
    _lines.add(line);
    if (_lines.length > kWebLogBufferLines) {
      _lines.removeRange(0, _lines.length - kWebLogBufferLines);
    }
    // Still visible in the browser console, which is where a web engineer will
    // look first.
    debugPrint(line.trimRight());
  }

  @override
  Future<List<String>> readLines() async => List<String>.unmodifiable(_lines);

  @override
  Future<void> clear() async => _lines.clear();
}
