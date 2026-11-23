import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:core_ui/src/ui/brand_button.dart';
import 'package:core_ui/src/ui/shapes.dart';
import 'package:flutter/material.dart';

/// Confirmation dialog (UI-11 / W-4, T-4).
///
/// **L25 (barrier contract):** [show] wraps `showDialog` with
/// `barrierDismissible: false` by DEFAULT (money-confirming dialogs must be
/// answered, never tapped away); callers opt in explicitly. The widget is
/// pure presentation: branded title/actions, a focus-safe [SafeArea],
/// scroll-safe content and `Semantics(scopesRoute: true)`. Callbacks are
/// limited to [onConfirm]/[onCancel] (each also closes the dialog —
/// visibility is the only state this layer owns).
class BrandDialog extends StatelessWidget {
  /// Caller-supplied, already-localised header (L3).
  final String title;

  /// Caller-supplied scrollable body.
  final Widget child;

  /// Tapped by the confirm action; also closes the dialog.
  final VoidCallback? onConfirm;

  /// Tapped by the cancel action; also closes the dialog.
  final VoidCallback? onCancel;

  /// Caller-supplied confirm label; absent => no confirm action (L3).
  final String? confirmLabel;

  /// Caller-supplied cancel label; absent => no cancel action (L3).
  final String? cancelLabel;

  const BrandDialog({
    super.key,
    required this.title,
    required this.child,
    this.onConfirm,
    this.onCancel,
    this.confirmLabel,
    this.cancelLabel,
  });

  /// Presents [builder]'s dialog. **L25 default: not dismissable.**
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
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
    final maxScroll = MediaQuery.sizeOf(context).height * 0.45;
    return Semantics(
      container: true,
      scopesRoute: true,
      explicitChildNodes: true,
      child: SafeArea(
        child: AlertDialog(
          backgroundColor: brand.surface,
          shape: RoundedRectangleBorder(borderRadius: BrandShapes.borderLarge),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: brand.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxScroll),
                child: SingleChildScrollView(child: child),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(children: actions),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
