import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';

/// UI-11 (p23) W-5 `BrandedSplash` — library-only visual splash screen.
///
/// Implements §3 W-5 splash row: token-driven logo/name/loader slots,
/// zero business logic (stateless, owns no timers/futures/routing),
/// reduced-motion aware (spinner replaced with a static glyph when motion is
/// disabled).
class BrandedSplash extends StatelessWidget {
  const BrandedSplash({
    super.key,
    required this.appName,
    this.message,
    this.logo,
    this.showLoader = true,
  });

  /// The application name displayed below the logo mark.
  final String appName;

  /// Optional secondary message or status line (e.g. "Loading…").
  final String? message;

  /// Optional caller-supplied logo mark widget. When omitted, falls back
  /// to a branded restaurant icon slot.
  final Widget? logo;

  /// Whether to display the progress indicator. Defaults to `true`.
  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BrandColors.of(context);
    final primary = brand.primary;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final logoWidget =
        logo ??
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.restaurant, size: 40, color: primary),
        );

    final titleStyle =
        (theme.textTheme.headlineMedium ??
                const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))
            .copyWith(fontWeight: FontWeight.bold, color: brand.textPrimary);

    final msg = message;
    final messageStyle =
        (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
          color: brand.textSecondary,
        );

    return Scaffold(
      backgroundColor: brand.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Spacer(flex: 3),
                logoWidget,
                const SizedBox(height: 20),
                Text(appName, textAlign: TextAlign.center, style: titleStyle),
                if (msg != null && msg.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(msg, textAlign: TextAlign.center, style: messageStyle),
                ],
                const Spacer(flex: 2),
                if (showLoader)
                  SizedBox(
                    height: 48,
                    child: Center(
                      child: reduceMotion
                          ? Icon(Icons.hourglass_top, size: 28, color: primary)
                          : SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.8,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  primary,
                                ),
                              ),
                            ),
                    ),
                  )
                else
                  const SizedBox(height: 48),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
