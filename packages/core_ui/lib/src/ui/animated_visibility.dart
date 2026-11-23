import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Visibility fade (UI-2 T-5).
///
/// The [visible] flag fades opacity 1↔0 over `motion.standard` (L6). The
/// hidden state is `IgnorePointer` + `Offstage` after the fade settles —
/// findable only with `skipOffstage: false` — and the content is never
/// interactive while hidden (mid-fade included). `style: none` (or a zero
/// standard duration) switches instantly; content never throws, never
/// disappears from the tree (L5).
class AnimatedVisibility extends StatefulWidget {
  const AnimatedVisibility({
    super.key,
    required this.visible,
    required this.child,
    this.motion,
  });

  /// Whether the content is shown. Toggling drives the fade.
  final bool visible;

  /// The content kept alive (offstage) while hidden.
  final Widget child;

  /// Optional explicit motion tokens; defaults to the ambient theme's
  /// [AppMotionTokens]. A MISSING token extension degrades to the `none`
  /// preset — the content is placed in its final state, no animation (L5).
  final AppMotionTokens? motion;

  @override
  State<AnimatedVisibility> createState() => _AnimatedVisibilityState();
}

class _AnimatedVisibilityState extends State<AnimatedVisibility>
    with SingleTickerProviderStateMixin {
  /// L5 fail-safe preset: a MISSING token extension must land the content in
  /// its final state instead of animating it (never mid-flight).
  static final AppMotionTokens _noneMotion = AppMotionTokens.forStyle(
    AppMotionStyle.none,
  );

  late final AnimationController _controller;
  AppMotionTokens? _lastMotion;
  bool _settled = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: widget.visible ? 1.0 : 0.0,
    );
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if ((status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) &&
        !_settled) {
      setState(() => _settled = true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    final motion = widget.motion ?? _lastMotion ?? _noneMotion;
    if (motion.style == AppMotionStyle.none ||
        motion.standard <= Duration.zero) {
      // Instant switch — no controller churn. (Settled first so the status
      // listener below never calls setState during didUpdateWidget.)
      _settled = true;
      _controller.stop();
      _controller.value = widget.visible ? 1.0 : 0.0;
    } else {
      _controller.duration = motion.standard;
      if (widget.visible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      _settled = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion =
        widget.motion ??
        Theme.of(context).extension<AppMotionTokens>() ??
        // L5 fail-safe: a MISSING token extension lands the content in its
        // final state (the `none` preset) instead of animating it.
        _noneMotion;
    _lastMotion = motion;
    if (motion.style != AppMotionStyle.none &&
        motion.standard > Duration.zero) {
      _controller.duration = motion.standard;
    }
    final hidden = !widget.visible;
    return Offstage(
      offstage: hidden && _settled,
      child: IgnorePointer(
        ignoring: hidden,
        child: FadeTransition(opacity: _controller, child: widget.child),
      ),
    );
  }
}
