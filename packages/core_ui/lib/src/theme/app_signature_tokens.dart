/// Q1 (signature identity — impeccable critique 2026-10-02, P1 "category-
/// interchangeable aesthetic"): the ONE signature element a client opts into
/// through `theme.signature.style`, built by `AppTheme._themeFromConfig`.
///
/// The ABSENT extension is the b10 byte contract: when the config carries no
/// `theme.signature` block the extension is never attached, and every
/// consumer renders its stock tree — core_app's goldens (stock config) stay
/// pixel-identical while a rebranded shell can opt in from config alone.
library;

import 'package:flutter/material.dart';

@immutable
class AppSignatureTokens extends ThemeExtension<AppSignatureTokens> {
  const AppSignatureTokens({required this.style});

  /// Which signature motif to paint. The closed set is mirrored in BOTH
  /// config validators (`client_config.dart` + `tool/whitelabel.dart`, pinned
  /// by `whitelabel_schema_identity_test`).
  final AppSignatureStyle style;

  @override
  AppSignatureTokens copyWith({AppSignatureStyle? style}) =>
      AppSignatureTokens(style: style ?? this.style);

  @override
  AppSignatureTokens lerp(AppSignatureTokens? other, double t) {
    if (other == null) return this;
    // The style is a discrete enum — a swap either holds or flips.
    return t < 0.5 ? this : other;
  }

  @override
  bool operator ==(Object other) =>
      other is AppSignatureTokens && other.style == style;

  @override
  int get hashCode => style.hashCode;

  @override
  String toString() => 'AppSignatureTokens(style: $style)';
}

/// Closed set of signature motifs (config key `theme.signature.style`).
enum AppSignatureStyle {
  /// A short accent bar leading display copy (SectionHeader,
  /// EmptyStateWidget) — the first signature; extend the enum + both config
  /// validators together to add more.
  rule,
}
