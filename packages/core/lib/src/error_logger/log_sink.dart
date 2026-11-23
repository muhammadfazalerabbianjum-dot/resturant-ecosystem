/// P2-1a — where log lines go, chosen per platform.
///
/// The mobile app appends to `app_logs.txt` with single-generation rotation;
/// the web has no filesystem, so it keeps a bounded in-memory buffer for the
/// session. Both satisfy [LogSink], so `LoggerService` has no `dart:io` edge and
/// the thin web shell can import it.
library;

export 'log_sink_base.dart';
export 'log_sink_io.dart' if (dart.library.js_interop) 'log_sink_web.dart';
