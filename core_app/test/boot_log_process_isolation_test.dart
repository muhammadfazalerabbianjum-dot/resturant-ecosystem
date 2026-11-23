// T-FLAKE-1 (RED→GREEN, Law 2) — boot-log PROCESS ISOLATION.
//
// Root cause (verified against source, not the stale DEFERRED hint): every
// boot-chain `logger.error` call IS awaited (app_bootstrap.dart L560/571/768/
// 784) and `LoggerService.error` awaits its file write — but under
// `FLUTTER_TEST` the boot logger sank into the MACHINE-GLOBAL
// `%TEMP%/app_logs.txt`. `flutter test` runs each test FILE in its own
// process, and four files share this harness (app_bootstrap_states, boot_env_t1,
// boot_env_t2, boot_shell_env_t3). Each harness install() snapshots+deletes
// and restore() overwrites-or-deletes that one file — a sibling process can
// delete or clobber a boot's lines between the write and `freshBootLog()`,
// returning `''` (~1 in 5 full-suite runs; DEFERRED T-FLAKE-1 evidence,
// tool_uilib/p37/battery.txt FLAKE block).
//
// The fix matches the codebase's own determinism law (§0.7 / p26 T-2
// temp_log_guard: "every test logger must sink into its OWN directory") and
// the boot chain's own comment ("Route test logs to the PROCESS temp
// directory"): a single per-PID directory, shared by the logger branch and
// the harness so both sides name the same file. Production (no FLUTTER_TEST)
// is untouched.
//
// RED before the fix: fails to compile — `bootLogDirectoryForTest` and the
// harness's public path getters do not exist yet.
import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app_bootstrap.dart';

import 'helpers/boot_env_harness.dart';

void main() {
  group('T-FLAKE-1 boot-log process isolation', () {
    test(
      'boot log directory is per-process — never the machine-global temp',
      () {
        final Directory dir = bootLogDirectoryForTest();
        expect(
          dir.path,
          isNot(equals(Directory.systemTemp.path)),
          reason:
              'the logger must sink into a SUBDIRECTORY, not the shared '
              'machine temp root where every run/sibling worktree collides',
        );
        expect(
          dir.path,
          contains('$pid'),
          reason:
              'keyed by PID: two `flutter test` processes can never target '
              'the same log file, so snapshot/restore in one process cannot '
              'delete another process\'s boot lines',
        );
      },
    );

    test('the harness reads the exact path the boot logger writes', () {
      expect(
        BootHarness.bootLogPathForTest,
        '${bootLogDirectoryForTest().path}/app_logs.txt',
        reason:
            'single source of truth: logger and harness must name the '
            'same file or freshBootLog() reads nothing',
      );
      expect(
        BootHarness.crashLogPathForTest,
        startsWith('${bootLogDirectoryForTest().path}/'),
        reason:
            'the fatal-crash log has the same shared-file defect class '
            '(boot_env_t1_test asserts freshCrashLog) — same isolation',
      );
      expect(BootHarness.crashLogPathForTest, endsWith('_fatal_crash.log'));
    });

    test(
      'a sibling clobbering the old shared path cannot erase boot lines',
      () async {
        final LoggerService logger = LoggerService(
          testDirectory: bootLogDirectoryForTest(),
        );
        await logger.init();
        await logger.info(
          const <String, dynamic>{},
          'FirebaseInitError: seeded',
        );

        // Simulate a parallel harness process doing restore() on the old
        // machine-global file: overwrite + delete.
        final File shared = File('${Directory.systemTemp.path}/app_logs.txt');
        await shared.writeAsString('SIBLING RESTORE CLOBBER\n');
        await shared.delete();

        final String readBack = await File(
          '${bootLogDirectoryForTest().path}/app_logs.txt',
        ).readAsString();
        expect(
          readBack,
          contains('FirebaseInitError: seeded'),
          reason:
              'the boot\'s own bytes live in a process-private directory '
              '— a sibling\'s snapshot-restore can never make freshBootLog() '
              'return empty',
        );
      },
    );
  });
}
