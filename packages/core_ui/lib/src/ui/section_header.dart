/// Section header: title + optional action + optional subtitle (UI-4, p14).
///
/// Pure layout with caller-supplied strings (Law 3 — no hardcoded
/// user-facing strings). The title is bold (w700) and ellipsized when
/// overlong; the optional action widget is right-aligned; the optional
/// subtitle is secondary-colored via the ambient ColorScheme.
library;

import 'package:core_ui/src/theme/app_signature_tokens.dart';
import 'package:core_ui/src/ui/signature_rule.dart';
import 'package:flutter/material.dart';

/// A titled section header row.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  /// The section title — caller-supplied (localized at the call site).
  final String title;

  /// Optional secondary line beneath the title.
  final String? subtitle;

  /// Optional trailing widget (e.g. a "See all" link), right-aligned.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Q1: the signature motif leads EVERY section header when the client
    // opted in; absent tokens => the stock tree renders byte-identical.
    final hasSignature = theme.extension<AppSignatureTokens>() != null;
    final titleStyle = (theme.textTheme.titleLarge ?? const TextStyle())
        .copyWith(fontWeight: FontWeight.w700);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasSignature) ...[
                const SignatureRule(),
                const SizedBox(height: 6),
              ],
              Text(
                title,
                style: titleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: (theme.textTheme.bodyMedium ?? const TextStyle())
                      .copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}
