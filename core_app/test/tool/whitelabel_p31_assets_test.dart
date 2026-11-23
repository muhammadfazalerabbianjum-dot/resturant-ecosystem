import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/whitelabel.dart' as whitelabel;

/// G1/G2 (p31) — generated-app asset parity and `--template` presets.
///
/// G1: the emitted pubspec DECLARES `assets/fonts/*.ttf` — before p31 no
/// copy step existed, so a fresh client app shipped four missing assets
/// (only halal_boyz had the bytes, added by hand). These tests pin the
/// canonical tool-side source, the byte-copy contract, and the checked-in
/// shell's on-disk parity.
///
/// G2: `--template minimal|modern|classic` validated and printed but was
/// never read (a no-op flag). The preset seam is a pure fill-missing merge
/// over the generated app's config copy — config stays the source of truth.
List<String> _fontNames() => const [
  'PlayfairDisplay-Regular.ttf',
  'PlayfairDisplay-Bold.ttf',
  'Inter-Regular.ttf',
  'Inter-Bold.ttf',
];

Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final candidate = File(
      '${dir.path}${Platform.pathSeparator}core_app'
      '${Platform.pathSeparator}tool${Platform.pathSeparator}whitelabel.dart',
    );
    if (candidate.existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('p31: repo root not found from ${Directory.current.path}');
}

void main() {
  final repoRoot = _repoRoot();
  final sep = Platform.pathSeparator;
  final canonical = Directory(
    '${repoRoot.path}${sep}core_app${sep}tool${sep}templates${sep}fonts',
  );
  final shellFonts = Directory(
    '${repoRoot.path}${sep}apps${sep}halal_boyz${sep}assets${sep}fonts',
  );
  final generatorSource = File(
    '${repoRoot.path}${sep}core_app${sep}tool${sep}whitelabel.dart',
  );

  group('G1 — canonical font source', () {
    test('the tool carries the four declared TTFs', () {
      expect(
        canonical.existsSync(),
        isTrue,
        reason:
            'core_app/tool/templates/fonts/ must exist — the pubspec template '
            'declares these assets for every generated app',
      );
      final names = canonical
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split(sep).last)
          .where((n) => n.endsWith('.ttf'))
          .toSet();
      expect(names, _fontNames().toSet());
    });

    test('the checked-in shell matches the canonical bytes (drift guard)', () {
      expect(shellFonts.existsSync(), isTrue);
      for (final name in _fontNames()) {
        final source = File('${canonical.path}$sep$name');
        final shell = File('${shellFonts.path}$sep$name');
        expect(source.existsSync(), isTrue, reason: 'missing $name');
        expect(shell.existsSync(), isTrue, reason: 'shell missing $name');
        expect(
          shell.readAsBytesSync(),
          source.readAsBytesSync(),
          reason:
              '$name drifted between the generator source and the generated '
              'shell — regenerate the app or update the canonical copy',
        );
      }
    });

    test(
      'copyTemplateFonts materialises every declared font byte-identically',
      () {
        final target = Directory.systemTemp.createTempSync('p31_fonts_');
        addTearDown(() => target.deleteSync(recursive: true));

        whitelabel.copyTemplateFonts(repoRoot: repoRoot, appPath: target.path);

        for (final name in _fontNames()) {
          final copied = File('${target.path}${sep}assets${sep}fonts$sep$name');
          expect(
            copied.existsSync(),
            isTrue,
            reason: 'generator did not copy $name',
          );
          expect(
            copied.readAsBytesSync(),
            File('${canonical.path}$sep$name').readAsBytesSync(),
          );
        }
      },
    );

    test('the generator source declares exactly the canonical font assets', () {
      final declared = RegExp(r'assets/fonts/([A-Za-z0-9-]+\.ttf)')
          .allMatches(generatorSource.readAsStringSync())
          .map((m) => m.group(1)!)
          .toSet();
      expect(
        declared,
        _fontNames().toSet(),
        reason:
            'pubspec template font entries must stay 1:1 with the bytes the '
            'generator copies (G1 asset-parity gate)',
      );
    });
  });

  group('G2 — template theme presets', () {
    test('fills only absent theme keys — the config wins', () {
      final config = <String, dynamic>{
        'app': <String, dynamic>{'name': 'Probe'},
        'theme': <String, dynamic>{
          'shape': <String, dynamic>{'cardRadius': 42.0},
        },
      };

      whitelabel.applyTemplateThemePreset(config, 'modern');

      final theme = config['theme'] as Map<String, dynamic>;
      final shape = theme['shape'] as Map<String, dynamic>;
      final components = theme['components'] as Map<String, dynamic>;
      expect(shape['cardRadius'], 42.0, reason: 'owner value must survive');
      expect(shape['ctaRadius'], 100.0, reason: 'preset fills the gap');
      expect(
        (components['input'] as Map<String, dynamic>)['radius'],
        12.0,
        reason: 'preset fills components.input.radius',
      );
      expect((components['chip'] as Map<String, dynamic>)['radius'], 100.0);
    });

    test('each named preset ships its own shape scale', () {
      final radii = <String, double>{};
      for (final name in ['minimal', 'modern', 'classic']) {
        final config = <String, dynamic>{};
        whitelabel.applyTemplateThemePreset(config, name);
        final theme = config['theme'] as Map<String, dynamic>;
        final shape = theme['shape'] as Map<String, dynamic>;
        radii[name] = shape['cardRadius']! as double;
      }
      expect(radii['minimal'], 8.0);
      expect(radii['modern'], 20.0);
      expect(radii['classic'], 4.0);
    });

    test('an unknown preset fails loudly instead of silently no-opping', () {
      expect(
        () => whitelabel.applyTemplateThemePreset(<String, dynamic>{}, 'neon'),
        throwsArgumentError,
      );
    });

    test('the generator source only seeds when --template is explicit', () {
      expect(
        generatorSource.readAsStringSync().contains(
          "args.contains('--template')",
        ),
        isTrue,
        reason:
            "G2: the default run must keep today's byte-identical config — "
            'presets apply only when the operator passes --template',
      );
    });
  });

  group('checked-in shell parity (G1 evidence on the real artifact)', () {
    test('every pubspec font asset in halal_boyz exists on disk', () {
      final pubspec = File(
        '${repoRoot.path}${sep}apps${sep}halal_boyz${sep}pubspec.yaml',
      );
      expect(pubspec.existsSync(), isTrue);
      final declared = RegExp(
        r'asset:\s*(assets/fonts/[A-Za-z0-9-]+\.ttf)',
      ).allMatches(pubspec.readAsStringSync()).map((m) => m.group(1)!).toSet();
      expect(declared, isNotEmpty, reason: 'pubspec must declare fonts');
      for (final rel in declared) {
        expect(
          File(
            '${repoRoot.path}$sep${'apps'}$sep${'halal_boyz'}$sep$rel',
          ).existsSync(),
          isTrue,
          reason: 'declared font missing on disk: $rel (the G1 defect class)',
        );
      }
    });
  });
}
