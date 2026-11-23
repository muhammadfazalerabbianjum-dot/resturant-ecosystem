// FIX-B1 (boot-env-guard) shared boot harness — HELPERS ONLY.
// (Not a *_test.dart file: `flutter test` never collects it.)
//
// Mirrors the proven pattern of test/app_bootstrap_states_test.dart: run the
// REAL production `initCarnamaApp` chain against a RECORDING Firebase
// platform double (call evidence for the fail-closed gates), a captured
// debugPrint surface (the gates' FATAL messages) and offset-tracked crash/
// boot logs.
//
// FIX-B7 T-1 (F-W4-01) — DETERMINISM LAW (§0.7): the `systemTemp` log files
// are MACHINE-GLOBAL and ever-appending: they are shared by every test file
// in this suite, by every sibling worktree's run and by every previous run.
// An assertion that reads them whole can therefore fail (or pass) because of
// state this test never wrote — a defect, not a flake. So [BootHarness] now
// OWNS that state per install/restore cycle:
//   * install() snapshots the generations it is about to touch and starts
//     from an EMPTY log, so [freshBootLog]/[freshCrashLog] can only ever
//     return bytes the boot under test itself wrote;
//   * restore() puts the snapshots back byte-for-byte, so the harness neither
//     destroys another process's post-mortem evidence nor leaks its own;
//   * the byte offsets are still snapshotted (defence in depth: even if the
//     files are held open by a concurrent process and the delete fails, a
//     marker written BEFORE this boot is still outside the window).
// No test in the fleet may assert on state that survives a run.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:labs/app_bootstrap.dart';

/// A [FirebasePlatform] double that RECORDS every `initializeApp` attempt —
/// same contract as the copy in app_bootstrap_states_test.dart: the
/// fail-closed assertions need exact call evidence (unlike
/// `mock_firebase.dart`, whose `apps` is permanently non-empty, which would
/// make `Firebase.apps.isEmpty` unobservable).
class RecordingFirebasePlatform extends FirebasePlatform {
  final List<FirebaseOptions> initializeAppCalls = <FirebaseOptions>[];
  Object? throwOnInitializeApp;

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) =>
      FirebaseAppPlatform(
        name,
        const FirebaseOptions(
          apiKey: 'recording-platform-key',
          appId: 'recording-app-id',
          messagingSenderId: 'recording-sender',
          projectId: 'recording-project',
        ),
      );

  @override
  List<FirebaseAppPlatform> get apps => <FirebaseAppPlatform>[];

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    initializeAppCalls.add(
      options ??
          const FirebaseOptions(
            apiKey: 'recording-platform-key',
            appId: 'recording-app-id',
            messagingSenderId: 'recording-sender',
            projectId: 'recording-project',
          ),
    );
    final Object? failure = throwOnInitializeApp;
    if (failure != null) {
      throw failure;
    }
    return app(name ?? defaultFirebaseAppName);
  }
}

/// The shell's fail-closed blocking screen key (W6.1 vocabulary).
const ValueKey<String> blockedScreenKey = ValueKey<String>(
  'boot-blocked-shell-screen',
);

/// The shell's W6.1 blocking screen ("Firebase configuration missing —
/// contact the operator").
Widget shellBlockingScreen() => const Scaffold(
  key: blockedScreenKey,
  body: Text('Firebase configuration missing - contact the operator'),
);

/// Caller [FirebaseOptions] for a boot under test. [projectId] defaults to a
/// REAL-looking id so the placeholder gate can be exercised both ways
/// (default survives vs resolved-placeholder must be caught).
FirebaseOptions bootOptions({
  required String apiKey,
  String projectId = 'boot-test-default-project',
}) => FirebaseOptions(
  apiKey: apiKey,
  appId: 'boot-test-default-app',
  messagingSenderId: 'boot-test-default-sender',
  projectId: projectId,
);

/// Builds the [CarnamaBootstrap] for a boot under test. Template policy
/// (logged-continue, no key gate) unless [errorScreen] supplies the shell's
/// fail-closed blocking screen.
CarnamaBootstrap bootstrapFor({
  required FirebaseOptions options,
  bool loadEnv = false,
  Widget Function()? errorScreen,
}) => CarnamaBootstrap(
  firebaseOptions: options,
  coreConfig: const DefaultCoreConfig(),
  appBuilder: () => const SizedBox.shrink(),
  loadEnv: loadEnv,
  firebaseErrorScreenBuilder: errorScreen,
);

/// One install/restore cycle per test (wire as setUp/tearDown).
class BootHarness {
  final RecordingFirebasePlatform platform = RecordingFirebasePlatform();
  final List<String> debugPrintLines = <String>[];

  late void Function(String?, {int? wrapWidth}) _originalDebugPrint;
  int _bootLogOffset = 0;
  int _crashLogOffset = 0;

  // T-FLAKE-1: every path below resolves `bootLogDirectoryForTest()` (from
  // `package:labs/app_bootstrap.dart` — the SAME function the boot logger's
  // FLUTTER_TEST branch uses). Per-PID isolation: four test FILES run as four
  // parallel processes, and the old machine-global `%TEMP%` files let one
  // harness's snapshot/restore delete another's bytes mid-test.
  static String get _bootLogPath =>
      '${bootLogDirectoryForTest().path}/app_logs.txt';

  /// The rotated generation (`LoggerService` keeps exactly one).
  static String get _rotatedBootLogPath =>
      '${bootLogDirectoryForTest().path}/app_logs.1.txt';

  static String get _crashLogPath =>
      '${bootLogDirectoryForTest().path}/carnama_fatal_crash.log';

  /// Public mirrors for the T-FLAKE-1 isolation-contract test — pinning that
  /// the harness reads the exact per-process files the boot logger writes.
  static String get bootLogPathForTest => _bootLogPath;
  static String get crashLogPathForTest => _crashLogPath;

  /// Every log file a boot under test can write to (all process-private now).
  static List<String> get _sharedLogPaths => <String>[
    _bootLogPath,
    _rotatedBootLogPath,
    _crashLogPath,
  ];

  /// FIX-B7 T-1: pre-test bytes per shared log file (null = did not exist).
  final Map<String, List<int>?> _sharedLogSnapshots = <String, List<int>?>{};

  static Future<int> _length(String path) async {
    final File file = File(path);
    return file.existsSync() ? await file.length() : 0;
  }

  /// Takes OWNERSHIP of the shared log files: snapshot + clear. Tolerates a
  /// concurrent process holding a file open — the offset snapshot that
  /// follows still keeps this boot's window honest.
  Future<void> _ownSharedLogs() async {
    _sharedLogSnapshots.clear();
    for (final String path in _sharedLogPaths) {
      final File file = File(path);
      _sharedLogSnapshots[path] = file.existsSync()
          ? await file.readAsBytes()
          : null;
      try {
        if (file.existsSync()) await file.delete();
      } catch (_) {
        // Windows can refuse the delete while another process has the file
        // open. Never fail the test on it: the offset below excludes every
        // byte that was already there.
      }
    }
  }

  /// Releases ownership: restore the pre-test bytes verbatim (or delete a
  /// generation that did not exist), so nothing this harness did can leak
  /// into the next file/run.
  Future<void> _releaseSharedLogs() async {
    for (final MapEntry<String, List<int>?> entry
        in _sharedLogSnapshots.entries) {
      final File file = File(entry.key);
      final List<int>? snapshot = entry.value;
      try {
        if (snapshot == null) {
          if (file.existsSync()) await file.delete();
        } else {
          await file.writeAsBytes(snapshot, flush: true);
        }
      } catch (_) {
        // Best effort: cleanup must never turn a green test red.
      }
    }
    _sharedLogSnapshots.clear();
  }

  /// Swaps in the recording platform + captured debugPrint, clears the
  /// machine-global log generations (see the file header) and snapshots the
  /// (now empty — or, if the clear was refused, already-written) offsets
  /// BEFORE the boot under test runs.
  Future<void> install() async {
    platform.initializeAppCalls.clear();
    platform.throwOnInitializeApp = null;
    FirebasePlatform.instance = platform;
    Firebase.delegatePackingProperty = null;
    debugPrintLines.clear();
    _originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      debugPrintLines.add(message ?? '');
    };
    await _ownSharedLogs();
    _bootLogOffset = await _length(_bootLogPath);
    _crashLogOffset = await _length(_crashLogPath);
  }

  /// Restores the real debugPrint + Firebase platform and hands the shared
  /// log files back exactly as they were found (tearDown contract).
  Future<void> restore() async {
    debugPrint = _originalDebugPrint;
    Firebase.delegatePackingProperty = null;
    PushNotificationService.resetForTest();
    await _releaseSharedLogs();
  }

  /// Runs [body] inside a guarded zone — the SAME containment pattern the
  /// production chain uses (STEP 02) and app_bootstrap_states_test asserts
  /// with: async plugin noise from the mounted app must not fail the boot
  /// assertions under the test host.
  Future<T> runBoot<T>(Future<T> Function() body) {
    final Completer<T> completer = Completer<T>();
    runZonedGuarded(() {
      body().then(completer.complete, onError: completer.completeError);
    }, (Object error, StackTrace stack) {});
    return completer.future;
  }

  /// The boot-under-test's OWN logger bytes: written between [install] and
  /// now, inside the empty generation [install] created. Residue from a
  /// previous run / sibling worktree can never appear here (F-W4-01), and if
  /// the clear was refused the offset window still excludes it.
  Future<String> freshBootLog() async =>
      _readSince(_bootLogPath, _bootLogOffset);

  /// `handleBootFailure`'s fatal-crash bytes written inside this harness's
  /// owned window (the file is opened with FileMode.append, so offsets are
  /// stable).
  Future<String> freshCrashLog() async =>
      _readSince(_crashLogPath, _crashLogOffset);

  static Future<String> _readSince(String path, int offset) async {
    final File file = File(path);
    if (!file.existsSync()) return '';
    final List<int> bytes = await file.readAsBytes();
    if (offset >= bytes.length) return '';
    return utf8.decode(bytes.sublist(offset), allowMalformed: true);
  }
}
