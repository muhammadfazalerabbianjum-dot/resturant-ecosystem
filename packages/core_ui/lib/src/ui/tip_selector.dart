import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:core_ui/src/ui/brand_chip.dart';
import 'package:flutter/material.dart';

/// One candidate tip option (UI-11 / W-1, T-1).
///
/// **L24 (tip/gift numeric law):** [label] MUST arrive already formatted by the
/// caller's money authority (e.g. `moneyCents(...)` composed with the client's
/// localisation). This class stores it verbatim and never parses, scales or
/// re-renders it; [value] is opaque to the library — typically the caller's
/// percentage or the caller's own already-computed amount, echoed back
/// untouched so the caller stays the single money authority.
@immutable
class TipOption<T> {
  /// The value handed back to the caller when this option is chosen.
  ///
  /// The library never interprets it (no multiplication, rounding or
  /// formatting): it is a selection token.
  final T value;

  /// Caller-supplied, already-formatted, already-localised display string.
  final String label;

  const TipOption({required this.value, required this.label});
}

/// Tip/gift preset selector (UI-11 / W-1, T-1) — money-adjacent, display-only.
///
/// **L24:** this widget performs NO money arithmetic and owns NO money state.
/// It renders the caller's preset [options] as branded chips, reports the
/// chosen [TipOption] back through [onChanged], and optionally shows a custom
/// entry affordance ([customLabel]/[onCustomTapped]) plus a summary line whose
/// text the caller supplies via [selectedSummaryLabel]. Every string on screen
/// comes from the caller; the widest money-related thing in here is a
/// `String`.
///
/// Compositional, not duplicated: the chip surface is the frozen UI-1
/// [BrandChip] (L27 — consumed, never edited).
class TipSelector<T> extends StatelessWidget {
  /// The caller's preset candidates, in display order.
  final List<TipOption<T>> options;

  /// The caller's current selection (null => nothing chosen yet).
  final TipOption<T>? selectedOption;

  /// Emits the exact [TipOption] the user chose.
  final ValueChanged<TipOption<T>>? onChanged;

  /// Optional caller-supplied heading.
  final String? title;

  /// Optional caller-supplied summary text for the current selection.
  ///
  /// The callback receives the selected [TipOption] and returns the final
  /// rendered string, so no money text is ever produced by this widget.
  final String Function(TipOption<T> option)? selectedSummaryLabel;

  /// Optional caller-supplied label for the custom-amount affordance.
  final String? customLabel;

  /// Emitted when the custom-amount affordance is tapped.
  final VoidCallback? onCustomTapped;

  const TipSelector({
    super.key,
    required this.options,
    this.selectedOption,
    this.onChanged,
    this.title,
    this.selectedSummaryLabel,
    this.customLabel,
    this.onCustomTapped,
  });

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    final heading = title;
    final custom = customLabel;
    final summary = selectedSummaryLabel;
    final selected = selectedOption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (heading != null) ...<Widget>[
          Text(
            heading,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: brand.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final option in options) _buildOption(option),
            if (custom != null)
              BrandChip(
                label: custom,
                icon: Icons.edit_outlined,
                onTap: onCustomTapped,
              ),
          ],
        ),
        if (summary != null && selected != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            summary(selected),
            style: TextStyle(color: brand.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  Widget _buildOption(TipOption<T> option) {
    final isSelected = option.value == selectedOption?.value;
    return Semantics(
      selected: isSelected,
      button: true,
      child: BrandChip(
        label: option.label,
        selected: isSelected,
        onTap: onChanged == null ? null : () => onChanged!(option),
      ),
    );
  }
}
