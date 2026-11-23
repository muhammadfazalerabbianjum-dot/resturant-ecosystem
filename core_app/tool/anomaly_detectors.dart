/// UI-16 (p26) T-1 — the committed anomaly harness for classes 3, 5, 6, 8, 9.
///
/// Fleet contract (`ANOMALY_CLASS_PLAYBOOK.md:32`, fleet row
/// `AUDIT_FLEET_13CLASSES.md:103`): the classes are re-checked by a committed
/// script + repo test so they cannot silently reappear at a batch close or at
/// a client onboarding.
///
/// Detector -> class -> playbook row:
///   d3 `:9`  divergent twins        — two implementations of one concept with
///                                      no parity citation
///   d5 `:11` orphaned deferral      — a deferral line in a spec that names no
///                                      file existing on disk (S5-01 closed)
///   d6 `:12` unconfigured mechanism — an engine-read key with neither a value
///                                      in a shipped config, nor a written
///                                      allowlist reason, nor a disposition row
///   d8 `:14` uncovered surface      — a surface row with no owning spec file
///                                      (zero unassigned rows); emits the
///                                      surface x wave matrix
///   d9 `:15` hand-rolled density    — adoption-gap density regressing above
///                                      the register §2 dispatch baseline
///
/// Dispositions: every candidate that fires must be declared in
/// `core_app/test/tool/fixtures/p26/dispositions.json` with status
/// `FIXED | OPERATOR-ACCEPTED | SPEC'D | FALSE-POSITIVE` — nothing dies
/// unexplained (playbook `:3`). Exit codes: 0 = clean or every candidate
/// declared; 1 = an undeclared candidate; 2 = unreadable/invalid
/// dispositions or bad usage.
///
/// Reuse (L-P26-3, never fork): d6 PARSES p25's own artifacts —
/// `client_config_engine_key_matrix_test.dart` (engineKeys + allowlist +
/// shippedConfigs) and `config_key_disposition_test.dart`
/// (dispositionRegister) — pinned by an import-parity test; d8 consumes the
/// ladder/register/dispatch row data as written; d9 baselines cite
/// `AUDIT_TRIAGE_STAGE3.md` §2 by line. The harness reports the COMPOSITION
/// across those sources and never re-gates what CI already gates alone.
///
/// Run from `core_app/`: `dart run tool/anomaly_detectors.dart`
///   [--root=<repo-root>] [--dispositions=<json>] [--emit-matrix=<md>]
///   [--help]
library;

import 'dart:convert';
import 'dart:io';

/// Detector ids in report order.
const List<String> kDetectorIds = <String>['d3', 'd5', 'd6', 'd8', 'd9'];

/// The four dispositions a candidate may carry (playbook `:3`).
const Set<String> kValidDispositions = <String>{
  'FIXED',
  'OPERATOR-ACCEPTED',
  "SPEC'D",
  'FALSE-POSITIVE',
};

/// One detector finding. [key] is the identity a declaration must carry.
class Candidate {
  const Candidate(this.detector, this.id, this.detail);

  final String detector;
  final String id;
  final String detail;

  String get key => '$detector:$id';
}

/// A declared disposition for a candidate key.
class Disposition {
  const Disposition(this.status, this.note);

  final String status;
  final String note;
}

/// Result of one detector run: the candidates it fired plus its report body.
class DetectorOutcome {
  const DetectorOutcome(this.candidates, this.report);

  final List<Candidate> candidates;
  final String report;
}

// ─────────────────────────── shared helpers ────────────────────────────────

/// Normalize line endings so line-oriented parsing behaves identically on the
/// CRLF checkouts this repo uses on Windows.
String normalizeEol(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

/// Read a UTF-8 text file with normalized line endings.
String readText(String path) => normalizeEol(File(path).readAsStringSync());

/// All `*.dart` files under [dir], sorted for deterministic output.
List<String> dartFilesUnder(String dir) {
  final root = Directory(dir);
  if (!root.existsSync()) {
    throw FileSystemException('source root missing', dir);
  }
  final out = <String>[];
  for (final entity in root.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      out.add(entity.path);
    }
  }
  return out..sort();
}

/// Paths of the `WHITE_LABEL_*.md` spec files at [repoRoot], sorted.
List<String> specFilesUnder(String repoRoot) {
  final out = <String>[];
  for (final entity in Directory(repoRoot).listSync()) {
    if (entity is File) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.startsWith('WHITE_LABEL_') && name.endsWith('.md')) {
        out.add(entity.path);
      }
    }
  }
  return out..sort();
}

/// Walk up from [start] to the repo root: the directory that contains both
/// `core_app/` and `packages/`.
String findRepoRoot(String start) {
  final sep = Platform.pathSeparator;
  var dir = Directory(start).absolute;
  while (true) {
    if (Directory(
          '${dir.path}$sep'
          'core_app',
        ).existsSync() &&
        Directory(
          '${dir.path}$sep'
          'packages',
        ).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw FileSystemException('repo root not found above', start);
    }
    dir = parent;
  }
}

// ───────────────────── d3 — divergent twins (class 3) ──────────────────────

/// One documented concept whose parallel implementations must stay pinned by
/// a parity test.
class TwinConcept {
  const TwinConcept({
    required this.name,
    required this.tokens,
    required this.citations,
    required this.evidence,
  });

  /// Concept name (e.g. `money-format`).
  final String name;

  /// The parallel helper/class names, 2+ per concept.
  final List<String> tokens;

  /// Repo-relative parity-test files that pin the concept.
  final List<String> citations;

  /// Where the concept was documented (file:line).
  final String evidence;
}

/// The documented precedents the playbook and register already carry:
///   * money: `formatCurrencyCents` vs `moneyCents` (playbook `:9`,
///     register `AUD1-02`; unified as delegation + parity by B3),
///   * retry: `NetworkRetry` vs `IsarSyncQueue` fail-closed classification
///     (register `AUD1-03`; pinned by B5's parity suite).
const List<TwinConcept> kRealTwinConcepts = <TwinConcept>[
  TwinConcept(
    name: 'money-format',
    tokens: <String>['formatCurrencyCents', 'moneyCents'],
    citations: <String>[
      'core_app/test/app/config/currency_format_test.dart',
      'core_app/test/app/config/money_cldr_parity_test.dart',
    ],
    evidence: 'ANOMALY_CLASS_PLAYBOOK.md:9 (AUD1-02, fixed by B3)',
  ),
  TwinConcept(
    name: 'retry-classification',
    tokens: <String>['NetworkRetry', 'IsarSyncQueue'],
    citations: <String>['packages/core/test/retry_classifier_parity_test.dart'],
    evidence: 'AUDIT_TRIAGE_STAGE3.md:49 (AUD1-03, fixed by B5)',
  ),
];

/// Production source roots scanned for twin definitions.
const List<String> kProductionRoots = <String>[
  'core_app/lib',
  'packages/core/lib',
  'packages/core_ui/lib',
];

/// d3: a concept whose 2+ tokens are ALL still defined in production source
/// while NO cited parity file exists (or none mentions the tokens) is a live
/// divergent twin waiting to bite at an edge case.
DetectorOutcome detectDivergentTwins({
  required String repoRoot,
  List<TwinConcept>? concepts,
  List<String>? productionRoots,
}) {
  final roots = productionRoots ?? kProductionRoots;
  final sources = <String, String>{};
  for (final rel in roots) {
    final dir = '$repoRoot${Platform.pathSeparator}$rel';
    for (final file in dartFilesUnder(dir)) {
      sources[file] = readText(file);
    }
  }

  final candidates = <Candidate>[];
  final toCheck = concepts ?? kRealTwinConcepts;
  for (final concept in toCheck) {
    final defined = <String>[];
    for (final token in concept.tokens) {
      final asFunction = RegExp(
        '(?:^|\\n)[A-Za-z_][\\w<>,\\s\\[\\]\\?]*\\s+$token\\s*\\(',
      );
      final asType = RegExp(
        '(?:^|\\n)\\s*(?:abstract\\s+)?(?:class|mixin|enum)\\s+$token\\b',
      );
      final hit = sources.values.any(
        (text) => asFunction.hasMatch(text) || asType.hasMatch(text),
      );
      if (hit) {
        defined.add(token);
      }
    }
    if (defined.length < 2) {
      continue; // not a live twin: fewer than two implementations remain
    }

    var citationOk = false;
    for (final citation in concept.citations) {
      final file = File('$repoRoot${Platform.pathSeparator}$citation');
      if (!file.existsSync()) {
        continue;
      }
      final text = readText(file.path);
      if (concept.tokens.any(text.contains)) {
        citationOk = true;
      }
    }
    if (!citationOk) {
      candidates.add(
        Candidate(
          'd3',
          concept.name,
          'tokens ${defined.join(', ')} are both defined in production '
              'source but no cited parity test exists or mentions them '
              '(documented at ${concept.evidence})',
        ),
      );
    }
  }

  final report = StringBuffer()
    ..writeln(
      'd3 divergent twins: ${toCheck.length} concepts checked, '
      '${sources.length} production files scanned, '
      '${candidates.length} candidate(s)',
    );
  return DetectorOutcome(candidates, report.toString());
}

// ───────────────────── d5 — orphaned deferrals (class 5) ───────────────────

/// Deferral phrase patterns a spec may use (playbook `:11`). Every matching
/// line must name at least one file that exists on disk — otherwise the
/// deferral points at nothing (the p20 -> "candidate p21" hole, closed by
/// S5-01). Patterns are case-insensitive; `candidate p\d` deliberately
/// requires the digit so UI copy like "candidate percentages" never matches.
const List<String> kDeferralPhrasePatterns = <String>[
  r'deferred to',
  r'candidate p\d',
  r'never written',
  r'unwritten',
  r'no such spec',
  r'to be authored',
  r'not yet written',
  r'no spec exists',
  r'ownerless',
  r'spec is missing',
  r'\bTBD\b',
];

final RegExp _refPattern = RegExp(
  r'[\w./\\-]+\.(?:md|dart|json|js|ts|yml|yaml)',
);
final RegExp _specIdPattern = RegExp(r'\bp\d{2}\b');

/// d5: scan every `WHITE_LABEL_*.md` spec for deferral phrases; a matching
/// line that resolves to NO existing file on disk is an orphaned deferral.
DetectorOutcome detectOrphanedDeferrals({required String repoRoot}) {
  final candidates = <Candidate>[];
  var hitLines = 0;
  final phrases = <RegExp>[
    for (final pattern in kDeferralPhrasePatterns)
      RegExp(pattern, caseSensitive: false),
  ];
  final specs = specFilesUnder(repoRoot);
  final specNames = specs
      .map((p) => p.split(Platform.pathSeparator).last)
      .toSet();

  for (final specPath in specs) {
    final name = specPath.split(Platform.pathSeparator).last;
    final lines = readText(specPath).split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isDeferral = phrases.any((phrase) => phrase.hasMatch(line));
      if (!isDeferral) {
        continue;
      }
      hitLines++;

      // A line resolves when it names a file that exists (path refs) or an
      // existing spec id (bare `pNN` references).
      var resolves = false;
      for (final match in _refPattern.allMatches(line)) {
        final ref = match.group(0)!;
        if (File('$repoRoot${Platform.pathSeparator}$ref').existsSync()) {
          resolves = true;
          break;
        }
      }
      if (!resolves) {
        for (final match in _specIdPattern.allMatches(line)) {
          final id = match.group(0)!;
          final owned = specNames.any(
            (n) =>
                n.startsWith('WHITE_LABEL_${id}_') || n == 'WHITE_LABEL_$id.md',
          );
          if (owned) {
            resolves = true;
            break;
          }
        }
      }
      if (!resolves) {
        final excerpt = line.trim();
        candidates.add(
          Candidate(
            'd5',
            '$name:${i + 1}',
            'deferral phrase with no file that exists on disk: '
                '${excerpt.length > 160 ? '${excerpt.substring(0, 160)}...' : excerpt}',
          ),
        );
      }
    }
  }

  final report = StringBuffer()
    ..writeln(
      'd5 orphaned deferrals: ${specs.length} specs scanned, '
      '$hitLines deferral line(s), ${candidates.length} candidate(s)',
    );
  return DetectorOutcome(candidates, report.toString());
}

// ──────────── d6 — mechanism exists but unconfigured (class 6) ─────────────

/// p25's engine-key artifacts, PARSED from the test files themselves so the
/// harness can never fork the key list (L-P26-3).
class ParsedEngineMatrix {
  const ParsedEngineMatrix({
    required this.engineKeys,
    required this.allowlist,
    required this.shippedConfigs,
  });

  /// Dotted paths read by the theme engine (from `engineKeys`).
  final List<String> engineKeys;

  /// `<config> -> <engine key> -> written reason` (from `allowlist`).
  final Map<String, Map<String, String>> allowlist;

  /// `<config> -> repo-relative config path` (from `shippedConfigs`).
  final Map<String, String> shippedConfigs;
}

/// Parse `client_config_engine_key_matrix_test.dart` source text.
ParsedEngineMatrix parseEngineMatrix(String source) {
  final engineKeys = RegExp(
    r"EngineKey\(\s*'([^']+)'",
    dotAll: true,
  ).allMatches(source).map((m) => m.group(1)!).toList();

  final allowlist = <String, Map<String, String>>{};
  var inAllowlist = false;
  String? section;
  final lines = source.split('\n');
  for (final line in lines) {
    if (RegExp(r'allowlist\s*=').hasMatch(line)) {
      inAllowlist = true;
      continue;
    }
    if (inAllowlist && line.trimRight() == '};') {
      inAllowlist = false;
      section = null;
      continue;
    }
    if (!inAllowlist) {
      continue;
    }
    final sectionMatch = RegExp(
      r"^\s*'(\w+)':\s*<String, String>\{",
    ).firstMatch(line);
    if (sectionMatch != null) {
      final name = sectionMatch.group(1);
      section = name;
      if (name != null) {
        allowlist.putIfAbsent(name, () => <String, String>{});
      }
      continue;
    }
    final keyMatch = RegExp(r"^\s{4}'([\w.]+)':").firstMatch(line);
    if (keyMatch != null && section != null) {
      allowlist[section]![keyMatch.group(1)!] = '';
    }
  }

  final shippedConfigs = <String, String>{};
  var inShipped = false;
  for (final line in lines) {
    if (RegExp(r'shippedConfigs\s*=').hasMatch(line)) {
      inShipped = true;
      continue;
    }
    if (inShipped && line.trimRight() == '};') {
      inShipped = false;
      continue;
    }
    if (!inShipped) {
      continue;
    }
    final pair = RegExp(r"^\s*'(\w+)':\s*'([^']+)'").firstMatch(line);
    if (pair != null) {
      shippedConfigs[pair.group(1)!] = pair.group(2)!;
    }
  }

  return ParsedEngineMatrix(
    engineKeys: engineKeys,
    allowlist: allowlist,
    shippedConfigs: shippedConfigs,
  );
}

/// Parse `config_key_disposition_test.dart` source text into
/// `<dotted path> -> <disposition name>`.
Map<String, String> parseKeyDispositionRegister(String source) {
  final rows = <String, String>{};
  final blocks = RegExp(
    r'KeyRow\((.*?)\n  \),',
    dotAll: true,
  ).allMatches(source);
  for (final block in blocks) {
    final body = block.group(1)!;
    final path = RegExp(r"path:\s*'([^']+)'").firstMatch(body);
    final disposition = RegExp(
      r'disposition:\s*KeyDisposition\.(\w+)',
    ).firstMatch(body);
    if (path != null && disposition != null) {
      rows[path.group(1)!] = disposition.group(1)!;
    }
  }
  return rows;
}

/// Value at a dotted path; any non-map hop yields null (= unset).
Object? configValueAt(Map<String, dynamic> root, String path) {
  Object? cursor = root;
  for (final key in path.split('.')) {
    if (cursor is! Map) {
      return null;
    }
    cursor = cursor[key];
  }
  return cursor;
}

/// d6: every engine-read key must carry a value in each shipped config, or
/// have a written allowlist reason (matrix test), or a disposition row
/// (disposition register) — anything else is silent degradation (class 6).
///
/// Source paths are overridable for fixtures; defaults point at p25's tests.
DetectorOutcome detectUnconfiguredKeys({
  required String repoRoot,
  String? matrixTestPath,
  String? dispositionTestPath,
}) {
  final matrixPath =
      matrixTestPath ??
      '$repoRoot/core_app/test/tool/'
          'client_config_engine_key_matrix_test.dart';
  final dispositionPath =
      dispositionTestPath ??
      '$repoRoot/core_app/test/tool/config_key_disposition_test.dart';

  final matrix = parseEngineMatrix(readText(matrixPath));
  final register = parseKeyDispositionRegister(readText(dispositionPath));

  final candidates = <Candidate>[];
  var keyChecks = 0;
  for (final entry in matrix.shippedConfigs.entries) {
    final configName = entry.key;
    final configFile = File('$repoRoot/core_app/${entry.value}');
    if (!configFile.existsSync()) {
      candidates.add(
        Candidate(
          'd6',
          '$configName:__config__',
          'shipped config missing: core_app/${entry.value}',
        ),
      );
      continue;
    }
    final config =
        jsonDecode(readText(configFile.path)) as Map<String, dynamic>;
    final allowed = matrix.allowlist[configName] ?? <String, String>{};
    for (final key in matrix.engineKeys) {
      keyChecks++;
      if (configValueAt(config, key) != null) {
        continue;
      }
      if (allowed.containsKey(key)) {
        continue;
      }
      if (register.containsKey(key)) {
        continue;
      }
      candidates.add(
        Candidate(
          'd6',
          '$configName:$key',
          'engine reads "$key" but $configName sets it nowhere and it has '
              'no allowlist reason (matrix test) nor disposition row '
              '(disposition register)',
        ),
      );
    }
  }

  final report = StringBuffer()
    ..writeln(
      'd6 unconfigured mechanism: ${matrix.engineKeys.length} engine keys x '
      '${matrix.shippedConfigs.length} configs = $keyChecks checks, '
      '${register.length} disposition rows reused, '
      '${candidates.length} candidate(s)',
    );
  return DetectorOutcome(candidates, report.toString());
}

// ──────────────────── d8 — uncovered surface (class 8) ─────────────────────

/// One surface row: ladder `M-*`/`W-*` rows or a register
/// "surfaces **UNASSIGNED**" row.
class SurfaceRow {
  const SurfaceRow(this.id, this.source, this.surfaces);

  final String id;
  final String source;
  final String surfaces;
}

/// A row of the emitted surface x wave matrix.
class SurfaceMatrixRow {
  const SurfaceMatrixRow(
    this.row, {
    required this.ownerFile,
    required this.wave,
    required this.unassignedReason,
  });

  final SurfaceRow row;

  /// Repo-relative spec file that owns the row, or null when unassigned.
  final String? ownerFile;

  /// Wave label from the dispatch plan (§5), or `—`.
  final String wave;

  /// Why the row has no owner (null = assigned).
  final String? unassignedReason;
}

/// d8 outcome: candidates plus the full matrix rows for rendering.
class SurfaceOutcome {
  const SurfaceOutcome(
    this.candidates,
    this.rows, {
    required this.ladderRows,
    required this.registerRows,
  });

  final List<Candidate> candidates;
  final List<SurfaceMatrixRow> rows;
  final int ladderRows;
  final int registerRows;
}

final RegExp _rowIdLine = RegExp(r'^\|\s*\**(M-\d+|W-\d+)\**\s*\|');
final RegExp _rangePattern = RegExp(r'\b([MW])-(\d+)\.\.([MW])-(\d+)');
final RegExp _singleIdPattern = RegExp(r'\b([MW]-\d+)\b');

/// Extract M-/W row ids from free text, expanding `M-1..M-6` ranges.
List<String> rowIdsIn(String text) {
  final cleaned = text.replaceAll('*', '').replaceAll('`', '');
  final ids = <String>{};
  for (final m in _rangePattern.allMatches(cleaned)) {
    final prefix = m.group(1)!;
    final start = int.parse(m.group(2)!);
    final end = int.parse(m.group(4)!);
    for (var i = start; i <= end; i++) {
      ids.add('$prefix-$i');
    }
  }
  final withoutRanges = cleaned.replaceAll(
    RegExp(r'\b[MW]-\d+\.\.[MW]-\d+'),
    ' ',
  );
  for (final m in _singleIdPattern.allMatches(withoutRanges)) {
    ids.add(m.group(1)!);
  }
  return ids.toList();
}

/// Surface rows from the coherence ladder §2 (M-*) and §3 (W-*).
List<SurfaceRow> parseLadderSurfaceRows(String text) {
  final rows = <SurfaceRow>[];
  for (final line in text.split('\n')) {
    final m = _rowIdLine.firstMatch(line);
    if (m == null) {
      continue;
    }
    final id = m.group(1)!;
    final cells = line.split('|').map((c) => c.trim()).toList();
    // split('|') => ['', id, cellA, cellB, cellC, ...]; §2 rows are
    // id | severity | surface | size | why; §3 rows are
    // id | component | needed-by | evidence.
    final surface = id.startsWith('M')
        ? (cells.length > 3 ? cells[3] : line)
        : (cells.length > 3 ? '${cells[2]} (needed by: ${cells[3]})' : line);
    rows.add(SurfaceRow(id, 'AUDIT_COHERENCE_LADDER.md', surface));
  }
  return rows;
}

/// Row-id -> owning spec id from the ladder §6 corrected queue.
Map<String, Set<String>> parseLadderOwnership(String text) {
  final owners = <String, Set<String>>{};
  final idx = text.indexOf('## §6');
  final section = idx >= 0 ? text.substring(idx) : '';
  for (final line in section.split('\n')) {
    if (!line.startsWith('|')) {
      continue;
    }
    final cells = line.split('|').map((c) => c.trim()).toList();
    if (cells.length < 4) {
      continue;
    }
    final specMatch = RegExp(r'p\d{2}[_a-z0-9]*').firstMatch(cells[1]);
    if (specMatch == null) {
      continue; // header row
    }
    final specId = specMatch.group(0)!;
    for (final id in rowIdsIn(cells[2])) {
      owners.putIfAbsent(id, () => <String>{}).add(specId);
    }
  }
  return owners;
}

/// Row-id -> owning spec id from spec-header territory claims
/// ("rows ... are this wave's territory").
Map<String, Set<String>> parseSpecTerritoryClaims(Iterable<String> specPaths) {
  final claims = <String, Set<String>>{};
  final claim = RegExp(r'rows\s+(.+?)\s+are\s+this\s+wave.s\s+territory');
  for (final path in specPaths) {
    final name = path.split(Platform.pathSeparator).last;
    final idMatch = RegExp(r'p\d{2}[_a-z0-9]*').firstMatch(name);
    if (idMatch == null) {
      continue;
    }
    final specId = idMatch.group(0)!;
    for (final line in readText(path).split('\n')) {
      final m = claim.firstMatch(line);
      if (m == null) {
        continue;
      }
      for (final rowId in rowIdsIn(m.group(1)!)) {
        claims.putIfAbsent(rowId, () => <String>{}).add(specId);
      }
    }
  }
  return claims;
}

/// Row-id -> owner token from register "surfaces **UNASSIGNED**" rows.
Map<String, String> parseRegisterSurfaceOwners(String text) {
  final owners = <String, String>{};
  for (final line in text.split('\n')) {
    if (!line.contains('surfaces **UNASSIGNED**')) {
      continue;
    }
    final idMatch = RegExp(r'^\|\s*`(F3-\d+)`').firstMatch(line);
    if (idMatch == null) {
      continue;
    }
    final cells = line
        .split('|')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    final owner = cells.last.replaceAll('`', '');
    owners[idMatch.group(1)!] = owner;
  }
  return owners;
}

/// Spec-id -> wave label from the dispatch plan §5 (plus the p17 flexible
/// fallback line).
Map<String, String> parseDispatchWaves(String text) {
  final waves = <String, String>{};
  for (final line in text.split('\n')) {
    final m = RegExp(r'^\|\s*\*\*W(\d+)').firstMatch(line);
    if (m == null) {
      continue;
    }
    final wave = 'W${m.group(1)!}';
    final cells = line.split('|').map((c) => c.trim()).toList();
    if (cells.length < 4) {
      continue;
    }
    for (final spec in RegExp(r'p\d{2}').allMatches(cells[3])) {
      waves.putIfAbsent(spec.group(0)!, () => wave);
    }
  }
  final flexible = RegExp(
    r'`(p\d{2})[_\w]*`\s+may slot into any wave\s+\*\*after\s+W(\d+)',
  ).firstMatch(text);
  if (flexible != null) {
    waves.putIfAbsent(
      flexible.group(1)!,
      () => 'post-W${flexible.group(2)} (flexible)',
    );
  }
  return waves;
}

/// Resolve an owner token (`p21`, `p21_adoption3`) to a spec file on disk.
String? resolveSpecFile(String repoRoot, String ownerToken) {
  for (final path in specFilesUnder(repoRoot)) {
    final name = path.split(Platform.pathSeparator).last;
    if (name == 'WHITE_LABEL_$ownerToken.md' ||
        name.startsWith('WHITE_LABEL_${ownerToken}_')) {
      return name;
    }
  }
  return null;
}

/// d8: every surface row must resolve to an owning spec file that exists on
/// disk (ladder §6 + spec territory claims + register owner column), and the
/// matrix carries the dispatch-plan wave for that owner. Unassigned or
/// conflicting rows are candidates; the report body is the matrix itself.
SurfaceOutcome detectUncoveredSurfaces({
  required String repoRoot,
  String? ladderPath,
  String? registerPath,
  String? dispatchPath,
}) {
  final ladder = readText(ladderPath ?? '$repoRoot/AUDIT_COHERENCE_LADDER.md');
  final register = readText(registerPath ?? '$repoRoot/AUDIT_TRIAGE_STAGE3.md');
  final dispatch = readText(dispatchPath ?? '$repoRoot/STAGE6_DISPATCH_W1.md');
  final specPaths = specFilesUnder(repoRoot);

  final ladderRows = parseLadderSurfaceRows(ladder);
  final registerOwners = parseRegisterSurfaceOwners(register);
  final registerRows = <SurfaceRow>[
    for (final id in registerOwners.keys)
      SurfaceRow(
        id,
        'AUDIT_TRIAGE_STAGE3.md',
        'register row (10 unassigned customer surfaces)',
      ),
  ];

  final owners = <String, Set<String>>{};
  void addOwners(Map<String, Set<String>> source) {
    source.forEach((id, specs) {
      owners.putIfAbsent(id, () => <String>{}).addAll(specs);
    });
  }

  addOwners(parseLadderOwnership(ladder));
  addOwners(parseSpecTerritoryClaims(specPaths));
  final waves = parseDispatchWaves(dispatch);

  final candidates = <Candidate>[];
  final rows = <SurfaceMatrixRow>[];
  final allRows = <SurfaceRow>[...ladderRows, ...registerRows];
  for (final row in allRows) {
    if (registerOwners.containsKey(row.id)) {
      owners.putIfAbsent(row.id, () => <String>{}).add(registerOwners[row.id]!);
    }
    final claimants = owners[row.id] ?? <String>{};
    String? ownerFile;
    String? reason;
    if (claimants.isEmpty) {
      reason =
          'no owning spec in ladder §6, spec territory claims, or the '
          'register owner column';
    } else if (claimants.length > 1) {
      reason = 'conflicting owners: ${claimants.join(', ')}';
    } else {
      ownerFile = resolveSpecFile(repoRoot, claimants.first);
      if (ownerFile == null) {
        reason = 'owner ${claimants.first} has no WHITE_LABEL_*.md on disk';
      }
    }
    if (reason != null) {
      candidates.add(Candidate('d8', row.id, reason));
    }
    final specNum = claimants.isEmpty
        ? null
        : RegExp(r'p\d{2}').firstMatch(claimants.first)?.group(0);
    rows.add(
      SurfaceMatrixRow(
        row,
        ownerFile: ownerFile,
        wave: specNum == null
            ? '—'
            : (waves[specNum] ?? 'not in dispatch plan'),
        unassignedReason: reason,
      ),
    );
  }

  return SurfaceOutcome(
    candidates,
    rows,
    ladderRows: ladderRows.length,
    registerRows: registerRows.length,
  );
}

/// Render the surface x wave matrix. Rows without an owner show their
/// reason — and, when a disposition declares them, that disposition — so the
/// committed matrix carries zero unassigned rows by construction of the
/// declarations, not by omission.
String renderSurfaceMatrix(
  SurfaceOutcome outcome,
  Map<String, Disposition> dispositions,
) {
  final buf = StringBuffer()
    ..writeln('# p26 surface × wave matrix (detector 8, class 8)')
    ..writeln()
    ..writeln(
      'Generated by `core_app/tool/anomaly_detectors.dart` (p26 T-1) '
      'from the register\'s own row data (L-P26-3):',
    )
    ..writeln()
    ..writeln('- `AUDIT_COHERENCE_LADDER.md` §2 (M-*) / §3 (W-*) / §6 (queue)')
    ..writeln(
      '- `AUDIT_TRIAGE_STAGE3.md` (unassigned-surface row(s), '
      'owner column)',
    )
    ..writeln('- `STAGE6_DISPATCH_W1.md` §5 (spec → wave plan)')
    ..writeln(
      '- spec-header territory claims (rows ... are this wave\'s '
      'territory)',
    )
    ..writeln()
    ..writeln(
      '| Surface row | Source | Surface(s) | Owning spec file | '
      'Wave (dispatch §5) | Disposition |',
    )
    ..writeln('|---|---|---|---|---|---|');
  for (final row in outcome.rows) {
    final key = 'd8:${row.row.id}';
    final disposition = dispositions[key];
    final owner = row.ownerFile ?? '—';
    final status = row.unassignedReason == null
        ? '—'
        : (disposition == null
              ? '**UNASSIGNED** (${row.unassignedReason})'
              : '${disposition.status} (declared; see dispositions.json)');
    buf.writeln(
      '| ${row.row.id} | ${row.row.source} | ${row.row.surfaces} | $owner | '
      '${row.wave} | $status |',
    );
  }
  buf
    ..writeln()
    ..writeln(
      'Rows: ${outcome.rows.length} '
      '(${outcome.ladderRows} ladder + ${outcome.registerRows} register). '
      'An UNASSIGNED cell means the row fired a d8 candidate that had no '
      'declaration at render time.',
    );
  return buf.toString();
}

// ──────────────────── d9 — hand-rolled density (class 9) ───────────────────

/// One adoption-gap token with its dispatch baseline (must never regress).
class DensityBaseline {
  const DensityBaseline(this.token, this.maxSites, this.maxFiles, this.cite);

  final String token;
  final int maxSites;
  final int maxFiles;
  final String cite;
}

/// Register §2 dispatch baseline for the F3 adoption-gap residuals:
/// spinner 76/33 (`:42`), ListTile 19/13, Card 15/10, raw TextField 12/4,
/// decorated Container 7/6 (`:74`); cross-checked against p21's L32
/// dispatch measurement (73/30 · 27/13 · 12/4 · 7/6). Measured with the
/// constructor-call rule below, non-increasing is the contract (p26 §3 T-1).
const List<DensityBaseline> kRealDensityBaselines = <DensityBaseline>[
  DensityBaseline(
    'CircularProgressIndicator',
    76,
    33,
    'AUDIT_TRIAGE_STAGE3.md:42 (F3-09)',
  ),
  DensityBaseline('ListTile', 19, 13, 'AUDIT_TRIAGE_STAGE3.md:74 (F3-10)'),
  DensityBaseline('Card', 15, 10, 'AUDIT_TRIAGE_STAGE3.md:74 (F3-11)'),
  DensityBaseline('TextField', 12, 4, 'AUDIT_TRIAGE_STAGE3.md:74 (F3-12)'),
  DensityBaseline('BoxDecoration', 7, 6, 'AUDIT_TRIAGE_STAGE3.md:74 (F3-15)'),
];

/// Count constructor-call sites of [token] in non-comment lines: the token
/// must start at a non-letter boundary and be followed by `(`, so
/// `BrandCard(`, `SwitchListTile(` and doc mentions never count.
int constructorSites(String text, String token) {
  final pattern = RegExp('(?<![A-Za-z])${RegExp.escape(token)}\\s*\\(');
  var count = 0;
  for (final line in text.split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//') ||
        trimmed.startsWith('/*') ||
        trimmed.startsWith('*')) {
      continue;
    }
    count += pattern.allMatches(line).length;
  }
  return count;
}

/// d9: hand-rolled density per file; a token whose measured sites or files
/// exceed the register §2 dispatch baseline is a regression candidate.
DetectorOutcome detectDensityRegression({
  required String repoRoot,
  String libRoot = 'core_app/lib',
  List<DensityBaseline>? baselines,
}) {
  final files = dartFilesUnder('$repoRoot/$libRoot');
  final toCheck = baselines ?? kRealDensityBaselines;
  final candidates = <Candidate>[];
  final report = StringBuffer();

  for (final baseline in toCheck) {
    var sites = 0;
    var touched = 0;
    final hotFiles = <String>[];
    for (final file in files) {
      final content = readText(file);
      final n = constructorSites(content, baseline.token);
      if (n > 0) {
        sites += n;
        touched++;
        hotFiles.add('${file.split(Platform.pathSeparator).last}:$n');
      }
    }
    final over = sites > baseline.maxSites || touched > baseline.maxFiles;
    if (over) {
      candidates.add(
        Candidate(
          'd9',
          baseline.token,
          'hand-rolled density regressed: $sites site(s) in $touched file(s) '
              'vs dispatch baseline ${baseline.maxSites}/'
              '${baseline.maxFiles} (${baseline.cite}); hot files: '
              '${hotFiles.join(', ')}',
        ),
      );
    }
    report.writeln(
      'd9 ${baseline.token}: $sites site(s) / $touched file(s) vs baseline '
      '${baseline.maxSites}/${baseline.maxFiles} '
      '[${over ? 'REGRESSED' : 'non-increasing'}] (${baseline.cite})',
    );
  }
  report.writeln(
    'd9 hand-rolled density: ${files.length} files scanned, '
    '${candidates.length} candidate(s)',
  );
  return DetectorOutcome(candidates, report.toString());
}

// ────────────────────── declarations & orchestration ───────────────────────

/// Parse the dispositions JSON. Throws [FormatException] on any invalid
/// entry — a declaration with a bad status or an un-written note is noise.
Map<String, Disposition> parseDispositions(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('dispositions must be a JSON object');
  }
  final out = <String, Disposition>{};
  decoded.forEach((key, value) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('disposition "$key" must be an object');
    }
    final status = value['status'];
    final note = value['note'];
    if (status is! String || !kValidDispositions.contains(status)) {
      throw FormatException(
        'disposition "$key" has invalid status "$status" '
        '(expected one of ${kValidDispositions.join(', ')})',
      );
    }
    if (note is! String || note.trim().length < 20) {
      throw FormatException(
        'disposition "$key" needs a written note of >= 20 characters',
      );
    }
    out[key] = Disposition(status, note);
  });
  return out;
}

/// The verdict of one harness run.
class HarnessRun {
  const HarnessRun({
    required this.candidates,
    required this.reports,
    required this.undeclared,
    required this.stale,
    required this.matrix,
  });

  final List<Candidate> candidates;
  final Map<String, String> reports;
  final List<String> undeclared;
  final List<String> stale;
  final String? matrix;
}

/// Run detectors d3/d5/d6/d8/d9 over [repoRoot] and evaluate [dispositions]
/// against whatever fired. A detector that throws contributes an `ERROR`
/// candidate instead of taking the whole harness down.
HarnessRun runHarness({
  required String repoRoot,
  required Map<String, Disposition> dispositions,
}) {
  final candidates = <Candidate>[];
  final reports = <String, String>{};
  SurfaceOutcome? d8;
  String? matrix;

  try {
    final outcome = detectDivergentTwins(repoRoot: repoRoot);
    candidates.addAll(outcome.candidates);
    reports['d3'] = outcome.report.trimRight();
  } catch (e) {
    candidates.add(Candidate('d3', 'ERROR', 'detector failed: $e'));
    reports['d3'] = 'd3 ERROR: $e';
  }
  try {
    final outcome = detectOrphanedDeferrals(repoRoot: repoRoot);
    candidates.addAll(outcome.candidates);
    reports['d5'] = outcome.report.trimRight();
  } catch (e) {
    candidates.add(Candidate('d5', 'ERROR', 'detector failed: $e'));
    reports['d5'] = 'd5 ERROR: $e';
  }
  try {
    final outcome = detectUnconfiguredKeys(repoRoot: repoRoot);
    candidates.addAll(outcome.candidates);
    reports['d6'] = outcome.report.trimRight();
  } catch (e) {
    candidates.add(Candidate('d6', 'ERROR', 'detector failed: $e'));
    reports['d6'] = 'd6 ERROR: $e';
  }
  try {
    d8 = detectUncoveredSurfaces(repoRoot: repoRoot);
    candidates.addAll(d8.candidates);
    reports['d8'] =
        'd8 uncovered surface: ${d8.ladderRows} ladder row(s) + '
        '${d8.registerRows} register row(s), '
        '${d8.candidates.length} candidate(s)';
  } catch (e) {
    candidates.add(Candidate('d8', 'ERROR', 'detector failed: $e'));
    reports['d8'] = 'd8 ERROR: $e';
  }
  try {
    final outcome = detectDensityRegression(repoRoot: repoRoot);
    candidates.addAll(outcome.candidates);
    reports['d9'] = outcome.report.trimRight();
  } catch (e) {
    candidates.add(Candidate('d9', 'ERROR', 'detector failed: $e'));
    reports['d9'] = 'd9 ERROR: $e';
  }

  if (d8 != null) {
    matrix = renderSurfaceMatrix(d8, dispositions);
  }

  final firedKeys = candidates.map((c) => c.key).toSet();
  final undeclared = candidates
      .where((c) => !dispositions.containsKey(c.key))
      .map((c) => c.key)
      .toList();
  final stale = dispositions.keys.where((k) => !firedKeys.contains(k)).toList();

  return HarnessRun(
    candidates: candidates,
    reports: reports,
    undeclared: undeclared,
    stale: stale,
    matrix: matrix,
  );
}

// ─────────────────────────────────── CLI ───────────────────────────────────

const String _usage =
    'Usage: dart run tool/anomaly_detectors.dart\n'
    '  --root=<repo-root>        scan a different tree (fixtures)\n'
    '  --dispositions=<json>     declarations file (default:\n'
    '                            core_app/test/tool/fixtures/p26/'
    'dispositions.json)\n'
    '  --emit-matrix=<path>      write the surface x wave matrix (markdown)\n'
    '  --help                    this text\n'
    'Exit: 0 = clean / all candidates declared; 1 = undeclared candidate;\n'
    '      2 = bad usage or unreadable dispositions.';

/// CLI entry returning the process exit code. Exposed (rather than only
/// [main]) so the repo test can pin every exit path in-process.
int harnessMain(List<String> args, {StringSink? out, String? cwd}) {
  final sink = out ?? stdout;
  if (args.contains('--help') || args.contains('-h')) {
    sink.writeln(_usage);
    return 0;
  }

  String? root;
  String? dispoPath;
  String? emitPath;
  for (final arg in args) {
    if (arg.startsWith('--root=')) {
      root = arg.substring('--root='.length);
    } else if (arg.startsWith('--dispositions=')) {
      dispoPath = arg.substring('--dispositions='.length);
    } else if (arg.startsWith('--emit-matrix=')) {
      emitPath = arg.substring('--emit-matrix='.length);
    } else {
      sink.writeln('unknown argument: $arg');
      sink.writeln(_usage);
      return 2;
    }
  }

  String repoRoot;
  try {
    repoRoot = root ?? findRepoRoot(cwd ?? Directory.current.path);
  } catch (e) {
    sink.writeln('repo root not found: $e');
    return 2;
  }

  final sep = Platform.pathSeparator;
  final dispoFile =
      dispoPath ??
      '$repoRoot${sep}core_app${sep}test${sep}tool${sep}fixtures${sep}p26'
          '${sep}dispositions.json';
  Map<String, Disposition> dispositions;
  try {
    final file = File(dispoFile);
    if (file.existsSync()) {
      dispositions = parseDispositions(readText(file.path));
    } else {
      sink.writeln('dispositions file absent (treated as empty): $dispoFile');
      dispositions = <String, Disposition>{};
    }
  } catch (e) {
    sink.writeln('dispositions unreadable/invalid ($dispoFile): $e');
    return 2;
  }

  final run = runHarness(repoRoot: repoRoot, dispositions: dispositions);
  for (final id in kDetectorIds) {
    final report = run.reports[id];
    if (report != null) {
      sink.writeln(report);
    }
  }
  for (final candidate in run.candidates) {
    final disposition = dispositions[candidate.key];
    if (disposition == null) {
      sink.writeln('  UNDECLARED ${candidate.key}: ${candidate.detail}');
    } else {
      sink.writeln(
        '  declared ${candidate.key} [${disposition.status}]: '
        '${candidate.detail}',
      );
    }
  }
  for (final key in run.stale) {
    sink.writeln('  stale disposition (no candidate fired): $key');
  }
  if (emitPath != null) {
    File(
      emitPath,
    ).writeAsStringSync(run.matrix ?? 'd8 errored; no matrix available\n');
    sink.writeln('surface-wave matrix written: $emitPath');
  }
  if (run.undeclared.isNotEmpty) {
    sink.writeln('${run.undeclared.length} undeclared candidate(s) -> exit 1');
    return 1;
  }
  sink.writeln('all candidates declared -> exit 0');
  return 0;
}

/// `dart run tool/anomaly_detectors.dart` entry point.
void main(List<String> args) {
  exitCode = harnessMain(args);
}
