import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Form field wiring (UI-1, T-9) on top of the AMBIENT `InputDecorationTheme`.
///
/// Chrome rule (b10 contract): the client-config input theme owns borders and
/// fill — this widget deliberately does NOT override either, so a configured
/// `theme.components.input` styles it and an unconfigured app gets the
/// Material default. This widget owns WIRING only: label/hint/error, obscure,
/// enabled, keyboard parameters, input formatters (optional sanitiser
/// passthrough — p21 seam), prefix icon, and the change/submit/validate
/// callbacks (validator reachable through `Form.validate`).
class BrandTextField extends StatelessWidget {
  /// Controls the text being edited (forwarded).
  final TextEditingController? controller;

  /// Focus node (forwarded).
  final FocusNode? focusNode;

  /// Floating label (caller-supplied — L3).
  final String? labelText;

  /// Placeholder hint (caller-supplied — L3).
  final String? hintText;

  /// Error line (caller-supplied; also set by `Form.validate` via [validator]).
  final String? errorText;

  /// Whether the text is obscured (passwords).
  final bool obscureText;

  /// Whether the field accepts input.
  final bool enabled;

  /// Keyboard type (forwarded).
  final TextInputType? keyboardType;

  /// Keyboard action button (forwarded).
  final TextInputAction? textInputAction;

  /// Input sanitiser (forwarded verbatim — p21 seam, DECISIONS).
  ///
  /// Additive and optional: a caller whose pre-adoption raw `TextField`
  /// carried a `FilteringTextInputFormatter` (e.g. the checkout promo-code
  /// field) would otherwise have to DROP that sanitiser to adopt this widget.
  /// WIRING only — this widget never composes or relaxes a formatter.
  final List<TextInputFormatter>? inputFormatters;

  /// Optional leading icon inside the field.
  final IconData? prefixIcon;

  /// Optional trailing widget inside the field (forwarded verbatim — p21 H2
  /// seam, DECISIONS).
  ///
  /// Additive and optional: a caller whose pre-adoption raw `TextField` carried
  /// a suffix control (the home search's clear `IconButton`) would otherwise
  /// have to DROP that affordance to adopt this widget. WIRING only — the
  /// suffix widget is composed by the caller, never here.
  final Widget? suffixIcon;

  /// Platform autofill hints (forwarded verbatim — p21 D1 seam, DECISIONS).
  ///
  /// Additive and optional: a caller whose pre-adoption `TextField` carried
  /// `autofillHints` (the auth screens' UX-2 credential contract) would
  /// otherwise have to DROP the platform password-manager wiring to adopt
  /// this widget. WIRING only — no hint is composed here.
  final Iterable<String>? autofillHints;

  /// Maximum lines (default 1).
  final int? maxLines;

  /// Per-edit callback.
  final ValueChanged<String>? onChanged;

  /// Keyboard submit callback.
  final ValueChanged<String>? onFieldSubmitted;

  /// Validation hook — exercised by `FormState.validate()`.
  final FormFieldValidator<String>? validator;

  const BrandTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.autofillHints,
    this.maxLines = 1,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        errorText: errorText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon,
      ),
      obscureText: obscureText,
      enabled: enabled,
      autofillHints: autofillHints,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
    );
  }
}
