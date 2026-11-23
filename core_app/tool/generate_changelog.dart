// ignore_for_file: avoid_print
import 'dart:io';

/// Auto-generates CHANGELOG.md from conventional commits and bumps pubspec version.
/// Usage: dart run tool/generate_changelog.dart [patch|minor|major]
Future<void> main(List<String> args) async {
  final bumpType = args.isNotEmpty ? args.first : 'patch';

  // 1. Get commits since last tag
  final lastTag = await _run('git', ['describe', '--tags', '--abbrev=0']);
  final log = await _run('git', [
    'log',
    '$lastTag..HEAD',
    '--pretty=format:%s',
    '--no-merges',
  ]);

  if (log.trim().isEmpty) {
    print('No commits since last tag. Nothing to changelog.');
    return;
  }

  // 2. Parse conventional commits
  final lines = log.trim().split('\n');
  final features = lines.where((l) => l.startsWith('feat:')).toList();
  final fixes = lines.where((l) => l.startsWith('fix:')).toList();
  final chores = lines.where((l) => l.startsWith('chore:')).toList();

  // 3. Bump version in pubspec.yaml
  final pubspec = File('pubspec.yaml');
  var content = pubspec.readAsStringSync();
  final versionMatch = RegExp(
    r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)',
  ).firstMatch(content);
  if (versionMatch == null) {
    print('Could not parse version.');
    exit(1);
  }

  var major = int.parse(versionMatch.group(1)!);
  var minor = int.parse(versionMatch.group(2)!);
  var patch = int.parse(versionMatch.group(3)!);
  var build = int.parse(versionMatch.group(4)!);

  if (bumpType == 'major') {
    major++;
    minor = 0;
    patch = 0;
  } else if (bumpType == 'minor') {
    minor++;
    patch = 0;
  } else {
    patch++;
  }
  build++;

  final newVersion = '$major.$minor.$patch+$build';
  content = content.replaceFirst(
    versionMatch.group(0)!,
    'version: $newVersion',
  );
  pubspec.writeAsStringSync(content);
  print('✅ Version bumped to $newVersion');

  // 4. Write CHANGELOG.md
  final date = DateTime.now().toIso8601String().split('T').first;
  final entry = StringBuffer();
  entry.writeln('## [$newVersion] - $date\n');
  if (features.isNotEmpty) {
    entry.writeln('### Features');
    for (final f in features) {
      entry.writeln('- ${f.replaceFirst('feat: ', '')}');
    }
    entry.writeln();
  }
  if (fixes.isNotEmpty) {
    entry.writeln('### Bug Fixes');
    for (final f in fixes) {
      entry.writeln('- ${f.replaceFirst('fix: ', '')}');
    }
    entry.writeln();
  }
  if (chores.isNotEmpty) {
    entry.writeln('### Maintenance');
    for (final c in chores) {
      entry.writeln('- ${c.replaceFirst('chore: ', '')}');
    }
    entry.writeln();
  }

  final changelog = File('CHANGELOG.md');
  final existing = changelog.existsSync() ? changelog.readAsStringSync() : '';
  changelog.writeAsStringSync('${entry.toString()}$existing');
  print('✅ CHANGELOG.md updated.');
}

Future<String> _run(String cmd, List<String> args) async {
  final r = await Process.run(cmd, args, runInShell: true);
  return r.stdout.toString().trim();
}
