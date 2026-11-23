/// Spacing delegates over [SizedBox] (UI-4, p14).
///
/// Named constants use the frozen token engine's dimension vocabulary
/// (`AppDimensions.paddingS` = 8, `paddingM` = 16, and the 24 step), plus
/// parameterized `Gap.h(n)`/`Gap.v(n)` factories. Pure layout — no theme
/// reads, no decorative behavior.
library;

import 'package:flutter/widgets.dart';

import '../theme/app_dimensions.dart';

/// Horizontal/vertical gap widget.
class Gap extends StatelessWidget {
  const Gap._({this.width, this.height});

  /// Horizontal gap of exactly [n] logical pixels.
  factory Gap.h(double n) => Gap._(width: n);

  /// Vertical gap of exactly [n] logical pixels.
  factory Gap.v(double n) => Gap._(height: n);

  /// Horizontal gap of `AppDimensions.paddingS` (8).
  static final Gap h8 = Gap.h(AppDimensions.paddingS);

  /// Horizontal gap of `AppDimensions.paddingM` (16).
  static final Gap h16 = Gap.h(AppDimensions.paddingM);

  /// Horizontal gap of 24.
  static final Gap h24 = Gap.h(24);

  /// Vertical gap of `AppDimensions.paddingS` (8).
  static final Gap v8 = Gap.v(AppDimensions.paddingS);

  /// Vertical gap of `AppDimensions.paddingM` (16).
  static final Gap v16 = Gap.v(AppDimensions.paddingM);

  /// Vertical gap of 24.
  static final Gap v24 = Gap.v(24);

  /// The exact horizontal extent (null for vertical gaps).
  final double? width;

  /// The exact vertical extent (null for horizontal gaps).
  final double? height;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: height);
}
