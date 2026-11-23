import 'package:core_ui/src/theme/app_colors.dart';
import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:core_ui/src/ui/shapes.dart';
import 'package:flutter/material.dart';

/// Selectable stadium chip (UI-1, T-3).
///
/// Colors resolve from [BrandColors.of] (config-driven, COLOR-1): selected =
/// brand primary fill with the BrandButton-precedent [AppColors.background]
/// foreground (AA-pass on brand hues); unselected = brand surface with a
/// `textSecondary` outline. State changes animate via [AnimatedContainer].
class BrandChip extends StatelessWidget {
  /// The chip label (caller-supplied — L3: no hardcoded strings).
  final String label;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether the chip is selected.
  final bool selected;

  /// Optional tap callback (exactly one tap path — InkWell, semantics native).
  final VoidCallback? onTap;

  const BrandChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    final background = selected ? brand.primary : brand.surface;
    // P37 T-1: derived foreground — AA for any client primary (no fixed white).
    final foreground = selected
        ? AppColors.onColorFor(background)
        : brand.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BrandShapes.borderPill,
        border: Border.all(
          color: selected ? brand.primary : brand.textSecondary,
        ),
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BrandShapes.borderPill,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
