// UI-13 (p21) phase H2 — the CUSTOMER half of the F3-09..F3-15 adoption sweep
// (L32: audience, not convenience).
//
// This is the enforceable counterpart of the register rows: every raw
// `CircularProgressIndicator` (F3-09), `ListTile` (F3-10), `Card` (F3-11),
// `TextField` (F3-12), `showModalBottomSheet` (F3-13 adoption half) and
// `BoxDecoration`-decorated `Container` (F3-15) inside a CUSTOMER-facing
// `core_app/lib` file must be gone, replaced by the frozen `core_ui`
// equivalent (`SkeletonLoader`/`TileSkeletons`, the tile family, `BrandCard`,
// `BrandTextField`, `BrandSheet`).
//
// Scope exclusions are ownership boundaries, not loopholes — each is a handoff
// row in `tool_uilib/p21/p21_report.md`:
//   * `features/admin/**` + `admin_reservations_tab.dart`  -> p22 (staff)
//   * `features/{waitlist,profile,loyalty}/**`, the p20 shipped screens and
//     `features/driver/proof_of_delivery_service.dart` (a `*_service.dart`,
//     forbidden to BOTH waves — p22 §2 names it explicitly)
//
// Line comments are stripped before scanning: several adopted screens carry a
// self-documenting comment that NAMES the widget they no longer use, and a
// comment is not an occurrence.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _SweepGap {
  const _SweepGap(this.id, this.pattern, this.libraryEquivalent);

  final String id;
  final RegExp pattern;
  final String libraryEquivalent;
}

/// Not `const`: `RegExp` has no const constructor, so the list is `final`.
final List<_SweepGap> _gaps = <_SweepGap>[
  _SweepGap(
    'F3-09',
    RegExp(r'\bCircularProgressIndicator\s*\('),
    'SkeletonLoader / TileSkeletons (or BrandButton(isLoading:))',
  ),
  _SweepGap(
    'F3-10',
    RegExp(r'(?<![A-Za-z])ListTile\s*\('),
    'SettingTile / MenuTile / StatusTile / StatTile',
  ),
  _SweepGap('F3-11', RegExp(r'(?<![A-Za-z])Card\s*\('), 'BrandCard'),
  _SweepGap('F3-12', RegExp(r'(?<![A-Za-z])TextField\s*\('), 'BrandTextField'),
  _SweepGap(
    'F3-13',
    RegExp(r'\bshowModalBottomSheet\s*\('),
    'BrandSheet / BrandDialog',
  ),
  _SweepGap(
    'F3-15',
    RegExp(r'\bBoxDecoration\s*\('),
    'GradientScaffold / ScreenScaffold / shapes (decorated Container)',
  ),
];

/// Ownership boundaries (see the header). Paths are repo-relative with `/`.
const List<String> _handoffPrefixes = <String>[
  // p22 — staff/operator surfaces.
  'core_app/lib/features/admin/',
  'core_app/lib/features/reservations/presentation/admin_reservations_tab.dart',
  // p20 — shipped, forbidden to this wave.
  'core_app/lib/features/reservations/presentation/reservation_screen.dart',
  'core_app/lib/features/waitlist/',
  'core_app/lib/features/profile/',
  'core_app/lib/features/loyalty/',
  'core_app/lib/features/orders/presentation/order_tracker_screen.dart',
  'core_app/lib/features/orders/presentation/order_history_screen.dart',
  // Forbidden to both waves (p22 §2 names the service explicitly).
  'core_app/lib/features/driver/proof_of_delivery_service.dart',
];

String _stripLineComments(String source) => source
    .split('\n')
    .map((l) {
      final i = l.indexOf('//');
      return i == -1 ? l : l.substring(0, i);
    })
    .join('\n');

void main() {
  Directory repoRoot() {
    var dir = Directory.current;
    for (var i = 0; i < 6; i++) {
      final coreApp = Directory('${dir.path}/core_app');
      final packages = Directory('${dir.path}/packages');
      final batches = File('${dir.path}/PRODUCTION_FIX_BATCHES.md');
      if (coreApp.existsSync() &&
          packages.existsSync() &&
          batches.existsSync()) {
        return dir;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    fail('repo root not found upward from ${Directory.current.path}');
  }

  List<File> dartFilesUnder(Directory dir) => dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String repoRelative(File f) =>
      f.path.replaceAll('\\', '/').split('core_app/').last;

  bool isCustomerSweepFile(File f) {
    final rel = 'core_app/${repoRelative(f)}';
    return !_handoffPrefixes.any(rel.startsWith);
  }

  test('sweep ban is live (positive control — never vacuously green)', () {
    expect(
      _gaps[0].pattern.hasMatch('child: CircularProgressIndicator()'),
      isTrue,
    );
    expect(_gaps[1].pattern.hasMatch('child: ListTile(title: t)'), isTrue);
    expect(_gaps[1].pattern.hasMatch('child: SettingTile()'), isFalse);
    expect(_gaps[2].pattern.hasMatch('child: Card(child: c)'), isTrue);
    expect(_gaps[2].pattern.hasMatch('child: BrandCard(child: c)'), isFalse);
    expect(_gaps[3].pattern.hasMatch('child: TextField()'), isTrue);
    expect(_gaps[3].pattern.hasMatch('child: BrandTextField()'), isFalse);
    expect(
      _gaps[4].pattern.hasMatch('showModalBottomSheet(context: c)'),
      isTrue,
    );
    expect(_gaps[4].pattern.hasMatch('BrandSheet.show(context)'), isFalse);
    expect(_gaps[5].pattern.hasMatch('decoration: BoxDecoration()'), isTrue);
    // A comment naming a widget is not an occurrence.
    final commented = _stripLineComments(
      '// no raw CircularProgressIndicator here\nchild: 1',
    );
    expect(_gaps[0].pattern.hasMatch(commented), isFalse);
  });

  test('every staff/handoff path is excluded from the customer scan (L32)', () {
    final root = repoRoot();
    // The exclusions must be real ownership boundaries, not a claim: walk each
    // handoff prefix and prove the scanner classifies it as NOT customer-side.
    // (No count is asserted on the staff side — p22 owns that half and its
    // progress must never be able to turn this gate red or green.)
    for (final prefix in _handoffPrefixes) {
      final dir = Directory('${root.path}/$prefix');
      if (dir.existsSync()) {
        final files = dartFilesUnder(dir);
        expect(
          files,
          isNotEmpty,
          reason: 'handoff dir has no sources: $prefix',
        );
        expect(
          files.every((f) => !isCustomerSweepFile(f)),
          isTrue,
          reason: '$prefix must be a handoff, never a customer-scan target',
        );
      } else {
        final file = File('${root.path}/$prefix');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'handoff path missing from the tree: $prefix',
        );
        expect(
          isCustomerSweepFile(file),
          isFalse,
          reason: '$prefix must be a handoff, never a customer-scan target',
        );
      }
    }
    // And the customer side really is scanned (a live lib file is in scope).
    expect(
      isCustomerSweepFile(
        File(
          '${root.path}/core_app/lib/features/cart/presentation/cart_screen.dart',
        ),
      ),
      isTrue,
    );
  });

  test('no raw adoption-gap widget in any CUSTOMER-facing lib file', () {
    final lib = Directory('${repoRoot().path}/core_app/lib');
    final customerFiles = dartFilesUnder(
      lib,
    ).where(isCustomerSweepFile).toList();
    expect(customerFiles, isNotEmpty);

    final offenders = <String>[];
    for (final file in customerFiles) {
      final source = _stripLineComments(file.readAsStringSync());
      for (final gap in _gaps) {
        final n = gap.pattern.allMatches(source).length;
        if (n > 0) {
          offenders.add(
            '${repoRelative(file)} :: ${gap.id} x$n '
            '(use ${gap.libraryEquivalent})',
          );
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'customer half of F3-09..F3-15 not swept:\n'
          '${offenders.join('\n')}',
    );
  });
}
