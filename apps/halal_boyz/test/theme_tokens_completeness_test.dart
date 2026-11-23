import 'dart:convert';
import 'dart:io';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/client_config.dart';

/// FIX-B9 T-1 — config completeness, driven by the ENGINE's own reader list.
///
/// Reader list (P1, opened this session):
/// * `packages/core_ui/lib/src/theme/app_theme.dart:456-478` — token reads:
///   `shape.smallRadius`, `components.input.{fillColor,borderColor,radius}`,
///   `components.chip.radius`, `background.{color,overlayAsset}`.
/// * attach-when-set component themes — `app_theme.dart:564-617`
///   (TextButton / InputDecorationTheme / ChipThemeData attach ONLY when the
///   token is present; absent = Material 3 default).
/// * strict-when-present runtime schema —
///   `core_app/lib/app/config/client_config.dart:325-377` (hex colors,
///   positive radii, relative overlay path).
///
/// F-AUD2-07: the four families are ABSENT from the shipped halal config
/// (RED). GREEN = every reader key present, engine-parsable, derived from the
/// file's OWN brand values (invent nothing — spec §1), and the built
/// [ThemeData] differs from the generic (empty-map) build wherever branding
/// is promised.
void main() {
  late Map<String, dynamic> theme;

  setUpAll(() {
    final file = File('assets/client_config.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    theme = json['theme'] as Map<String, dynamic>;
  });

  /// Nested section lookup: `['components', 'input']` → `theme.components.input`
  /// (null when the whole section is absent — the F-AUD2-07 RED state).
  Map<String, dynamic>? section(List<String> path) {
    Map<String, dynamic>? cursor = theme;
    for (final key in path) {
      final next = cursor?[key];
      if (next is! Map<String, dynamic>) return null;
      cursor = next;
    }
    return cursor;
  }

  group('T-1: engine-surfaced branding keys are SET (F-AUD2-07)', () {
    test('all four families present at the engine reader paths', () {
      final shape = section(const ['shape']);
      expect(shape, isNotNull, reason: 'app_theme.dart:456 reads theme.shape');
      expect(
        shape!.containsKey('smallRadius'),
        isTrue,
        reason: 'app_theme.dart:459 reads theme.shape.smallRadius',
      );

      final input = section(const ['components', 'input']);
      expect(
        input,
        isNotNull,
        reason: 'app_theme.dart:466 reads theme.components.input.*',
      );
      for (final key in const ['fillColor', 'borderColor', 'radius']) {
        expect(
          input!.containsKey(key),
          isTrue,
          reason: 'theme.components.input.$key must be SET (F-AUD2-07)',
        );
      }

      final chip = section(const ['components', 'chip']);
      expect(
        chip,
        isNotNull,
        reason: 'app_theme.dart:470 reads theme.components.chip',
      );
      expect(
        chip!.containsKey('radius'),
        isTrue,
        reason: 'theme.components.chip.radius must be SET (F-AUD2-07)',
      );

      final background = section(const ['background']);
      expect(
        background,
        isNotNull,
        reason: 'app_theme.dart:473 reads theme.background',
      );
      expect(
        background!.containsKey('color'),
        isTrue,
        reason: 'theme.background.color must be SET (F-AUD2-07)',
      );
      expect(
        background.containsKey('overlayAsset'),
        isTrue,
        reason:
            'theme.background.overlayAsset key must be present (reader '
            'list parity with the engine and the core template; value may be '
            'null = no decorative art shipped, owner/ops decision F-4)',
      );
    });

    test('every branding token is engine-parsable '
        '(hex color / positive radius)', () {
      final input = section(const ['components', 'input'])!;
      expect(input['fillColor'], isA<String>(), reason: 'hex color token');
      expect(
        ClientConfig.isValidHexColor(input['fillColor'] as String),
        isTrue,
        reason:
            'client_config.dart:396 must accept theme.components.input.fillColor',
      );
      expect(input['borderColor'], isA<String>(), reason: 'hex color token');
      expect(
        ClientConfig.isValidHexColor(input['borderColor'] as String),
        isTrue,
        reason:
            'client_config.dart:396 must accept theme.components.input.borderColor',
      );
      expect(input['radius'], isA<num>(), reason: 'positive radius token');
      expect(
        (input['radius'] as num) > 0,
        isTrue,
        reason: 'app_theme.dart:642 requires a positive finite radius',
      );

      final chip = section(const ['components', 'chip'])!;
      expect(chip['radius'], isA<num>(), reason: 'positive radius token');
      expect((chip['radius'] as num) > 0, isTrue);

      final shape = section(const ['shape'])!;
      expect(shape['smallRadius'], isA<num>(), reason: 'positive radius token');
      expect((shape['smallRadius'] as num) > 0, isTrue);

      final background = section(const ['background'])!;
      expect(background['color'], isA<String>(), reason: 'hex color token');
      expect(
        ClientConfig.isValidHexColor(background['color'] as String),
        isTrue,
        reason: 'client_config.dart:396 must accept theme.background.color',
      );
      final overlayAsset = background['overlayAsset'];
      expect(
        overlayAsset == null || overlayAsset is String,
        isTrue,
        reason: 'app_theme.dart:475 reads overlayAsset as an optional string',
      );
    });

    test(
      "brand values derive from the file's OWN palette (invent nothing)",
      () {
        final colors = section(const ['colors'])!;
        final spacing = section(const ['spacing'])!;
        final shape = section(const ['shape'])!;
        final input = section(const ['components', 'input'])!;

        expect(
          input['fillColor'],
          colors['surface'],
          reason: 'input fill = the declared brand surface (0xFFFFFFFF)',
        );
        expect(
          input['borderColor'],
          colors['primary'],
          reason:
              'input border = the declared brand primary (maroon 0xFF900000)',
        );
        expect(
          input['radius'],
          spacing['smallPadding'],
          reason: 'input radius = the declared spacing.smallPadding (8.0)',
        );
        expect(
          shape['smallRadius'],
          spacing['smallPadding'],
          reason:
              'compact-button radius = the declared spacing.smallPadding (8.0)',
        );
        expect(
          section(const ['components', 'chip'])!['radius'],
          shape['ctaRadius'],
          reason:
              'chip radius = the declared shape.ctaRadius (100.0 stadium) — '
              'the brand CTA language',
        );
        expect(
          section(const ['background'])!['color'],
          colors['background'],
          reason: 'backdrop = the declared brand background (0xFFF9F9F9)',
        );
      },
    );

    test(
      'attach-when-set: built ThemeData differs from the generic default',
      () {
        final branded = AppTheme.buildTheme(theme);
        final generic = AppTheme.buildTheme(const <String, dynamic>{});

        // smallRadius → TextButton theme attaches (app_theme.dart:564-574).
        expect(generic.textButtonTheme.style, isNull);
        expect(
          branded.textButtonTheme.style,
          isNotNull,
          reason: 'theme.shape.smallRadius must attach a TextButton theme',
        );
        expect(
          branded.extension<AppShapeTokens>()!.smallRadius,
          8.0,
          reason: 'AppShapeTokens.smallRadius must carry the brand token',
        );
        expect(generic.extension<AppShapeTokens>()!.smallRadius, isNull);

        // input.* → InputDecorationTheme attaches (app_theme.dart:587-610).
        expect(generic.inputDecorationTheme.filled, isFalse);
        expect(
          branded.inputDecorationTheme.filled,
          isTrue,
          reason: 'theme.components.input.fillColor must fill the input',
        );
        expect(branded.inputDecorationTheme.fillColor, const Color(0xFFFFFFFF));
        final border =
            branded.inputDecorationTheme.enabledBorder as OutlineInputBorder;
        expect(border.borderRadius, BorderRadius.circular(8));
        expect(border.borderSide.color, const Color(0xFF900000));

        // chip.radius → ChipThemeData attaches (app_theme.dart:611-617).
        expect(generic.chipTheme.shape, isNull);
        expect(
          branded.chipTheme.shape,
          isNotNull,
          reason: 'theme.components.chip.radius must attach a chip shape',
        );
        final chipShape = branded.chipTheme.shape as RoundedRectangleBorder;
        expect(chipShape.borderRadius, BorderRadius.circular(100));
      },
    );

    test('background family: brand backdrop applied, overlay key present', () {
      final background = section(const ['background']);
      expect(
        background,
        isNotNull,
        reason: 'theme.background section must exist (F-AUD2-07)',
      );
      expect(
        background!['color'],
        isNot('0xFFFFFFFF'),
        reason:
            'the brand backdrop 0xFFF9F9F9 differs from the in-code '
            'generic AppColors.background (white)',
      );
      expect(
        background.containsKey('overlayAsset'),
        isTrue,
        reason:
            'overlayAsset key present; null = no decorative art shipped '
            'with the shell (owner/ops decision, AUDIT_HALAL F-4)',
      );

      final branded = AppTheme.buildTheme(theme);
      expect(
        branded.scaffoldBackgroundColor,
        const Color(0xFFF9F9F9),
        reason: 'app_theme.dart:512 must apply theme.background.color',
      );
      expect(
        branded.extension<AppBackdropTokens>()!.overlayAsset,
        isNull,
        reason: 'null overlayAsset = no overlay (app_theme.dart:475)',
      );
    });

    test('already-branded families stay present (no regression)', () {
      expect(section(const ['colors']), isNotNull);
      expect(section(const ['darkTheme']), isNotNull);
      expect(section(const ['typography']), isNotNull);
      expect(section(const ['confettiOverlay']), isNotNull);
      expect(section(const ['spacing']), isNotNull);
      expect(
        section(const ['components', 'navigationBar']),
        isNotNull,
        reason: 'navigationBar tokens were already set — must stay set',
      );
      expect(section(const ['shape'])!.containsKey('cardRadius'), isTrue);
      expect(section(const ['shape'])!.containsKey('ctaRadius'), isTrue);
    });
  });
}
