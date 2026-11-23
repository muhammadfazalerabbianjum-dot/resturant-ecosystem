import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';

/// TOKENS (WHITE_LABEL_b10_tokens.md) — per-token red→green: setting a token
/// must be reflected in the built [ThemeData]; omitting it must keep the
/// pre-token default (acceptance contract 3). Plus the distinct-tokens widget
/// pattern (COLOR-1 T-2 extended), the typography split, and the
/// [ScaffoldBackground] mechanism.
///
/// NOTE on Flutter API: `ThemeData.cardTheme` / `filledButtonTheme` /
/// `navigationBarTheme` / `chipTheme` / `inputDecorationTheme` getters are
/// non-nullable (they fall back to M3 defaults), so "absent token" is asserted
/// on the FALLBACK VALUES (e.g. `style == null`, `backgroundColor == null`),
/// not on the getter being null.
void main() {
  group("T-1 backward compatibility: an absent token = today's behavior", () {
    test('empty theme map builds the pre-token surfaces', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{});

      final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(cardShape.borderRadius, BorderRadius.circular(16));
      // No token → component themes fall back to Material 3 defaults.
      expect(theme.filledButtonTheme.style, isNull);
      expect(theme.outlinedButtonTheme.style, isNull);
      expect(theme.iconButtonTheme.style, isNull);
      expect(theme.textButtonTheme.style, isNull);
      expect(theme.navigationBarTheme.backgroundColor, isNull);
      expect(theme.inputDecorationTheme.filled, isFalse);
      expect(theme.chipTheme.shape, isNull);
      expect(theme.scaffoldBackgroundColor, AppColors.background);

      final shape = theme.extension<AppShapeTokens>();
      expect(shape, isNotNull);
      expect(shape!.cardRadius, 16);
      expect(shape.ctaRadius, isNull);
      expect(shape.smallRadius, isNull);

      final motion = theme.extension<AppMotionTokens>();
      expect(motion, isNotNull);
      expect(motion!.style, AppMotionStyle.full);
      // full preset = today's shared page-motion baseline (transitions.dart).
      expect(motion.standard, const Duration(milliseconds: 300));
      expect(motion.curve, Curves.easeOut);

      final backdrop = theme.extension<AppBackdropTokens>();
      expect(backdrop, isNotNull);
      expect(backdrop!.overlayAsset, isNull);
    });

    test('dark build keeps the same defaults', () {
      final theme = AppTheme.buildDarkTheme(const <String, dynamic>{});
      final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(cardShape.borderRadius, BorderRadius.circular(16));
      expect(theme.extension<AppMotionTokens>()!.style, AppMotionStyle.full);
      expect(theme.extension<AppBackdropTokens>()!.overlayAsset, isNull);
    });
  });

  group('T-2 shape tokens', () {
    test('cardRadius token → CardThemeData radius', () {
      final theme = AppTheme.buildTheme(<String, dynamic>{
        'shape': <String, dynamic>{'cardRadius': 12},
      });
      final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
    });

    test('ctaRadius token → Filled/Outlined/Icon button radius', () {
      final theme = AppTheme.buildTheme(<String, dynamic>{
        'shape': <String, dynamic>{'ctaRadius': 100},
      });
      expect(theme.cardTheme.shape, isNotNull); // card keeps its default 16
      OutlinedBorder? shapeOf(ButtonStyle style) =>
          style.shape?.resolve(<WidgetState>{});
      final rounded =
          shapeOf(theme.filledButtonTheme.style!)! as RoundedRectangleBorder;
      expect(rounded.borderRadius, BorderRadius.circular(100));
      expect(
        shapeOf(theme.outlinedButtonTheme.style!) as RoundedRectangleBorder,
        rounded,
      );
      expect(shapeOf(theme.iconButtonTheme.style!), isA<OutlinedBorder>());
    });

    test('smallRadius token → TextButton (compact) radius', () {
      final theme = AppTheme.buildTheme(<String, dynamic>{
        'shape': <String, dynamic>{'smallRadius': 8},
      });
      final shape =
          theme.textButtonTheme.style!.shape!.resolve(<WidgetState>{})
              as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(8));
      expect(theme.filledButtonTheme.style, isNull);
    });
  });

  group('T-3 navigationBar tokens', () {
    test('background + activeColor → NavigationBarThemeData', () {
      final theme = AppTheme.buildTheme(<String, dynamic>{
        'colors': <String, dynamic>{'primary': '0xFF900000'},
        'components': <String, dynamic>{
          'navigationBar': <String, dynamic>{
            'background': '0xFF1A1A1A',
            'activeColor': '0xFFFFA500',
          },
        },
      });
      expect(theme.navigationBarTheme.backgroundColor, const Color(0xFF1A1A1A));
      expect(
        theme.navigationBarTheme.iconTheme!.resolve(<WidgetState>{
          WidgetState.selected,
        }),
        const IconThemeData(color: Color(0xFFFFA500)),
      );
      // Unselected icons keep their defaults (null resolve → theme default).
      expect(
        theme.navigationBarTheme.iconTheme!.resolve(<WidgetState>{}),
        isNull,
      );
    });

    test('background only → no iconTheme override', () {
      final theme = AppTheme.buildTheme(<String, dynamic>{
        'components': <String, dynamic>{
          'navigationBar': <String, dynamic>{'background': '0xFF000000'},
        },
      });
      expect(theme.navigationBarTheme.backgroundColor, const Color(0xFF000000));
      expect(theme.navigationBarTheme.iconTheme, isNull);
    });
  });

  group('T-4 input tokens', () {
    test('fillColor + radius + borderColor → InputDecorationTheme', () {
      final theme = AppTheme.buildTheme(<String, dynamic>{
        'components': <String, dynamic>{
          'input': <String, dynamic>{
            'fillColor': '0xFFFFFFFF',
            'borderColor': '0xFF900000',
            'radius': 12,
          },
        },
      });
      final input = theme.inputDecorationTheme;
      expect(input.filled, isTrue);
      expect(input.fillColor, const Color(0xFFFFFFFF));
      final border = input.enabledBorder as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(12));
      expect(border.borderSide.color, const Color(0xFF900000));
    });
  });

  group('T-5 chip token', () {
    test('chip.radius → ChipThemeData shape', () {
      final theme = AppTheme.buildTheme(<String, dynamic>{
        'components': <String, dynamic>{
          'chip': <String, dynamic>{'radius': 50},
        },
      });
      final shape = theme.chipTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(50));
    });
  });

  group('T-6 background tokens + ScaffoldBackground', () {
    test(
      'background.color overrides scaffold; omit keeps colors.background',
      () {
        final withToken = AppTheme.buildTheme(<String, dynamic>{
          'colors': <String, dynamic>{'background': '0xFFF9F9F9'},
          'background': <String, dynamic>{'color': '0xFFF5EFEB'},
        });
        expect(withToken.scaffoldBackgroundColor, const Color(0xFFF5EFEB));
        expect(withToken.extension<AppBackdropTokens>()!.overlayAsset, isNull);

        final without = AppTheme.buildTheme(<String, dynamic>{
          'colors': <String, dynamic>{'background': '0xFFF9F9F9'},
        });
        expect(without.scaffoldBackgroundColor, const Color(0xFFF9F9F9));
      },
    );

    test(
      'overlayAsset → AppBackdropTokens + rendered by ScaffoldBackground',
      () {
        final theme = AppTheme.buildTheme(<String, dynamic>{
          'background': <String, dynamic>{
            'overlayAsset': 'assets/images/city_map.png',
          },
        });
        expect(
          theme.extension<AppBackdropTokens>()!.overlayAsset,
          'assets/images/city_map.png',
        );
      },
    );
  });

  group('T-7 animationStyle token', () {
    test('subtle → shorter durations', () {
      final theme = AppTheme.buildTheme(<String, dynamic>{
        'animationStyle': 'subtle',
      });
      final motion = theme.extension<AppMotionTokens>()!;
      expect(motion.style, AppMotionStyle.subtle);
      expect(motion.standard, const Duration(milliseconds: 200));
      expect(motion.fast, const Duration(milliseconds: 120));
    });

    test('none → zero durations', () {
      final theme = AppTheme.buildTheme(<String, dynamic>{
        'animationStyle': 'none',
      });
      final motion = theme.extension<AppMotionTokens>()!;
      expect(motion.style, AppMotionStyle.none);
      expect(motion.standard, Duration.zero);
      expect(motion.slow, Duration.zero);
    });

    test(
      'malformed value is defensive: falls back to full (schema rejects)',
      () {
        final theme = AppTheme.buildTheme(<String, dynamic>{
          'animationStyle': 'bogus',
        });
        expect(theme.extension<AppMotionTokens>()!.style, AppMotionStyle.full);
      },
    );
  });

  group('T-8 typography split (headingFont/bodyFont)', () {
    tearDown(AppTheme.resetFontGuardForTest);

    test('heading/body fonts resolve from their own keys', () {
      AppTheme.setBundledFontFamiliesForTest({'PlayfairDisplay', 'Inter'});
      AppTheme.buildTheme(<String, dynamic>{
        'typography': <String, dynamic>{
          'fontFamily': 'Inter',
          'headingFont': 'PlayfairDisplay',
          'bodyFont': 'Inter',
        },
      });
      expect(AppTheme.headingFontFamily, 'PlayfairDisplay');
      expect(AppTheme.bodyFontFamily, 'Inter');
      expect(AppTheme.fontLoadError, isNull);
    });

    test('omitted split keys fall back to the single fontFamily', () {
      AppTheme.setBundledFontFamiliesForTest({'CarnamaSans'});
      AppTheme.buildTheme(<String, dynamic>{
        'typography': <String, dynamic>{'fontFamily': 'CarnamaSans'},
      });
      expect(AppTheme.headingFontFamily, 'CarnamaSans');
      expect(AppTheme.bodyFontFamily, 'CarnamaSans');
    });

    test('unregistered heading font → guard error + heading falls back', () {
      AppTheme.setBundledFontFamiliesForTest({'Inter'});
      AppTheme.buildTheme(<String, dynamic>{
        'typography': <String, dynamic>{
          'headingFont': 'Comic Serif MS',
          'bodyFont': 'Inter',
        },
      });
      expect(AppTheme.headingFontFamily, isNull); // guard-rejected
      expect(AppTheme.fontLoadError, contains('Comic Serif MS'));
      expect(AppTheme.bodyFontFamily, 'Inter');
    });
  });

  group('T-9 distinct-tokens widget pattern (COLOR-1 T-2 extended)', () {
    testWidgets(
      'two configs with different tokens render distinct Theme surfaces',
      (WidgetTester tester) async {
        final plain = AppTheme.buildTheme(<String, dynamic>{
          'colors': <String, dynamic>{'primary': '0xFFC84F00'},
        });
        final branded = AppTheme.buildTheme(<String, dynamic>{
          'colors': <String, dynamic>{'primary': '0xFF900000'},
          'shape': <String, dynamic>{'cardRadius': 4, 'ctaRadius': 100},
          'components': <String, dynamic>{
            'navigationBar': <String, dynamic>{
              'background': '0xFF1A1A1A',
              'activeColor': '0xFFFFA500',
            },
          },
          'animationStyle': 'subtle',
        });

        ThemeData? captured;
        await tester.pumpWidget(
          MaterialApp(
            // Zero theme-animation so Theme.of reflects the target theme on
            // the first frame (AnimatedTheme would otherwise lerp in).
            themeAnimationDuration: Duration.zero,
            theme: plain,
            home: Builder(
              builder: (context) {
                captured = Theme.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        final plainTheme = captured!;
        captured = null;

        await tester.pumpWidget(
          MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: branded,
            home: Builder(
              builder: (context) {
                captured = Theme.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        final brandedTheme = captured!;

        expect(
          (plainTheme.cardTheme.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(16),
        );
        expect(
          (brandedTheme.cardTheme.shape! as RoundedRectangleBorder)
              .borderRadius,
          BorderRadius.circular(4),
        );
        expect(plainTheme.navigationBarTheme.backgroundColor, isNull);
        expect(
          brandedTheme.navigationBarTheme.backgroundColor,
          const Color(0xFF1A1A1A),
        );
        expect(
          plainTheme.extension<AppMotionTokens>()!.style,
          AppMotionStyle.full,
        );
        expect(
          brandedTheme.extension<AppMotionTokens>()!.style,
          AppMotionStyle.subtle,
        );
      },
    );

    testWidgets('ScaffoldBackground renders the overlay only when configured', (
      WidgetTester tester,
    ) async {
      final withOverlay = AppTheme.buildTheme(<String, dynamic>{
        'background': <String, dynamic>{
          'overlayAsset': 'assets/images/city_map.png',
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: withOverlay,
          home: const ScaffoldBackground(child: Text('overlaid')),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('overlaid'), findsOneWidget);

      final without = AppTheme.buildTheme(<String, dynamic>{});
      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: without,
          home: const ScaffoldBackground(child: Text('plain')),
        ),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.text('plain'), findsOneWidget);
    });
  });

  group('T-10 ThemeExtension contract', () {
    test('AppShapeTokens copyWith/lerp/equality', () {
      const base = AppShapeTokens(cardRadius: 16, ctaRadius: 100);
      expect(base.copyWith(), base);
      expect(base.copyWith(cardRadius: 8).cardRadius, 8);
      expect(base.lerp(base, 0.5), base);
      expect(base == const AppShapeTokens(), isFalse);
    });

    test('AppMotionTokens presets differ as configured', () {
      expect(
        AppMotionTokens.forStyle(AppMotionStyle.full).standard,
        const Duration(milliseconds: 300),
      );
      expect(
        AppMotionTokens.forStyle(AppMotionStyle.subtle).standard,
        const Duration(milliseconds: 200),
      );
      expect(
        AppMotionTokens.forStyle(AppMotionStyle.none).standard,
        Duration.zero,
      );
    });
  });
}
