import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'money_text.dart';

/// Animated displayed-integer counter (UI-2 T-4).
///
/// Animates the displayed integer previous→new over `motion.standard`
/// (L6); every rendered frame is formatted through [moneyCents] (L2 —
/// display-only money law: no arithmetic beyond the tween itself). Currency
/// config is forwarded to every frame. `style: none` (or a zero standard
/// duration) jumps straight to the new value with no controller churn (L5).
class AnimatedCountText extends StatefulWidget {
  const AnimatedCountText(
    this.value, {
    super.key,
    this.style,
    this.currencyCode,
    this.currencySymbol,
    this.motion,
  });

  /// The target displayed value (integer cents).
  final int value;

  /// Text style for the rendered [Text].
  final TextStyle? style;

  /// Active currency code from client config (e.g. 'USD').
  final String? currencyCode;

  /// Explicit currency symbol override from client config.
  final String? currencySymbol;

  /// Optional explicit motion tokens; defaults to the ambient theme's
  /// [AppMotionTokens]. A MISSING token extension degrades to the `none`
  /// preset — the value is shown immediately, no animation (L5).
  final AppMotionTokens? motion;

  @override
  State<AnimatedCountText> createState() => _AnimatedCountTextState();
}

class _AnimatedCountTextState extends State<AnimatedCountText>
    with SingleTickerProviderStateMixin {
  /// L5 fail-safe preset: a MISSING token extension must land the content in
  /// its final state instead of animating it (never mid-flight).
  static final AppMotionTokens _noneMotion = AppMotionTokens.forStyle(
    AppMotionStyle.none,
  );

  late final AnimationController _controller;
  Animation<int>? _anim;
  AppMotionTokens? _lastMotion;
  int _displayedTarget = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _displayedTarget = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedCountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == _displayedTarget) return;
    final motion = widget.motion ?? _lastMotion ?? _noneMotion;
    if (motion.style == AppMotionStyle.none ||
        motion.standard <= Duration.zero) {
      // Jump straight to the new value — no controller churn.
      _controller.stop();
      _anim = null;
    } else {
      _anim = IntTween(
        begin: _anim?.value ?? _displayedTarget,
        end: widget.value,
      ).animate(CurvedAnimation(parent: _controller, curve: motion.curve));
      _controller
        ..duration = motion.standard
        ..forward(from: 0);
    }
    _displayedTarget = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _lastMotion =
        widget.motion ??
        Theme.of(context).extension<AppMotionTokens>() ??
        // L5 fail-safe: a MISSING token extension degrades to the final visual
        // state (the `none` preset) — the new value is shown immediately.
        _noneMotion;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _anim?.value ?? _displayedTarget;
        return Text(
          moneyCents(
            value,
            currencyCode: widget.currencyCode,
            currencySymbol: widget.currencySymbol,
          ),
          style: widget.style,
        );
      },
    );
  }
}
