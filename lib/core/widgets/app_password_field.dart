import 'package:demo_ai_workflow/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// Password input with a show/hide toggle. Owns only the visibility state;
/// the text lives in the caller's controller.
///
/// Icon follows the Figma spec: eye-off while the password is hidden.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    required this.controller,
    this.label = 'Password',
    this.hint,
    this.enabled = true,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      enabled: widget.enabled,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: const [AutofillHints.password],
      onSubmitted: widget.onSubmitted,
      suffixIcon: IconButton(
        tooltip: _obscure ? 'Show password' : 'Hide password',
        icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}
