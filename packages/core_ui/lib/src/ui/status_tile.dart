import 'package:core_ui/src/theme/app_tokens.dart';
import 'package:core_ui/src/ui/brand_badge.dart';
import 'package:flutter/material.dart';

/// The tri-state tile status (UI-3, T-4).
enum TileStatus { ok, pending, failed }

/// Status tile (UI-3, T-4).
///
/// Renders the caller-supplied status label through a [BrandBadge] with the
/// tone resolved by the pure static [toneFor] mapping:
/// `ok → positive`, `pending → neutral`, `failed → negative` (pairwise
/// distinct — asserted by the batch suite). Colors stay on the token chain
/// (L1); the badge text is caller-supplied (L3); the tap surface is a
/// native [InkWell] (0.10).
class StatusTile extends StatelessWidget {
  /// The status driving the badge tone.
  final TileStatus status;

  /// The status label (caller-supplied, L3) — shown in the badge.
  final String label;

  /// Optional tap callback; `null` renders an inert tile.
  final VoidCallback? onTap;

  const StatusTile({
    super.key,
    required this.status,
    required this.label,
    this.onTap,
  });

  /// The pure static `TileStatus → BadgeTone` mapping (no instance state,
  /// no theme reads — trivially testable).
  static BadgeTone toneFor(TileStatus status) => switch (status) {
    TileStatus.ok => BadgeTone.positive,
    TileStatus.pending => BadgeTone.neutral,
    TileStatus.failed => BadgeTone.negative,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shapeTokens =
        theme.extension<AppShapeTokens>() ?? const AppShapeTokens();
    final spacing = AppSpacing.of(context);

    final Widget content = Padding(
      padding: EdgeInsets.all(spacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [BrandBadge(label: label, tone: toneFor(status))],
      ),
    );

    return Material(
      color: theme.colorScheme.surface,
      elevation: theme.extension<AppDepthTokens>()?.elevation ?? 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(shapeTokens.cardRadius),
      ),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
