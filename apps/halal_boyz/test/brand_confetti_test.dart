import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/labs.dart' show AppConfig;

/// FIX-B9 T-2 — brand confetti (F-AUD2-10).
///
/// The in-code generic default quartet (P1, opened this session):
/// * `core_app/lib/app/config/app_config.dart:79-84` — `AppConfig._confettiColors`
/// * `packages/core_ui/lib/src/ui/confetti_overlay.dart:13-18` — fallback arg
///   = `[E63946, 1D3557, F4A261, 2A9D8F]`.
///
/// RED today: the shipped halal `theme.confettiOverlay.colors` is byte-
/// identical to that default ("configured but not branded"). GREEN = the
/// config declares the client's own brand quartet — derived from the SAME
/// file's `theme.colors` (invent nothing — spec §1) — and the RUNTIME parser
/// (`app_config.dart:321-334`) hydrates it into [AppConfig.confettiColors],
/// which checkout passes to `ConfettiOverlay.show`
/// (`checkout_screen.dart:495`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The in-code generic default — duplicated here as the const under test
  /// (both P1 sites above carry the same literal values).
  const inCodeDefaultQuartet = <String>[
    '0xFFE63946',
    '0xFF1D3557',
    '0xFFF4A261',
    '0xFF2A9D8F',
  ];

  late Map<String, dynamic> theme;

  setUpAll(() {
    final file = File('assets/client_config.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    theme = json['theme'] as Map<String, dynamic>;
  });

  Map<String, dynamic> section(List<String> path) {
    Map<String, dynamic> cursor = theme;
    for (final key in path) {
      cursor = cursor[key] as Map<String, dynamic>;
    }
    return cursor;
  }

  /// Parses the config hex vocabulary (`0xRRGGBB` / `0xAARRGGBB`).
  Color hex(String raw) =>
      Color(int.parse(raw.trim().replaceFirst('0x', ''), radix: 16));

  group('T-2 brand confetti (F-AUD2-10)', () {
    test('theme.confettiOverlay.colors differs from the in-code default', () {
      final confetti = (section(const ['confettiOverlay'])['colors'] as List)
          .cast<String>();
      expect(
        confetti,
        isNot(equals(inCodeDefaultQuartet)),
        reason:
            'the shipped palette must NOT be the generic '
            '[E63946, 1D3557, F4A261, 2A9D8F] default (F-AUD2-10)',
      );
    });

    test("colors equal the client's declared brand palette (theme.colors)", () {
      final confetti = (section(const ['confettiOverlay'])['colors'] as List)
          .cast<String>();
      final colors = section(const ['colors']);

      // The brand celebration quartet, DERIVED from the file's own declared
      // palette: primary maroon + secondary orange-gold + warning amber +
      // success green — every element must appear in theme.colors.
      final expectedBrandPalette = <String>[
        colors['primary'] as String,
        colors['secondary'] as String,
        colors['warning'] as String,
        colors['success'] as String,
      ];
      expect(
        confetti,
        equals(expectedBrandPalette),
        reason:
            'theme.confettiOverlay.colors must equal the declared brand '
            'palette [primary, secondary, warning, success]',
      );
      expect(
        confetti.toSet().length,
        confetti.length,
        reason: 'a celebration palette needs distinct hues',
      );
      for (final value in confetti) {
        expect(
          colors.values,
          contains(value),
          reason:
              'every confetti hue must be a value the file already '
              'declares in theme.colors (invent nothing)',
        );
      }
    });

    test(
      'runtime: AppConfig.confettiColors hydrates the brand quartet',
      () async {
        addTearDown(AppConfig.resetForTest);
        AppConfig.resetForTest();
        await AppConfig.loadConfig();
        expect(
          AppConfig.loadFailed,
          isFalse,
          reason: 'the shipped config must pass the W6.5 schema gate',
        );

        final colors = section(const ['colors']);
        final expected = <Color>[
          hex(colors['primary'] as String),
          hex(colors['secondary'] as String),
          hex(colors['warning'] as String),
          hex(colors['success'] as String),
        ];
        expect(
          AppConfig.confettiColors,
          equals(expected),
          reason:
              'app_config.dart:321-334 must parse the brand quartet into '
              'the runtime confettiColors consumed by checkout (P2 end-to-end)',
        );
      },
    );
  });
}
