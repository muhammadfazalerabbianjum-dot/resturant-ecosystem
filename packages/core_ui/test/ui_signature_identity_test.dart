/// Q1 (signature identity — impeccable critique 2026-10-02, P1 "category-
/// interchangeable aesthetic"): ONE signature element carried across
/// surfaces, config-gated through `theme.signature.style`.
///
/// The ABSENT path is a byte contract (b10): a theme without
/// [AppSignatureTokens] must render the stock tree with NO rule widget, so
/// core_app's goldens (which ship no signature config) stay pixel-identical.
/// The PRESENT path paints [SignatureRule] in SectionHeader and
/// EmptyStateWidget — the motif the critique asked to carry "across every
/// surface".
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(ThemeData theme, Widget child) => MaterialApp(
    theme: theme,
    home: Scaffold(body: child),
  );

  ThemeData themedWithSignature() =>
      AppTheme.buildTheme(const <String, dynamic>{}).copyWith(
        extensions: const <ThemeExtension<dynamic>>[
          AppSignatureTokens(style: AppSignatureStyle.rule),
        ],
      );

  group('Q1 signature identity (config-gated motif)', () {
    testWidgets(
      'absent tokens: SectionHeader renders NO signature rule (b10 byte contract)',
      (tester) async {
        final theme = AppTheme.buildTheme(const <String, dynamic>{});
        await tester.pumpWidget(
          host(theme, const SectionHeader(title: 'Popular today')),
        );
        expect(find.byType(SignatureRule), findsNothing);
        expect(find.text('Popular today'), findsOneWidget);
      },
    );

    testWidgets('absent tokens: EmptyStateWidget renders NO signature rule', (
      tester,
    ) async {
      final theme = AppTheme.buildTheme(const <String, dynamic>{});
      await tester.pumpWidget(
        host(
          theme,
          const EmptyStateWidget(
            icon: Icons.inbox_outlined,
            title: 'No orders yet',
            subtitle: 'New orders will land here.',
          ),
        ),
      );
      expect(find.byType(SignatureRule), findsNothing);
    });

    testWidgets(
      'present tokens: SectionHeader paints SignatureRule ABOVE the title',
      (tester) async {
        await tester.pumpWidget(
          host(themedWithSignature(), const SectionHeader(title: 'Drinks')),
        );
        expect(find.byType(SignatureRule), findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(SignatureRule)).dy,
          lessThan(tester.getTopLeft(find.text('Drinks')).dy),
          reason: 'the motif sits above the section title',
        );
      },
    );

    testWidgets('present tokens: EmptyStateWidget paints SignatureRule', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          themedWithSignature(),
          const EmptyStateWidget(
            icon: Icons.inbox_outlined,
            title: 'No orders yet',
            subtitle: 'New orders will land here.',
          ),
        ),
      );
      expect(find.byType(SignatureRule), findsOneWidget);
    });

    testWidgets('SignatureRule paints the brand accent bar (28x3)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(themedWithSignature(), const SignatureRule()),
      );
      expect(tester.getSize(find.byType(SignatureRule)), const Size(28, 3));
    });

    test(
      'AppSignatureTokens copyWith carries the style (extension contract)',
      () {
        const tokens = AppSignatureTokens(style: AppSignatureStyle.rule);
        expect(tokens.copyWith(), tokens);
        expect(tokens, const AppSignatureTokens(style: AppSignatureStyle.rule));
        expect(tokens.lerp(tokens, 0.5), tokens);
      },
    );
  });
}
