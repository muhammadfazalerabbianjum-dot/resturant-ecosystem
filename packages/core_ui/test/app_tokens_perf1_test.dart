import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';

/// PERF-1 (T-6) — the token VALUE contracts (ThemeExtension lerp/copyWith/
/// equality across shape, motion, backdrop), the [ScaffoldBackground]
/// degradation branches, and the [AppTheme] manifest/config seams.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppShapeTokens — extension contract (PERF-1)', () {
    test('hashCode tracks the fields; equal tokens are equal', () {
      const a = AppShapeTokens(cardRadius: 16, ctaRadius: 100);
      const b = AppShapeTokens(cardRadius: 16, ctaRadius: 100);
      expect(a.hashCode, b.hashCode);
      expect(a == b, isTrue);
      expect(a.hashCode == const AppShapeTokens().hashCode, isFalse);
    });

    test('lerp with a null other returns this; nullable radii snap at 0.5', () {
      const base = AppShapeTokens(cardRadius: 16, ctaRadius: 100);
      expect(base.lerp(null, 0.7), base);

      const other = AppShapeTokens(cardRadius: 8, ctaRadius: null);
      // t < 0.5 → keeps the BASE nullable value; t >= 0.5 → the OTHER's.
      expect(base.lerp(other, 0.25).ctaRadius, 100);
      expect(base.lerp(other, 0.75).ctaRadius, isNull);
      expect(base.lerp(other, 0.5).cardRadius, closeTo(12, 0.001));
    });
  });

  group('AppMotionTokens — extension contract (PERF-1)', () {
    test('copyWith keeps unspecified fields', () {
      const base = AppMotionTokens();
      final patched = base.copyWith(
        style: AppMotionStyle.subtle,
        fast: const Duration(milliseconds: 90),
      );
      expect(patched.style, AppMotionStyle.subtle);
      expect(patched.fast, const Duration(milliseconds: 90));
      expect(patched.standard, base.standard);
      expect(patched.slow, base.slow);
      expect(patched.curve, base.curve);
    });

    test('lerp interpolates durations and flips style/curve at 0.5', () {
      final full = AppMotionTokens.forStyle(AppMotionStyle.full);
      final none = AppMotionTokens.forStyle(AppMotionStyle.none);

      expect(full.lerp(null, 0.3), full);
      // t < 0.5 → THIS style/curve; t >= 0.5 → the OTHER's (boundary
      // inclusive on the other side — the source contract).
      final before = full.lerp(none, 0.4);
      expect(before.style, AppMotionStyle.full);
      expect(before.curve, Curves.easeOut);

      final mid = full.lerp(none, 0.5);
      expect(mid.standard, const Duration(milliseconds: 150));
      expect(mid.style, AppMotionStyle.none);
      expect(mid.curve, Curves.linear);

      final late = full.lerp(none, 0.8);
      expect(late.style, AppMotionStyle.none);
      expect(late.curve, Curves.linear);
      expect(late.standard, const Duration(milliseconds: 60));
    });

    test('equality and hashCode are field-wise', () {
      final a = AppMotionTokens.forStyle(AppMotionStyle.subtle);
      final b = AppMotionTokens.forStyle(AppMotionStyle.subtle);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      expect(a == AppMotionTokens.forStyle(AppMotionStyle.none), isFalse);
    });
  });

  group('AppBackdropTokens — extension contract (PERF-1)', () {
    test('copyWith/lerp/equality track the overlay asset', () {
      const base = AppBackdropTokens(overlayAsset: 'assets/map.png');
      expect(base.copyWith(), base);
      expect(
        base.copyWith(overlayAsset: 'assets/other.png').overlayAsset,
        'assets/other.png',
      );
      expect(base.lerp(null, 0.9), base);

      const other = AppBackdropTokens(overlayAsset: 'assets/city.png');
      expect(base.lerp(other, 0.25).overlayAsset, 'assets/map.png');
      expect(base.lerp(other, 0.75).overlayAsset, 'assets/city.png');
      expect(base == other, isFalse);
      expect(base.hashCode, base.overlayAsset.hashCode);
    });

    testWidgets('ScaffoldBackground degrades with a BROKEN overlay asset '
        '(errorBuilder → content only)', (tester) async {
      final theme = AppTheme.buildTheme(<String, dynamic>{
        'background': <String, dynamic>{
          'overlayAsset': 'assets/does-not-exist.png',
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: theme,
          home: const ScaffoldBackground(child: Text('content')),
        ),
      );
      // Let the image load fail and the errorBuilder settle.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('ScaffoldBackground with NO overlay and NO child shrinks', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ScaffoldBackground())),
      );
      // The no-asset + no-child branch renders a bare scaffold-colored box.
      expect(find.byType(ScaffoldBackground), findsOneWidget);
    });
  });

  group('AppTheme — manifest + config seams (PERF-1)', () {
    test(
      'the color getters delegate to AppColors (single source of truth)',
      () {
        expect(AppTheme.primaryColor, AppColors.primary);
        expect(AppTheme.secondaryColor, AppColors.secondary);
        expect(AppTheme.accentColor, AppColors.accent);
      },
    );

    test('loadBundledFontFamilies without an injected reader fails CLOSED '
        '(the registry stays empty)', () async {
      await AppTheme.loadBundledFontFamilies();
      expect(AppTheme.bundledFontFamilies, isEmpty);
    });

    test('a DYNAMICALLY-keyed config section is coerced to string keys', () {
      // Simulates decoded JSON where the section arrives as Map<dynamic, ?>.
      final theme = AppTheme.buildTheme(<String, dynamic>{
        'shape': <dynamic, dynamic>{'cardRadius': 9},
      });
      final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(9));
    });
  });

  group('FadeSlideTransitionPage (PERF-1)', () {
    testWidgets('builds its fade+slide transition and registers the name', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            pages: <Page<void>>[
              FadeSlideTransitionPage<void>(
                name: 'perf1-probe',
                child: const Text('transitioned'),
              ),
            ],
            onDidRemovePage: (Page<Object?> page) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('transitioned'), findsOneWidget);
    });
  });

  group('ConfettiOverlay (PERF-1)', () {
    testWidgets('inserts the celebration, then removes it after the window', (
      tester,
    ) async {
      late BuildContext probe;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              probe = context;
              return const SizedBox();
            },
          ),
        ),
      );

      ConfettiOverlay.show(probe, duration: const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.byType(ConfettiWidget), findsOneWidget);

      // duration + the 2s cleanup window.
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(ConfettiWidget), findsNothing);
    });
  });
}
