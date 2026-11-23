import 'package:core_ui/src/theme/app_signature_tokens.dart';
import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:flutter/material.dart';

/// Q1 signature motif — the ONE element carried across surfaces
/// (impeccable critique 2026-10-02, P1).
///
/// Renders the [AppSignatureStyle.rule] bar in the client's brand accent.
/// Defensive double-guard: when the theme carries no [AppSignatureTokens]
/// (the b10 byte contract — config never opted in) it paints NOTHING, so a
/// caller may place it unconditionally without breaking the stock tree.
class SignatureRule extends StatelessWidget {
  const SignatureRule({super.key});

  /// Intrinsic size of the rule bar (fixed — not a magic number per surface).
  static const Size barSize = Size(28, 3);

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppSignatureTokens>();
    if (tokens == null) return const SizedBox.shrink();
    return switch (tokens.style) {
      AppSignatureStyle.rule => DecoratedBox(
        decoration: BoxDecoration(
          color: BrandColors.of(context).accent,
          borderRadius: BorderRadius.circular(barSize.height),
        ),
        child: SizedBox(width: barSize.width, height: barSize.height),
      ),
    };
  }
}
