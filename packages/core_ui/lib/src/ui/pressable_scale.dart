import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Pure press-feedback transform wrapper (UI-2 T-1).
///
/// While pressed, [child] scales to 0.96 (the BrandButton press precedent)
/// over `motion.fast` with `motion.curve`; on release or cancel it returns to
/// 1.0. Resolves [AppMotionTokens] from the ambient theme (L6). With
/// `style: none` there is no controller and no transform — the tap still
/// fires (L5/L6). Pure wrapper (L7): no haptics here — callers (e.g.
/// BrandButton) already own them, so wrapping must never double-fire.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.motion,
  });

  /// The content wrapped by the press transform. Semantics are untouched.
  final Widget child;

  /// Forwarded exactly once per completed tap. `null` disables press state.
  final VoidCallback? onTap;

  /// Optional explicit motion tokens; defaults to the ambient theme's
  /// [AppMotionTokens]. A MISSING token extension degrades to the `none`
  /// preset — the final visual state, no animation (L5).
  final AppMotionTokens? motion;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  static const double _pressedScale = 0.96;

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final motion =
        widget.motion ??
        Theme.of(context).extension<AppMotionTokens>() ??
        // L5 fail-safe: a MISSING token extension degrades to the final visual
        // state (the `none` preset) rather than animating content that could
        // be left mid-flight; only explicit tokens animate.
        AppMotionTokens.forStyle(AppMotionStyle.none);
    // `none` (or a zero fast duration) → zero controller churn: plain child.
    final animate =
        motion.style != AppMotionStyle.none && motion.fast > Duration.zero;
    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _pressed = false),
      onTap: widget.onTap == null
          ? null
          : () {
              setState(() => _pressed = false);
              widget.onTap!();
            },
      child: animate
          ? AnimatedScale(
              scale: _pressed ? _pressedScale : 1.0,
              duration: motion.fast,
              curve: motion.curve,
              child: widget.child,
            )
          : widget.child,
    );
  }
}
