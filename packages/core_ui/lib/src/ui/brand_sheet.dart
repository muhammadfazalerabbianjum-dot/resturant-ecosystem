import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:core_ui/src/ui/brand_button.dart';
import 'package:core_ui/src/ui/shapes.dart';
import 'package:flutter/material.dart';

/// Confirmation bottom sheet (UI-11 / W-4, T-4).
///
/// **L25 (barrier contract):** [show] wraps `showModalBottomSheet` with
/// `barrierDismissible: false` by DEFAULT — a money-confirming sheet cannot
/// be swiped/tapped away by accident; callers opt in explicitly. The widget
/// itself is pure presentation: branded header/actions, a focus-safe
/// [SafeArea] and `Semantics(scopesRoute: true)` around caller-supplied
/// content. Callbacks are limited to [onConfirm]/[onCancel] (each also closes
/// the route — visibility is the only state this layer owns).
class BrandSheet extends StatelessWidget {
  /// Caller-supplied, already-localised header (L3).
  final String title;

  /// Caller-supplied scrollable body.
  final Widget child;

  /// Tapped by the confirm action; also closes the sheet.
  final VoidCallback? onConfirm;

  /// Tapped by the cancel action; also closes the sheet.
  final VoidCallback? onCancel;

  /// Caller-supplied confirm label; absent => no confirm action (L3).
  final String? confirmLabel;

  /// Caller-supplied cancel label; absent => no cancel action (L3).
  final String? cancelLabel;

  const BrandSheet({
    super.key,
    required this.title,
    required this.child,
    this.onConfirm,
    this.onCancel,
    this.confirmLabel,
    this.cancelLabel,
  });

  /// Presents [builder]'s sheet. **L25 default: not dismissable** —
  /// [barrierDismissible] must be opted into deliberately (it also unlocks
  /// the drag-to-dismiss path via `isDismissible`).
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      // ModalBottomSheetRoute.barrierDismissible mirrors isDismissible, so
      // this one switch controls both the barrier tap and the drag path.
      isDismissible: barrierDismissible,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    final actions = <Widget>[
      if (cancelLabel != null)
        Expanded(
          child: BrandButton(
            text: cancelLabel!,
            onPressed: onCancel == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    onCancel!();
                  },
          ),
        ),
      if (cancelLabel != null && confirmLabel != null)
        const SizedBox(width: 12),
      if (confirmLabel != null)
        Expanded(
          child: BrandButton(
            text: confirmLabel!,
            onPressed: onConfirm == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    onConfirm!();
                  },
          ),
        ),
    ];
    final maxScroll = MediaQuery.sizeOf(context).height * 0.5;
    return Semantics(
      container: true,
      scopesRoute: true,
      explicitChildNodes: true,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: brand.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(BrandShapes.large),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: brand.textSecondary,
                  borderRadius: BrandShapes.borderPill,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: brand.textPrimary,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxScroll),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: child,
                ),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(children: actions),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
