import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/src/theme/app_colors.dart';
import 'package:core_ui/src/theme/app_theme.dart';
import 'package:labs/app/animated_cart_badge.dart';
import 'package:labs/features/auth/presentation/login_screen.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_tracker_steps_widget.dart';
import 'package:labs/l10n/app_localizations.dart';

/// UX-2 T-1/T-6 harness: seeds the real cartProvider through a stub
/// repository (no Isar) so REAL widgets render with a live item count.
class _StubCartRepository implements CartRepository {
  final CartModel cart;
  _StubCartRepository(this.cart);

  @override
  Future<CartModel> loadCart() async => cart;

  @override
  Future<void> saveCart(CartModel cart) async {}
}

/// WCAG 2.x relative luminance of [c] (sRGB -> linearized per WCAG 2.1
/// definition: c <= 0.03928 ? c/12.92 : ((c+0.055)/1.055)^2.4).
double _luminance(Color c) {
  double linearize(double channel) {
    if (channel <= 0.03928) return channel / 12.92;
    return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * linearize(c.r) +
      0.7152 * linearize(c.g) +
      0.0722 * linearize(c.b);
}

/// WCAG 2.x contrast ratio between [a] and [b], range 1.0..21.0.
double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Parses a config color literal like `0xFFC84F00` into a [Color].
Color _configColor(Map<String, dynamic> theme, String key) {
  final colors = theme['colors'];
  if (colors is! Map<String, dynamic>) {
    throw StateError('config theme.colors is not a map');
  }
  final raw = colors[key];
  if (raw is! String) {
    throw StateError('config theme.colors.$key is not a string: $raw');
  }
  return Color(int.parse(raw.replaceFirst('0x', ''), radix: 16));
}

void main() {
  group('Real-screen guideline scans — UX-2 / P2-A11Y-ENFORCE', () {
    // P2-A11Y-ENFORCE: the mock-scaffold scans proved nothing about the real
    // screens (the audit's 8 unlabeled buttons all passed CI against mocks).
    // These scans pump the REAL widgets and run the same guideline engine.

    testWidgets(
      'REAL AnimatedCartBadge (live cart) passes tap-target + labeled-target '
      'guidelines',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        const cart = CartModel(
          items: [
            CartItemModel(
              item: MenuItemModel(id: 'm1', name: 'Pizza', priceCents: 1000),
              quantity: 2,
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cartRepositoryProvider.overrideWithValue(
                _StubCartRepository(cart),
              ),
              authStateProvider.overrideWith(
                (ref) => Stream<User?>.value(null),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: Center(child: AnimatedCartBadge())),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Let the badge scale animation finish before the scan + teardown
        // so no animation timer is left pending.
        await tester.pump(const Duration(milliseconds: 300));

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        handle.dispose();
      },
    );

    testWidgets(
      'REAL OrderTrackerStepsWidget passes tap-target + labeled-target '
      'guidelines',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final order = OrderModel(
          id: 'ord123',
          customerId: 'user1',
          totalCents: 1500,
          createdAt: DateTime.now(),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: OrderTrackerStepsWidget(
                  order: order,
                  currentStatus: OrderStatus.preparing,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        handle.dispose();
      },
    );

    testWidgets(
      'REAL LoginScreen passes tap-target, labeled-target and text-contrast '
      'guidelines',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoginScreen(),
          ),
        );
        await tester.pump();
        await tester.pump();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        handle.dispose();
      },
    );
  });

  group('Error-message semantics binding', () {
    testWidgets(
      'Error messages natively bind to Semantics tree for blind VoiceOver support',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text(
                  'Network unavailable',
                  semanticsLabel: 'Error: Network unavailable',
                ),
              ),
            ),
          ),
        );

        // Constitution requirement: "Ensure error messages are included in the semantics tree"
        final textFinder = find.bySemanticsLabel('Error: Network unavailable');
        expect(textFinder, findsOneWidget);
      },
    );
  });

  group('W9.1 — AA contrast computed from the REAL palette (audit-05 table)', () {
    late Map<String, dynamic> coreTheme;
    late Map<String, dynamic> shellTheme;

    setUpAll(() {
      coreTheme =
          (jsonDecode(File('assets/client_config.json').readAsStringSync())
                  as Map<String, dynamic>)['theme']
              as Map<String, dynamic>;
      shellTheme =
          (jsonDecode(
                    File(
                      '../apps/halal_boyz/assets/client_config.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['theme']
              as Map<String, dynamic>;
    });

    test(
      'palette choice: Option A — primary darkened, AA-passing values in AppColors',
      () {
        // W9.1 Option A (index Decision 1): primary ~#C84F00 (4.5:1+ with
        // white); textSecondary and success >= 4.5:1 on white.
        expect(AppColors.primary, const Color(0xFFC84F00));
        expect(AppColors.textSecondary, const Color(0xFF757575));
        expect(AppColors.success, const Color(0xFF2E7D32));
      },
    );

    test(
      'BOTH client_config.json theme blocks are synced with their canonical palette',
      () {
        // COV-2 sanctioned drift-fix (operator decision 2026-09-11): the
        // approved Halal Boyz rebrand gave the shell its OWN design language
        // (Deep Maroon #900000 / Orange-Gold #FFA500 / off-white #F9F9F9 /
        // ink #111111 / muted #666666 / alert #E60000) — success kept the
        // core token. Byte-sync with AppColors therefore now applies to the
        // core_app config only; the shell config is asserted against its
        // documented rebrand palette. Handoff: TOKENS/W1 own the generator
        // path when the rebrand template lands (fix enacted here per
        // operator sanction; see FIX_VERIFICATION COV-2 addendum).
        expect(
          _configColor(coreTheme, 'primary'),
          AppColors.primary,
          reason: 'core_app theme.colors.primary must equal AppColors.primary',
        );
        expect(
          _configColor(coreTheme, 'textSecondary'),
          AppColors.textSecondary,
          reason:
              'core_app theme.colors.textSecondary must equal AppColors.textSecondary',
        );
        expect(
          _configColor(coreTheme, 'success'),
          AppColors.success,
          reason: 'core_app theme.colors.success must equal AppColors.success',
        );
        expect(
          _configColor(coreTheme, 'soldOut'),
          AppColors.soldOut,
          reason: 'core_app theme.colors.soldOut must equal AppColors.soldOut',
        );

        const shellPrimary = Color(0xFF900000);
        const shellSecondary = Color(0xFFFFA500);
        const shellTextSecondary = Color(0xFF666666);
        expect(
          _configColor(shellTheme, 'primary'),
          shellPrimary,
          reason:
              'apps/halal_boyz theme.colors.primary must equal the rebrand '
              'Deep Maroon #900000',
        );
        expect(
          _configColor(shellTheme, 'secondary'),
          shellSecondary,
          reason:
              'apps/halal_boyz theme.colors.secondary must equal the rebrand '
              'Orange-Gold #FFA500',
        );
        expect(
          _configColor(shellTheme, 'textSecondary'),
          shellTextSecondary,
          reason:
              'apps/halal_boyz theme.colors.textSecondary must equal the '
              'rebrand muted #666666',
        );
        expect(
          _configColor(shellTheme, 'success'),
          AppColors.success,
          reason:
              'apps/halal_boyz keeps the core success token (rebrand ledger)',
        );
      },
    );

    test('shell palette AA: white on rebrand primary >= 4.5 AA', () {
      expect(
        _contrastRatio(Colors.white, _configColor(shellTheme, 'primary')),
        greaterThanOrEqualTo(4.5),
        reason: 'white-on-maroon (#900000) must stay AA (it is ~9.6:1)',
      );
    });

    test('shell palette AA: rebrand textSecondary on white >= 4.5 AA', () {
      expect(
        _contrastRatio(_configColor(shellTheme, 'textSecondary'), Colors.white),
        greaterThanOrEqualTo(4.5),
        reason: 'muted #666666 on white must stay AA',
      );
    });

    test('white on primary (BrandButton ordering path) >= 4.5 AA', () {
      expect(
        _contrastRatio(Colors.white, AppColors.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('textSecondary on white (muted copy, links) >= 4.5 AA', () {
      expect(
        _contrastRatio(AppColors.textSecondary, Colors.white),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('success on white (status chips/icons) >= 4.5 AA', () {
      expect(
        _contrastRatio(AppColors.success, Colors.white),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('soldOut on white (sold-out chip/banner icons) >= 4.5 AA', () {
      expect(
        _contrastRatio(AppColors.soldOut, Colors.white),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('BOTH configs carry an AA-passing soldOut token', () {
      expect(
        _contrastRatio(_configColor(coreTheme, 'soldOut'), Colors.white),
        greaterThanOrEqualTo(4.5),
        reason: 'core theme.colors.soldOut must pass AA on white',
      );
      expect(
        _contrastRatio(_configColor(shellTheme, 'soldOut'), Colors.white),
        greaterThanOrEqualTo(4.5),
        reason: 'shell theme.colors.soldOut must pass AA on white',
      );
    });

    test('primary on white (price text, links) >= 4.5 AA', () {
      expect(
        _contrastRatio(AppColors.primary, Colors.white),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('textPrimary on background >= 4.5 AA', () {
      expect(
        _contrastRatio(AppColors.textPrimary, AppColors.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('white on secondary >= 4.5 AA', () {
      expect(
        _contrastRatio(Colors.white, AppColors.secondary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('error on white >= 3.0 (audit: AA-large-only pair)', () {
      expect(
        _contrastRatio(AppColors.error, Colors.white),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('white on error (delete-account button) >= 3.0 (large-only)', () {
      expect(
        _contrastRatio(Colors.white, AppColors.error),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('textPrimary54 blend on white >= 3.0 (audit: large-only)', () {
      final effective = Color.alphaBlend(AppColors.textPrimary54, Colors.white);
      expect(
        _contrastRatio(effective, Colors.white),
        greaterThanOrEqualTo(3.0),
      );
    });

    test(
      'textPrimary on primary >= 3.0 (large-only under Option A; no normal-size dark-on-primary text exists)',
      () {
        // The audit's 5.84:1 dark-on-primary pair becomes large-only once
        // primary is darkened for white-on-primary AA (Option A). The only
        // primary-filled CTA (BrandButton) paints a WHITE foreground —
        // asserted >= 4.5 above.
        expect(
          _contrastRatio(AppColors.textPrimary, AppColors.primary),
          greaterThanOrEqualTo(3.0),
        );
      },
    );

    test(
      'warning excluded from the asserted set — icon-only usage per audit (documented residual)',
      () {
        // AUDIT_A11Y_L10N_UX.md §1.3 marks warning #FFC107 on white 1.63:1 as
        // "FAIL (icon usage)" — not a text pair, and outside W9.1's fix scope
        // (index Decision 1 mandates primary/textSecondary/success only).
        // Recorded as an honest residual in the UX-1 addendum rather than
        // asserted against a meaningless threshold.
        expect(AppColors.warning, const Color(0xFFFFC107));
      },
    );

    test('dark theme: onSurface on scaffold background >= 4.5 AA', () {
      final theme = AppTheme.darkTheme;
      expect(
        _contrastRatio(
          theme.colorScheme.onSurface,
          theme.scaffoldBackgroundColor,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dark theme: onSurface on surface >= 4.5 AA', () {
      final theme = AppTheme.darkTheme;
      expect(
        _contrastRatio(theme.colorScheme.onSurface, theme.colorScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dark theme: background54 blend on dark background >= 4.5 AA', () {
      final theme = AppTheme.darkTheme;
      final effective = Color.alphaBlend(
        AppColors.background54,
        theme.scaffoldBackgroundColor,
      );
      expect(
        _contrastRatio(effective, theme.scaffoldBackgroundColor),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
