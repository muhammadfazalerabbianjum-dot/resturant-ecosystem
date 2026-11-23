import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Entrance animation (UI-2 T-2): fades 0→1 and slides from `Offset(0, 0.05)`
/// (the shared baseline) to zero over `motion.standard`, auto-playing on
/// mount. Resolves [AppMotionTokens] from the ambient theme (L6); `none` (or
/// a zero standard duration) renders the final state immediately with no
/// controller churn (L5/L6). A missing token extension degrades to the
/// documented `full` default — the content always reaches full visibility,
/// never stays invisible (L5).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.motion});

  /// The content entering the scene.
  final Widget child;

  /// Optional explicit motion tokens; defaults to the ambient theme's
  /// [AppMotionTokens]. A MISSING token extension degrades to the `none`
  /// preset — the final visual state, no animation (L5).
  final AppMotionTokens? motion;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _opacity;
  Animation<Offset>? _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion =
        widget.motion ??
        Theme.of(context).extension<AppMotionTokens>() ??
        // L5 fail-safe: a MISSING token extension degrades to the final visual
        // state (the `none` preset) — the entrance never leaves content
        // invisible or mid-flight.
        AppMotionTokens.forStyle(AppMotionStyle.none);
    _controller.duration = motion.standard;
    final curved = CurvedAnimation(parent: _controller, curve: motion.curve);
    _opacity = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(curved);
    if (motion.style == AppMotionStyle.none ||
        motion.standard <= Duration.zero) {
      // Instant final state — no controller churn.
      _controller.value = 1.0;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity!,
      child: SlideTransition(position: _slide!, child: widget.child),
    );
  }
}
