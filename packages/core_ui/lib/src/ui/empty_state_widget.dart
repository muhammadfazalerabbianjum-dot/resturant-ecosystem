import 'package:core_ui/src/theme/app_signature_tokens.dart';
import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:core_ui/src/ui/signature_rule.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? ctaText;
  final VoidCallback? onCtaPressed;
  final String? lottieUrl;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaText,
    this.onCtaPressed,
    this.lottieUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BrandColors.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      // Align, not a bare Column: Scaffold bodies, Stack children and
      // IndexedStack children all hand down LOOSE cross-axis constraints, so
      // a bare Column shrinks to its widest child and hugs the topStart
      // corner — on device the empty-state block rendered 88px left of
      // center (x=552 of 1280). Align fills any bounded width and centers
      // the column; under unbounded width it shrink-wraps exactly as a bare
      // Column would (no layout crash in rows/dialogs).
      child: Align(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Q1: the signature motif leads the empty state when the client
            // opted in; absent tokens => stock tree, byte-identical.
            if (theme.extension<AppSignatureTokens>() != null) ...[
              const SignatureRule(),
              const SizedBox(height: 16),
            ],
            if (lottieUrl != null)
              SizedBox(
                height: 180,
                child: Lottie.network(
                  lottieUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    icon,
                    size: 80,
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
              )
            else
              Icon(
                icon,
                size: 80,
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: brand.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (ctaText != null && onCtaPressed != null)
              ElevatedButton(onPressed: onCtaPressed, child: Text(ctaText!)),
          ],
        ),
      ),
    );
  }
}
