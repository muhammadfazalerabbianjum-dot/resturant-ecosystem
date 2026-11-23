import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_tokens.dart';

/// Reusable FadeSlide transition for GoRouter pages.
/// Provides a consistent entrance feel across the entire app.
class FadeSlideTransitionPage<T> extends CustomTransitionPage<T> {
  /// `name` is forwarded to [CustomTransitionPage] so the active route's
  /// registered name reaches `RouteSettings.name` — that is what
  /// `FirebaseAnalyticsObserver`'s default name extractor reads to emit
  /// `screen_view` (UX-4 / W9.12 contract #2: without it the observer would
  /// register but never fire on these pages).
  ///
  /// OPTIONAL motion seam (UI-2 T-6): when [motion] is supplied the route
  /// duration is `motion.standard` and the slide uses `motion.curve`; when
  /// omitted, behavior is byte-identical to the legacy shared baseline
  /// (300 ms / `Curves.easeOut` / `Offset(0, 0.05)`).
  FadeSlideTransitionPage({
    required super.child,
    super.key,
    super.name,
    AppMotionTokens? motion,
  }) : super(
         transitionDuration:
             motion?.standard ?? const Duration(milliseconds: 300),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curve = motion?.curve ?? Curves.easeOut;
           return FadeTransition(
             opacity: animation,
             child: SlideTransition(
               position: Tween<Offset>(
                 begin: const Offset(0, 0.05),
                 end: Offset.zero,
               ).animate(CurvedAnimation(parent: animation, curve: curve)),
               child: child,
             ),
           );
         },
       );
}
