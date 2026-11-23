import 'package:core_ui/src/theme/app_colors.dart';
import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:core_ui/src/ui/shapes.dart';
import 'package:flutter/material.dart';

/// One option of a [SegmentSelector] (UI-11 / W-1, T-1).
///
/// [label] is caller-supplied and already localised (L3 — the library never
/// hardcodes copy). [value] is the caller's own type: the selector echoes it
/// back verbatim through `onChanged` and performs no interpretation on it
/// (L2/L24-class law: no arithmetic, no formatting).
@immutable
class SegmentOption<T> {
  /// The value handed back to the caller when this segment is chosen.
  final T value;

  /// Caller-supplied, already-localised label.
  final String label;

  /// When false the segment renders but cannot be chosen.
  final bool enabled;

  /// When true the segment renders a loader and cannot be chosen.
  final bool loading;

  const SegmentOption({
    required this.value,
    required this.label,
    this.enabled = true,
    this.loading = false,
  });

  /// A segment is choosable only when enabled and not loading.
  ///
  /// Disabled and loading are deliberately separate flags (an empty-string
  /// label is not an error state, and a loader is not a permanent disable) but
  /// they share the same interaction guard.
  bool get selectable => enabled && !loading;
}

/// Generic N-option segmented control (UI-11 / W-1, T-1).
///
/// Pure presentation, caller-owned state: the widget reads
/// [selectedValue]/[segments] and reports taps through [onChanged]. It keeps
/// no state of its own, so it cannot drift from the caller's model. Colour
/// resolution rides [BrandColors] (L1 — frozen token engine, never
/// [AppColors] hues beyond the documented transparent/on-brand foreground
/// precedents). Layout is a plain [Row] of equal-width segments, so RTL
/// mirroring is the ambient [Directionality]'s job — no manual reordering.
class SegmentSelector<T> extends StatelessWidget {
  /// The ordered options; first is left-most in LTR (right-most in RTL).
  final List<SegmentOption<T>> segments;

  /// The caller's current selection (may be null => nothing selected).
  final T? selectedValue;

  /// Emits the selected option's exact [SegmentOption.value].
  final ValueChanged<T>? onChanged;

  const SegmentSelector({
    super.key,
    required this.segments,
    required this.selectedValue,
    this.onChanged,
  });

  void _select(SegmentOption<T> option) {
    if (!option.selectable) return;
    final handler = onChanged;
    if (handler == null) return;
    handler(option.value);
  }

  Widget _buildSegment(BuildContext context, SegmentOption<T> option) {
    final brand = BrandColors.of(context);
    final isSelected = option.value == selectedValue;
    // P37 T-1: derived foreground — AA for any client primary (no fixed white).
    final foreground = isSelected
        ? AppColors.onColorFor(brand.primary)
        : brand.textSecondary;

    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        enabled: option.enabled,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? brand.primary : brand.surface,
            borderRadius: BrandShapes.borderMedium,
            border: Border.all(
              color: isSelected ? brand.primary : brand.textSecondary,
            ),
          ),
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              onTap: option.selectable ? () => _select(option) : null,
              borderRadius: BrandShapes.borderMedium,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Center(
                  child: option.loading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          option.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final option in segments) _buildSegment(context, option),
      ],
    );
  }
}
