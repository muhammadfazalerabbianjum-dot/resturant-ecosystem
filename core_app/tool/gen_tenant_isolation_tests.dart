// P0-8 — generates the cross-tenant isolation suite and proves its completeness.
//
// Inputs:  firestore.rules (the only source of truth for what exists)
//          test/security/tenant_isolation_cases.json (the case registry)
// Output:  test/security/tenant_isolation.generated_test.dart (deterministic)
//
// Modes:
//   dart run tool/gen_tenant_isolation_tests.dart           # write the suite
//   dart run tool/gen_tenant_isolation_tests.dart --check   # gate (i): drift/completeness only
//
// Exit: 0 ok; 2 violation (unregistered collection, stale row, stale generated
// file, unknown status). It never writes in --check mode, so the gate cannot
// repair its own drift.
library;

import 'dart:convert';
import 'dart:io';

const String kRulesPath = 'firestore.rules';
const String kRegistryPath = 'test/security/tenant_isolation_cases.json';
const String kOutputPath = 'test/security/tenant_isolation.generated_test.dart';

const String kPendingTenancy = 'PENDING-TENANCY';
const String kActive = 'ACTIVE';

/// A row's same-tenant verdict: the suite asserts tenant A CAN read its own
/// document, or declares (with a reason) that no tenant-scoped principal can.
const String kSameTenantAllow = 'allow';
const String kSameTenantNone = 'none';

/// A top-level `match /collection/...` in firestore.rules sits at exactly four
/// spaces of indentation; the `match /databases/...` wrapper sits at two, and
/// nested rules deeper. Anchoring on four spaces is therefore what separates a
/// collection from its subcollections and from the database wrapper.
/// Any `match /...` at four spaces or deeper. Two spaces is the
/// `match /databases/{db}/documents` wrapper, which is not a rule path.
final RegExp _matchLine = RegExp(r'^ {4,}match /([A-Za-z0-9_/{}]+)');

class _RulePaths {
  final Set<String> collections = <String>{};
  final Set<String> nested = <String>{};
}

/// Classifies every match block into a top-level collection or a nested path.
///
/// Indentation alone is not enough: `notifications/{userId}` and
/// `notifications/{userId}/items/{itemId}` are SIBLINGS at four spaces, so a
/// "four spaces means top-level collection" rule collapsed two distinct rule
/// paths onto one registry row and gate (i) reported a completeness it did not
/// have. Classification therefore uses the path itself: two or more collection
/// segments is a nested path, one segment at six spaces is a child of the block
/// above it, and one segment at four spaces is a collection.
_RulePaths _pathsIn(String rules) {
  final _RulePaths paths = _RulePaths();
  String? parent;
  for (final String line in const LineSplitter().convert(rules)) {
    final RegExpMatch? m = _matchLine.firstMatch(line);
    if (m == null) continue;
    final bool childIndent = line.startsWith('      ');
    final List<String> names = m
        .group(1)!
        .split('/')
        .where((String s) => s.isNotEmpty && !s.startsWith('{'))
        .toList();
    if (names.isEmpty) continue;
    if (names.length >= 2) {
      paths.nested.add(names.join('/'));
    } else if (childIndent && parent != null) {
      paths.nested.add('$parent/${names.single}');
    } else {
      parent = names.single;
      paths.collections.add(names.single);
    }
  }
  return paths;
}

void main(List<String> args) {
  final bool checkOnly = args.contains('--check');
  if (args.any((String a) => a.startsWith('-') && a != '--check')) {
    stderr.writeln(
      'usage: dart run tool/gen_tenant_isolation_tests.dart [--check]',
    );
    exit(64);
  }

  final rulesFile = File(kRulesPath);
  final registryFile = File(kRegistryPath);
  if (!rulesFile.existsSync()) {
    _fail('cannot find $kRulesPath (run from core_app/)');
  }
  if (!registryFile.existsSync()) _fail('cannot find $kRegistryPath');

  final String rulesText = rulesFile.readAsStringSync();
  final _RulePaths paths = _pathsIn(rulesText);
  final Set<String> collections = paths.collections;
  final Set<String> nestedRows = paths.nested;
  final Set<String> knownRows = <String>{...collections, ...nestedRows};
  final Map<String, dynamic> registry =
      jsonDecode(registryFile.readAsStringSync()) as Map<String, dynamic>;
  final Map<String, dynamic> cases = (registry['cases'] as Map)
      .cast<String, dynamic>();

  final List<String> errors = <String>[];

  final List<String> missing = knownRows.difference(cases.keys.toSet()).toList()
    ..sort();
  if (missing.isNotEmpty) {
    errors.add(
      '${missing.length} collection(s) exist in $kRulesPath but have NO case row in '
      '$kRegistryPath — add a row (PENDING-TENANCY is a valid row; silence is not):\n'
      '${missing.map((String c) => '    - $c').join('\n')}',
    );
  }

  final List<String> stale =
      cases.keys.where((String c) => !knownRows.contains(c)).toList()..sort();
  if (stale.isNotEmpty) {
    errors.add(
      '${stale.length} registry row(s) no longer match any collection in $kRulesPath '
      '(stale registry): ${stale.join(', ')}',
    );
  }

  for (final String c in cases.keys.toList()..sort()) {
    final Object? row = cases[c];
    if (row is! Map) {
      errors.add('registry row "$c" must be an object, got ${row.runtimeType}');
      continue;
    }
    final Object? status = row['status'];
    if (status != kPendingTenancy && status != kActive) {
      errors.add(
        'registry row "$c" has status $status — expected $kActive or $kPendingTenancy',
      );
    }
    // A literal row names a fixed document (`settings/restaurantConfig`): the
    // rule block matches that exact name, so there is no id to substitute and
    // nothing for the probe to seed. Demanding a placeholder would force a
    // fiction — a seeded `settings/<random>` is denied because NO RULE MATCHES
    // it, not because of tenancy, which is the false proof this suite prevents.
    final bool literal = row['literal'] == true;
    for (final String field in <String>['readPath', 'writePath']) {
      final Object? v = row[field];
      if (v is! String || v.trim().isEmpty) {
        errors.add('registry row "$c" needs a non-empty "$field"');
      } else if (literal) {
        if (v.contains('{')) {
          errors.add(
            'registry row "$c" is literal but "$field" contains a placeholder '
            '— got "$v"',
          );
        }
      } else if (!v.contains('{id}')) {
        errors.add(
          'registry row "$c" "$field" must contain the {id} placeholder — got "$v"',
        );
      }
    }
    if (nestedRows.contains(c) && !literal) {
      if (row['nested'] != true) {
        errors.add(
          'registry row "$c" describes a nested block and must set "nested": true',
        );
      }
      for (final String field in <String>['readPath', 'writePath']) {
        final Object? v = row[field];
        if (v is String && !v.contains('{parentId}')) {
          errors.add(
            'registry row "$c" "$field" must contain {parentId} — a nested path '
            'has two document segments — got "$v"',
          );
        }
      }
      final Object? parentDoc = row['parentDocId'];
      if (parentDoc is! String || parentDoc.trim().isEmpty) {
        errors.add(
          'registry row "$c" needs a non-empty "parentDocId" (the SEEDED '
          'tenant-B parent document the nested path hangs from)',
        );
      }
      if (row['sameTenant'] == kSameTenantAllow) {
        final Object? allowParent = row['allowParentDocId'];
        if (allowParent is! String || allowParent.trim().isEmpty) {
          errors.add(
            'registry row "$c" is $kSameTenantAllow but has no '
            '"allowParentDocId" — the allow control needs tenant A\'s parent '
            'document to exist',
          );
        }
      }
    }
    if (!literal) {
      for (final String field in <String>['readDocId', 'writeDocId']) {
        final Object? v = row[field];
        if (v is! String || v.trim().isEmpty) {
          errors.add(
            'registry row "$c" needs a non-empty "$field" (the SEEDED tenant-B '
            'document id — a random path is denied for the wrong reason)',
          );
        }
      }
    }
    final Object? sameTenant = row['sameTenant'];
    if (sameTenant != kSameTenantAllow && sameTenant != kSameTenantNone) {
      errors.add(
        'registry row "$c" has sameTenant $sameTenant — expected '
        '$kSameTenantAllow or $kSameTenantNone',
      );
    } else if (sameTenant == kSameTenantAllow) {
      final Object? allowDoc = row['allowDocId'];
      if (allowDoc is! String || allowDoc.trim().isEmpty) {
        errors.add(
          'registry row "$c" is $kSameTenantAllow but has no "allowDocId" — '
          'the allow control needs a seeded tenant-A document',
        );
      }
    } else {
      final Object? allowWhy = row['sameTenantWhy'];
      if (allowWhy is! String || allowWhy.trim().isEmpty) {
        errors.add(
          'registry row "$c" is $kSameTenantNone but has no "sameTenantWhy" '
          '— a missing control needs a reason',
        );
      }
    }
    if (status == kPendingTenancy) {
      final Object? why = row['why'];
      if (why is! String || why.trim().isEmpty) {
        errors.add(
          'registry row "$c" is $kPendingTenancy but has no "why" — a loud skip needs a reason',
        );
      }
    }
  }

  if (errors.isNotEmpty) {
    for (final String e in errors) {
      stderr.writeln('ERROR: $e');
    }
    stderr.writeln(
      '\nTENANT-ISOLATION: FAIL — ${errors.length} violation(s); '
      '$kOutputPath was not written.',
    );
    exit(2);
  }

  // Format before writing. The template interpolates registry strings verbatim,
  // so long `why` values would otherwise exceed the formatter's line limit and
  // the checked-in file would fail the repo's `dart format` pre-commit rule the
  // moment it is generated. Formatting here makes the generator output stable
  // under the formatter, which is what `--check` compares against.
  final String rendered = _formatGenerated(_render(collections, cases));
  final File output = File(kOutputPath);

  if (checkOnly) {
    if (!output.existsSync()) {
      _fail(
        '$kOutputPath does not exist — run `dart run tool/gen_tenant_isolation_tests.dart` '
        'and commit the result',
      );
    }
    if (output.readAsStringSync() != rendered) {
      _fail(
        '$kOutputPath is stale (does not match $kRulesPath + $kRegistryPath) — '
        'run `dart run tool/gen_tenant_isolation_tests.dart`',
      );
    }
    final int pending = _countStatus(cases, kPendingTenancy);
    final int active = _countStatus(cases, kActive);
    stdout.writeln(
      'TENANT-ISOLATION: PASS — ${knownRows.length} rule paths '
      '(${collections.length} top-level + ${nestedRows.length} nested), '
      '$active ACTIVE, $pending $kPendingTenancy, generated suite in sync',
    );
    return;
  }

  output.writeAsStringSync(rendered);
  final int pending = _countStatus(cases, kPendingTenancy);
  final int active = _countStatus(cases, kActive);
  stdout.writeln(
    'wrote $kOutputPath — ${knownRows.length} rule paths '
    '(${collections.length} top-level + ${nestedRows.length} nested), '
    '$active ACTIVE, $pending $kPendingTenancy',
  );
}

int _countStatus(Map<String, dynamic> cases, String status) =>
    cases.values.where((Object? r) => r is Map && r['status'] == status).length;

/// Runs the SDK formatter over [source] and returns the formatted text.
///
/// Uses a temp file because `dart format` takes paths, not stdin. Fails closed:
/// an unformatted-but-written suite would make gate (i) red on the next run.
String _formatGenerated(String source) {
  final Directory tmp = Directory.systemTemp.createTempSync('tenant_gen_');
  try {
    final File file = File('${tmp.path}/suite.dart')..writeAsStringSync(source);
    final ProcessResult result = Process.runSync(Platform.resolvedExecutable, [
      'format',
      file.path,
    ]);
    if (result.exitCode != 0) {
      _fail(
        'dart format failed on the generated suite: '
        '${result.stderr.toString().trim()}',
      );
    }
    return file.readAsStringSync();
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

Never _fail(String message) {
  stderr.writeln('ERROR: $message');
  stderr.writeln('\nTENANT-ISOLATION: FAIL');
  exit(2);
}

String _dartString(String value) =>
    "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n')}'";

String _render(Set<String> collections, Map<String, dynamic> cases) {
  final List<String> sorted = collections.toList()..sort();
  final List<String> pendingNames = <String>[];
  final StringBuffer body = StringBuffer();

  for (final String c in sorted) {
    final Map<dynamic, dynamic> row = cases[c] as Map;
    final String status = row['status'] as String;
    if (status == kPendingTenancy) pendingNames.add(c);
    body
      ..writeln('    crossTenantCase(')
      ..writeln('      collection: ${_dartString(c)},')
      ..writeln('      status: ${_dartString(status)},')
      ..writeln('      why: ${_dartString((row['why'] as String?) ?? '')},')
      ..writeln('      readPath: ${_dartString(row['readPath'] as String)},')
      ..writeln('      writePath: ${_dartString(row['writePath'] as String)},')
      ..writeln('      readDocId: ${_dartString(row['readDocId'] as String)},')
      ..writeln(
        '      writeDocId: ${_dartString(row['writeDocId'] as String)},',
      )
      ..writeln(
        '      allowDocId: ${_dartString(row['allowDocId'] as String)},',
      )
      ..writeln(
        '      parentDocId: '
        '${_dartString((row['parentDocId'] as String?) ?? '')},',
      )
      ..writeln(
        '      allowParentDocId: '
        '${_dartString((row['allowParentDocId'] as String?) ?? '')},',
      )
      ..writeln(
        '      createBodyJson: ${_dartString(row['createBody'] == null ? '' : jsonEncode(row['createBody']))},',
      )
      ..writeln(
        '      createDocId: ${_dartString((row['createDocId'] as String?) ?? '')},',
      )
      ..writeln(
        '      sameTenant: ${_dartString(row['sameTenant'] as String)},',
      )
      ..writeln(
        '      sameTenantWhy: '
        '${_dartString((row['sameTenantWhy'] as String?) ?? '')},',
      )
      ..writeln(
        row['principal'] == null
            ? ''
            : '      principal: ${_dartString(row['principal'] as String)},',
      )
      ..writeln('    );')
      ..writeln();
  }

  final int active = sorted.length - pendingNames.length;

  return '''
// GENERATED FILE — DO NOT EDIT BY HAND.
// Generator: tool/gen_tenant_isolation_tests.dart
// Sources:   $kRulesPath (top-level collections) + $kRegistryPath
// Regenerate: cd core_app && dart run tool/gen_tenant_isolation_tests.dart
//
// P0-8: this suite is the machine that will prove tenant isolation. It is
// complete by construction — gate (i) fails when a rules collection has no case
// row. Today ${pendingNames.length} of ${sorted.length} collections are $kPendingTenancy and skip WITH A
// REASON; flipping a registry row to $kActive turns the same three tests into
// real assertions against the emulator: tenant A is denied READ and WRITE on
// tenant B's seeded document, and (when the registry says so) ALLOWED to read
// its own. The allow case is the control that stops a rules typo that denies
// everything from scoring as "tenants are isolated".

@Tags(['needs-emulator'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'tenant_isolation_support.dart';

/// Collections with a real (non-skipped) case today.
const int kActiveCases = $active;

/// Collections whose case skips because tenancy does not exist yet.
const int kPendingCases = ${pendingNames.length};

const int kTotalCases = ${sorted.length};

const List<String> kPendingCollections = <String>[
${pendingNames.map((String c) => '  ${_dartString(c)},').join('\n')}
];

void main() {
  // No bootstrap here: `flutter test --tags gate_fast` still LOADS this file
  // (and runs its main) while filtering every test out, so connecting eagerly
  // would make an unrelated gate fail for want of an emulator. The first
  // assertion that actually runs connects instead.
  group('P0-8 cross-tenant isolation (generated)', () {
    test('STATUS — pending collections are named, never silent', () {
      // Loud on purpose: the numbers and the list land in the test log, so a
      // green suite cannot be mistaken for proven tenancy.
      // stderr (not print): analyzer forbids print even in tests, and a silent
      // pending list would defeat the point of the scaffold.
      stderr.writeln(
        'TENANT ISOLATION: \$kActiveCases active / \$kPendingCases '
        '\$kPendingTenancy / \$kTotalCases collections',
      );
      if (kPendingCases > 0) {
        stderr.writeln('NO cross-tenant denial is proven yet for: \${kPendingCollections.join(", ")}');
      }
      expect(kActiveCases + kPendingCases, kTotalCases);
      expect(kPendingCollections.length, kPendingCases);
    });

$body  });
}
''';
}
