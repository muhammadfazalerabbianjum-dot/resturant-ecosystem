/// P2-1a — the logger's directory TYPE, chosen per platform.
///
/// WHY a typedef instead of changing the parameter: `LoggerService` exposes
/// `Directory? testDirectory` and 106 call sites (mostly tests) pass a real
/// `dart:io` `Directory`. On the VM `LogDirectory` IS `Directory`, so every one
/// of those sites keeps compiling untouched; on the web it becomes a small path
/// holder, which is the only thing the web sink can use.
library;

export 'log_directory_io.dart'
    if (dart.library.js_interop) 'log_directory_web.dart';
