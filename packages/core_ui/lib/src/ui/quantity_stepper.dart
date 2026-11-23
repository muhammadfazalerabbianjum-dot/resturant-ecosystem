import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A11y fallback tooltips (L3) — call sites are expected to pass localized
/// values; these exist so a quick integration never ships an unlabeled
/// control. Same documented-fallback precedent as
/// `GlobalErrorWidget.kGlobalErrorFallbackBody`.
const String kDefaultDecreaseTooltip = 'Decrease';
const String kDefaultIncreaseTooltip = 'Increase';

/// Clamped integer quantity step control (UI-1, T-10).
///
/// INTEGER-SAFE: emits exactly `value ± 1` within `[minValue, maxValue]`; the
/// button at a bound is DISABLED (null onPressed), so an out-of-range value
/// is unreachable through the UI — the state cannot drift. Haptic selection
/// feedback on every enabled press (BrandButton precedent).
class QuantityStepper extends StatelessWidget {
  /// The current value (owned by the caller).
  final int value;

  /// Emits the next value; always within bounds by construction.
  final ValueChanged<int> onChanged;

  /// Lower clamp (default 0).
  final int minValue;

  /// Upper clamp (default 99).
  final int maxValue;

  /// Semantic label for the decrement control.
  final String decrementTooltip;

  /// Semantic label for the increment control.
  final String incrementTooltip;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.minValue = 0,
    this.maxValue = 99,
    this.decrementTooltip = kDefaultDecreaseTooltip,
    this.incrementTooltip = kDefaultIncreaseTooltip,
  });

  void _emit(int next) {
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: decrementTooltip,
          onPressed: value > minValue ? () => _emit(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: brand.textSecondary,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: brand.textPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: incrementTooltip,
          onPressed: value < maxValue ? () => _emit(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
          color: brand.textSecondary,
        ),
      ],
    );
  }
}
