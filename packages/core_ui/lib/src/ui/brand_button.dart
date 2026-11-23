import 'package:core_ui/src/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BrandButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const BrandButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<BrandButton> createState() => _BrandButtonState();
}

class _BrandButtonState extends State<BrandButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed != null && !widget.isLoading) {
      HapticFeedback.lightImpact();
      _controller.forward().then((_) => _controller.reverse());
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    // P37 T-1: the foreground is derived from the ACTUAL fill so any client
    // hue clears WCAG AA — see AppColors.onColorFor (no fixed white).
    final fill = isEnabled
        ? Theme.of(context).primaryColor
        : AppColors.textSecondary;
    final fg = AppColors.onColorFor(fill);

    // P5-13 FIX: use a REAL ElevatedButton with onPressed — the button
    // provides semantics natively. No Semantics(onTap:) wrapper, no
    // GestureDetector onTapUp — exactly ONE tap path exists, so
    // accessibility mode cannot double-fire.
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: RepaintBoundary(child: child),
      ),
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: isEnabled ? _handleTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: fill,
            foregroundColor: fg,
            disabledBackgroundColor: AppColors.textSecondary,
            disabledForegroundColor: AppColors.onColorFor(
              AppColors.textSecondary,
            ),
          ),
          child: widget.isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: fg, strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: fg),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.text,
                        style: TextStyle(color: fg, fontSize: 16),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
