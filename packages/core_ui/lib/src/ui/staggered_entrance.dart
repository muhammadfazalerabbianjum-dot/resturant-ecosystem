import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Staggered entrance (UI-2 T-3): N children enter with a per-index delay of
/// `index * stagger` (default 60 ms, scaled by the motion style), each
/// fading/sliding in exactly like [FadeSlideIn]. Order is preserved.
/// Resolves [AppMotionTokens] from the ambient theme (L6); `none` renders all
/// children in their final state immediately (L5/L6).
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.children,
    this.stagger = const Duration(milliseconds: 60),
    this.motion,
  });

  /// Children in visual order; index i is delayed by i * [stagger].
  final List<Widget> children;

  /// Delay between consecutive children (full-style reference; scaled by the
  /// resolved style's standard/300 ratio).
  final Duration stagger;

  /// Optional explicit motion tokens; defaults to the ambient theme's
  /// [AppMotionTokens]. A MISSING token extension degrades to the `none`
  /// preset — the final visual state, no animation (L5).
  final AppMotionTokens? motion;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  static const int _referenceStandardMs = 300;

  late final AnimationController _controller;
  List<Animation<double>>? _fades;
  List<Animation<Offset>>? _slides;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  int _scaledStaggerMs(AppMotionTokens motion) {
    if (motion.style == AppMotionStyle.none) return 0;
    final ratio = motion.standard.inMilliseconds / _referenceStandardMs;
    return (widget.stagger.inMilliseconds * ratio).round();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion =
        widget.motion ??
        Theme.of(context).extension<AppMotionTokens>() ??
        // L5 fail-safe: a MISSING token extension degrades to the final visual
        // state (the `none` preset) — every child is rendered immediately.
        AppMotionTokens.forStyle(AppMotionStyle.none);
    final n = widget.children.length;
    final staggerMs = _scaledStaggerMs(motion);
    final standardMs = motion.standard.inMilliseconds;
    final totalMs = standardMs + (n > 0 ? (n - 1) * staggerMs : 0);
    _controller.duration = Duration(milliseconds: totalMs);
    final fades = <Animation<double>>[];
    final slides = <Animation<Offset>>[];
    for (var i = 0; i < n; i++) {
      // Child i animates inside its own window [i*stagger, i*stagger+standard]
      // mapped onto the single controller timeline.
      final t0 = totalMs <= 0 ? 0.0 : (i * staggerMs) / totalMs;
      final t1 = totalMs <= 0 ? 1.0 : (i * staggerMs + standardMs) / totalMs;
      final curved = CurvedAnimation(
        parent: _controller,
        curve: Interval(t0, t1, curve: motion.curve),
      );
      fades.add(curved);
      slides.add(
        Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curved),
      );
    }
    _fades = fades;
    _slides = slides;
    if (motion.style == AppMotionStyle.none || totalMs <= 0) {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          FadeTransition(
            opacity: _fades![i],
            child: SlideTransition(
              position: _slides![i],
              child: widget.children[i],
            ),
          ),
      ],
    );
  }
}
