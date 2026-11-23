/// The log destination LoggerService writes to, platform-independent.
///
/// Rotation, capping and persistence are the sink's business; the logger only
/// formats the line. This is what removes `dart:io` from the logger's import
/// graph (P2-1a) without changing a single call site.
abstract class LogSink {
  /// Prepares the destination (creating the file on the VM; no-op on the web).
  Future<void> open();

  /// Appends one already-formatted line, rotating first when the cap is
  /// exceeded (VM) or trimming the buffer (web).
  Future<void> append(String line);

  /// The current log lines, oldest first.
  Future<List<String>> readLines();

  /// Removes every stored line.
  Future<void> clear();
}
