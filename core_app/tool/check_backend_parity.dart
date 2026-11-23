// P0-5 — per-client backend parity.
//
// The drift trap this closes: every client app carries a copy of the Firestore
// and Storage rules plus the index file under `apps/<client>/backend/`. Those
// copies are generated from `core_app/`, but nothing asserted that, so a rule
// fixed in one place and not the other produced a client whose deployed
// security posture silently differs from the template's.
//
// Usage (from core_app/):
//   dart run tool/check_backend_parity.dart          # check, exit 1 on divergence
//   dart run tool/check_backend_parity.dart --fix    # refresh the copies, exit 0
//
// Exit codes: 0 clean (or refreshed), 1 divergence found, 2 bad input/no backends.

import 'dart:io';

const List<String> _parityFiles = <String>[
  'firestore.rules',
  'storage.rules',
  'firestore.indexes.json',
];

void main(List<String> args) {
  final bool fix = args.contains('--fix');
  final unknown = args.where((String a) => a != '--fix').toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('ERROR: unknown argument(s): ${unknown.join(' ')}');
    stderr.writeln('Usage: dart run tool/check_backend_parity.dart [--fix]');
    exit(2);
  }

  // tool/ -> core_app/ -> repo root
  final Directory coreApp = File.fromUri(Platform.script).parent.parent;
  final Directory repoRoot = coreApp.parent;
  final String sep = Platform.pathSeparator;

  final List<File> sources = <File>[
    for (final String name in _parityFiles) File('${coreApp.path}$sep$name'),
  ];
  for (final File source in sources) {
    if (!source.existsSync()) {
      stderr.writeln('ERROR: canonical source missing: ${source.path}');
      exit(2);
    }
  }

  final Directory appsDir = Directory('${repoRoot.path}${sep}apps');
  if (!appsDir.existsSync()) {
    stderr.writeln('ERROR: no apps/ directory at ${appsDir.path}');
    exit(2);
  }

  final List<Directory> backends =
      appsDir
          .listSync()
          .whereType<Directory>()
          .map((Directory d) => Directory('${d.path}${sep}backend'))
          .where((Directory d) => d.existsSync())
          .toList()
        ..sort((Directory a, Directory b) => a.path.compareTo(b.path));

  if (backends.isEmpty) {
    // Loud, not silent: with no backend to compare, "no divergence found" would
    // be a green gate that checked nothing.
    stderr.writeln(
      'ERROR: found no apps/*/backend directories — nothing to verify.',
    );
    exit(2);
  }

  int divergences = 0;
  int refreshed = 0;

  for (final Directory backend in backends) {
    for (final String name in _parityFiles) {
      final File source = File('${coreApp.path}$sep$name');
      final File target = File('${backend.path}$sep$name');
      final String label =
          '${backend.path.substring(repoRoot.path.length + 1)}$sep$name';

      if (!target.existsSync()) {
        divergences++;
        stdout.writeln('MISSING  $label');
        if (fix) {
          target.writeAsBytesSync(source.readAsBytesSync());
          refreshed++;
          stdout.writeln('CREATED  $label');
        }
        continue;
      }

      final List<int> want = source.readAsBytesSync();
      final List<int> have = target.readAsBytesSync();
      if (_bytesEqual(want, have)) {
        stdout.writeln('identical $label');
        continue;
      }

      divergences++;
      stdout.writeln(
        'DIVERGENT $label '
        '(${have.length} bytes vs canonical ${want.length})',
      );
      if (fix) {
        target.writeAsBytesSync(want);
        refreshed++;
        stdout.writeln('REFRESHED $label');
      }
    }
  }

  if (fix) {
    stdout.writeln(
      refreshed == 0
          ? 'parity: nothing to refresh, already byte-identical.'
          : 'parity: refreshed $refreshed file(s) from core_app/.',
    );
    exit(0);
  }

  if (divergences > 0) {
    stderr.writeln(
      'parity: $divergences file(s) differ from core_app/. '
      'Run `dart run tool/check_backend_parity.dart --fix` to refresh them.',
    );
    exit(1);
  }

  stdout.writeln(
    'parity: all ${backends.length} backend bundle(s) byte-identical to core_app/.',
  );
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
