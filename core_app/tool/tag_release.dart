// ignore_for_file: avoid_print
//
// RELEASE-1 (W11.2): annotated release tag from the canonical version source.
//
// Usage (documented: run from core_app/ — the repo's tool home):
//   dart run tool/tag_release.dart             # create annotated tag v<version>
//   dart run tool/tag_release.dart --dry-run   # print what WOULD be created
//   dart run tool/tag_release.dart -m "msg"    # override the tag message
//
// Reads `pubspec.yaml` in the current directory and creates an annotated tag
// `v<major>.<minor>.<patch>+<build>` at HEAD. Fail-closed: exits non-zero
// when the version cannot be read or the tag already exists (release tags are
// immutable — never overwritten).
import 'dart:io';

const String kPubspecPath = 'pubspec.yaml';

/// Extracts the pubspec `version:` value (`major.minor.patch+build`), or null
/// when absent/malformed.
String? parseVersion(String pubspecContent) {
  final match = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$',
    multiLine: true,
  ).firstMatch(pubspecContent);
  return match?.group(1);
}

/// Tag name for a pubspec [version] (`1.2.3+4` → `v1.2.3+4`).
String tagNameFor(String version) => 'v$version';

Future<String> _git(List<String> args) async {
  final result = await Process.run('git', args);
  return result.stdout.toString().trim();
}

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  var message = 'Release <version>';
  final messageIndex = args.indexOf('-m');
  if (messageIndex != -1 && messageIndex + 1 < args.length) {
    message = args[messageIndex + 1];
  }

  final pubspecFile = File(kPubspecPath);
  if (!pubspecFile.existsSync()) {
    stderr.writeln(
      'tag_release: $kPubspecPath not found — run from core_app/ '
      '(the repo tool home).',
    );
    exit(2);
  }

  final version = parseVersion(pubspecFile.readAsStringSync());
  if (version == null) {
    stderr.writeln(
      'tag_release: could not parse `version:` from $kPubspecPath — '
      'expected <major.minor.patch+build> (e.g. 1.1.0+2).',
    );
    exit(1);
  }

  final tag = tagNameFor(version);
  message = message.replaceFirst('<version>', version);

  final head = await _git(['rev-parse', '--short', 'HEAD']);
  final existing = await _git(['tag', '-l', tag]);

  if (dryRun) {
    print('Would create annotated tag $tag at $head: "$message"');
    return;
  }

  if (existing == tag) {
    stderr.writeln(
      'tag_release: tag $tag already exists — refusing to overwrite '
      '(release tags are immutable).',
    );
    exit(1);
  }

  final result = await Process.run('git', ['tag', '-a', tag, '-m', message]);
  if (result.exitCode != 0) {
    stderr.writeln(
      'tag_release: git tag failed (exit ${result.exitCode}):\n${result.stderr}',
    );
    exit(result.exitCode);
  }
  print('Created annotated tag $tag at $head.');
}
