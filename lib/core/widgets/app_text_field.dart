import 'package:demo_ai_workflow/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Text input with its label ABOVE the box and a placeholder inside
/// (Figma "Text Field": `.Header` + `.Input`).
///
/// The visible label is excluded from semantics and attached to the field
/// instead, so screen readers announce "Username, text field" as one node.
/// - Figma: https://www.figma.com/design/oPeUQfgMIErzZ7BIWwzkMz/?node-id=615-2183
///   (instance of "Text Field"; no component-set link yet).
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.enabled = true,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.suffixIcon,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool enabled;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          label: label,
          child: TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscureText,
            autocorrect: autocorrect,
            enableSuggestions: enableSuggestions,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(hintText: hint, suffixIcon: suffixIcon),
          ),
        ),
      ],
    );
  }
}
