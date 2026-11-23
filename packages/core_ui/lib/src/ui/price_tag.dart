import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:core_ui/src/ui/money_text.dart';
import 'package:flutter/material.dart';

/// Display-only money tag (UI-1, T-5).
///
/// MONEY-SAFETY LAW (spec L2): this widget NEVER computes on cents — it
/// formats exclusively through `moneyCents` (integer-cents display law,
/// LEDGER:PERF-10). The only comparison is the display-suppression rule that
/// hides a nonsensical compare-at (`compareAtCents <= cents`).
///
/// Merged semantics expose the full formatted sentence ("$5.00, was $9.99")
/// so screen readers read one coherent amount instead of fragments.
class PriceTag extends StatelessWidget {
  /// The price in integer cents (never recomputed, never rounded).
  final int cents;

  /// Optional original price; rendered strikethrough ONLY when strictly
  /// greater than [cents].
  final int? compareAtCents;

  /// ISO currency code forwarded to `moneyCents`.
  final String? currencyCode;

  /// Explicit symbol forwarded to `moneyCents` (overrides [currencyCode]).
  final String? currencySymbol;

  /// Prominent (22sp) variant for detail surfaces.
  final bool large;

  const PriceTag({
    super.key,
    required this.cents,
    this.compareAtCents,
    this.currencyCode,
    this.currencySymbol,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final main = moneyCents(
      cents,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
    );
    final compare = compareAtCents;
    final showCompare = compare != null && compare > cents;
    final secondary = BrandColors.of(context).textSecondary;

    return Semantics(
      container: true,
      label: showCompare
          ? '$main, was ${moneyCents(compare, currencyCode: currencyCode, currencySymbol: currencySymbol)}'
          : main,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            main,
            style: TextStyle(
              fontSize: large ? 22 : 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (showCompare) ...[
            const SizedBox(width: 6),
            Text(
              moneyCents(
                compare,
                currencyCode: currencyCode,
                currencySymbol: currencySymbol,
              ),
              style: TextStyle(
                fontSize: large ? 14 : 12,
                fontWeight: FontWeight.w500,
                color: secondary,
                decoration: TextDecoration.lineThrough,
                decorationColor: secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
