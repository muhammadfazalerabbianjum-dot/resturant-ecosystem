import 'package:flutter/material.dart';

/// Shape vocabulary for the core UI library (UI-1,
/// `WHITE_LABEL_p11_ui1_shapes.md` T-1).
///
/// Centralizes the borderRadius language so batch components stay consistent
/// and the client-config shape token ([AppShapeTokens], b10) has a canonical
/// fallback set. Pure statics — zero instance state, zero theme reads: this
/// is the FALLBACK vocabulary; theme-connected components resolve
/// [AppShapeTokens] first and fall back to these constants (Law 3 chain).
abstract final class BrandShapes {
  /// Small radius for chips, badges, tags.
  static const double small = 8;

  /// Medium radius for inputs, banners, steppers.
  static const double medium = 12;

  /// Large radius for cards and modals (the frozen cardTheme default).
  static const double large = 16;

  /// Stadium radius for pill shapes (any width).
  static const double pill = 999;

  /// Small rounded-rectangle border.
  static BorderRadius get borderSmall => BorderRadius.circular(small);

  /// Medium rounded-rectangle border.
  static BorderRadius get borderMedium => BorderRadius.circular(medium);

  /// Large rounded-rectangle border.
  static BorderRadius get borderLarge => BorderRadius.circular(large);

  /// Full pill/stadium border.
  static BorderRadius get borderPill => BorderRadius.circular(pill);

  /// The menu-item "tile" shape: large radius with an optional border side.
  static RoundedRectangleBorder tileShape({Color? borderColor}) =>
      RoundedRectangleBorder(
        borderRadius: borderLarge,
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor),
      );

  /// A stadium [OutlinedBorder] for pills and chips.
  static const StadiumBorder stadium = StadiumBorder();

  /// A rounded-rect [OutlinedBorder] at the medium radius, with an optional
  /// side (no side = [BorderSide.none], the Flutter 3.x non-nullable form).
  static RoundedRectangleBorder outlinedMedium({
    Color? color,
    double width = 1,
  }) => RoundedRectangleBorder(
    borderRadius: borderMedium,
    side: color == null
        ? BorderSide.none
        : BorderSide(color: color, width: width),
  );
}
