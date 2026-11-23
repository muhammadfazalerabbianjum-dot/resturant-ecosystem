// P2-1a (D-050) — the shell's import boundary, enforced mechanically.
//
// WHY this exists: the defect that killed the P2-0 spike was an INVISIBLE
// transitive edge (barrel → cache → `isar_community`, which has no web
// platform). No amount of reading `lib/shell/` would have caught it, and a
// README note would not have stopped it coming back. This walks the imports
// from the shell entrypoint and fails on any path to a native-only package, to
// `dart:io`, or to the `package:core/core.dart` barrel.
//
// CONDITIONAL DIRECTIVES are evaluated for a WEB build, not read literally:
// `export 'a.dart' if (dart.library.js_interop) 'b.dart'` resolves to `b.dart`
// here. That is not a loophole — it is the mechanism that lets shared code be
// platform-safe (the logger's sink), and treating both branches as reachable
// would make every correctly-guarded file look illegal.
//
// The regexes below embed both quote kinds, so they are triple-double-quoted
// raw strings; the single-quote style rule does not apply to them.
// ignore_for_file: prefer_single_quotes
//
// Usage (from `core_app`):
//   dart run tool/check_shell_imports.dart [entry]      # default lib/shell/main.dart
// Exit codes: 0 clean, 1 violation found, 2 usage/setup error.
import 'dart:io';

/// Packages that cannot exist in a web build. Kept as package NAMES (not files)
/// so a new file inside one of them cannot slip past.
const Set<String> _forbiddenPackages = <String>{
  'isar',
  'isar_community',
  'isar_community_flutter_libs',
  'isar_flutter_libs',
  'sqflite',
  'path_provider',
};

/// Whole-library imports banned outright: the barrel re-exports the native
/// cache, so importing it silently re-introduces the P2-0 edge.
const Set<String> _forbiddenExact = <String>{'package:core/core.dart'};

/// `packages/core` modules that touch Isar (the 7 files measured for P2-1a).
/// Naming them keeps the boundary true even if a barrel export is re-added.
const Set<String> _forbiddenCoreModules = <String>{
  'src/cache/isar_schemas.dart',
  'src/cache/isar_schemas.g.dart',
  'src/cache/isar_service.dart',
  'src/cache/isar_local_cache.dart',
  'src/kitchen/kitchen_offline_service.dart',
  'src/network/sync_queue.dart',
  'src/network/pending_sync_provider.dart',
};

final RegExp _token = RegExp(r"""'([^']+)'|if\s*\(([^)]+)\)""");

/// A WHOLE directive, including conditional branches that wrap onto following
/// lines (formatters do that). Parsing line-by-line silently dropped the
/// conditional and read the VM branch as reachable on the web.
///
/// Combinators (`show`, `hide`, `as x`) are part of the statement and MUST be
/// accepted: the first revision of this regex did not, so it skipped ~90 % of
/// directives and PASSED VACUOUSLY (1 file reachable). A checker that cannot
/// fail is worse than none, which is why the reachable-file count is printed
/// and the negative case is part of the card's proof.
final RegExp _directive = RegExp(
  r"""(?:import|export|part)\s+"""
  r"""(?:'[^']+'(?:\s*if\s*\([^)]*\)\s*'[^']+')*)"""
  r"""(?:\s+(?:show|hide)\s+[^;]+|\s+as\s+[A-Za-z_$][\w$]*)?\s*;""",
);

void main(List<String> args) {
  final projectRoot = File.fromUri(Platform.script).parent.parent;
  final entryArg = args.isNotEmpty ? args.first : 'lib/shell/main.dart';
  final entry = File('${projectRoot.path}/$entryArg');
  if (!entry.existsSync()) {
    stderr.writeln('SETUP: entry not found: ${entry.path}');
    exit(2);
  }

  final packages = <String, String>{
    'labs': '${projectRoot.path}/lib',
    'core': '${projectRoot.parent.path}/packages/core/lib',
    'core_ui': '${projectRoot.parent.path}/packages/core_ui/lib',
  };

  final visited = <String>{entry.absolute.path};
  final parentOf = <String, String>{};
  final violations = <String>[];
  final externals = <String>{};
  final queue = <String>[entry.absolute.path];

  while (queue.isNotEmpty) {
    final path = queue.removeLast();
    final file = File(path);
    if (!file.existsSync()) continue;
    final source = file.readAsStringSync();

    for (final directive in _directive.allMatches(source)) {
      final text = directive.group(0)!;
      final chain = _chainTo(parentOf, path);

      if (text.contains("'dart:io'")) {
        violations.add(
          'FORBIDDEN dart:io (no web platform)\n'
          '  via ${[...chain, 'dart:io'].join(' -> ')}',
        );
        continue;
      }

      final target = _chosenTarget(text);
      if (target == null || target.startsWith('dart:')) continue;

      if (_forbiddenExact.contains(target)) {
        violations.add(
          'FORBIDDEN BARREL  $target\n  via ${[...chain, target].join(' -> ')}',
        );
        continue;
      }

      if (target.startsWith('package:')) {
        final rest = target.substring('package:'.length);
        final slash = rest.indexOf('/');
        if (slash < 0) continue;
        final pkg = rest.substring(0, slash);
        final libPath = rest.substring(slash + 1);

        if (_forbiddenPackages.contains(pkg)) {
          violations.add(
            'FORBIDDEN PACKAGE $pkg\n'
            '  via ${[...chain, target].join(' -> ')}',
          );
          continue;
        }
        if (pkg == 'core' && _forbiddenCoreModules.contains(libPath)) {
          violations.add(
            'FORBIDDEN MODULE  package:core/$libPath (touches Isar)\n'
            '  via ${[...chain, target].join(' -> ')}',
          );
          continue;
        }
        final root = packages[pkg];
        if (root == null) {
          externals.add(pkg);
          continue;
        }
        final resolved = '$root/$libPath';
        if (!visited.add(resolved)) continue;
        parentOf[resolved] = path;
        queue.add(resolved);
        continue;
      }

      final resolved = _resolveRelative(file.parent.path, target);
      if (resolved == null) {
        stderr.writeln('WARN: unresolvable relative import "$target" in $path');
        continue;
      }
      if (!visited.add(resolved)) continue;
      parentOf[resolved] = path;
      queue.add(resolved);
    }
  }

  stdout.writeln('shell import graph: ${visited.length} file(s) reachable');
  stdout.writeln(
    'external packages: ${(externals.toList()..sort()).join(', ')}',
  );

  if (violations.isEmpty) {
    stdout.writeln(
      'PASS: no Isar, no dart:io and no core barrel on any shell path',
    );
    exit(0);
  }
  stdout.writeln('FAIL: ${violations.length} violation(s)');
  for (final v in violations) {
    stdout.writeln('- $v');
  }
  exit(1);
}

/// The target a conditional directive means FOR A WEB BUILD.
///
/// Syntax: `export 'default' if (cond1) 'alt1' if (cond2) 'alt2';`
/// A condition is applied in order; the last one true on web wins.
String? _chosenTarget(String directive) {
  String? chosen;
  String? pendingCondition;
  for (final m in _token.allMatches(directive)) {
    final path = m.group(1);
    final condition = m.group(2);
    if (condition != null) {
      pendingCondition = condition;
      continue;
    }
    if (path == null) continue;
    if (chosen == null) {
      chosen = path; // the default target
    } else if (pendingCondition != null &&
        _conditionTrueOnWeb(pendingCondition)) {
      chosen = path;
    }
    pendingCondition = null;
  }
  return chosen;
}

/// True for the conditions a dart2js build satisfies. Everything else (`io`,
/// `ffi`, `indexed_db`) is false on the web.
bool _conditionTrueOnWeb(String condition) {
  final c = condition.replaceAll(' ', '');
  return c == 'dart.library.js_interop' ||
      c == 'dart.library.html' ||
      c == 'dart.library.js_util';
}

String? _resolveRelative(String baseDir, String target) {
  final segments = <String>[];
  for (final part in '$baseDir/$target'.split('/')) {
    if (part == '.' || part.isEmpty) continue;
    if (part == '..') {
      if (segments.isNotEmpty) segments.removeLast();
      continue;
    }
    segments.add(part);
  }
  var path = segments.join('/');
  if (!path.endsWith('.dart')) path = '$path.dart';
  if (path.startsWith('A:') || path.startsWith('C:')) {
    path = path.replaceFirst(':', ':/');
  }
  return path;
}

List<String> _chainTo(Map<String, String> parentOf, String path) {
  final chain = <String>[_shorten(path)];
  var cursor = path;
  var guard = 0;
  while (parentOf.containsKey(cursor) && guard++ < 500) {
    cursor = parentOf[cursor]!;
    chain.insert(0, _shorten(cursor));
  }
  return chain;
}

String _shorten(String path) {
  const marker = '/packages/';
  final idx = path.indexOf(marker);
  if (idx >= 0) return 'packages/${path.substring(idx + marker.length)}';
  final libs = path.indexOf('/lib/');
  if (libs >= 0) return 'lib/${path.substring(libs + '/lib/'.length)}';
  return path;
}
