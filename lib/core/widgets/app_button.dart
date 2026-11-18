import 'package:demo_ai_workflow/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum AppButtonVariant { filled, outlined }

/// Primary action button of the design system.
///
/// - `isLoading` disables the button and swaps the label for a spinner
///   while keeping the button's size, so the layout doesn't jump.
/// - Screen readers hear "<label>, loading" instead of nothing.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.filled,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;

  /// Optional leading icon (e.g. an SSO logo). Decorative: the label
  /// already says what the button does.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final content = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: icon),
              const SizedBox(width: AppSpacing.md),
              Flexible(child: Text(label)),
            ],
          );
    final child = Stack(
      alignment: Alignment.center,
      children: [
        // Keeps the width of the label while loading.
        Opacity(opacity: isLoading ? 0 : 1, child: content),
        if (isLoading)
          const SizedBox.square(
            dimension: AppSize.iconSm,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
    final onTap = isLoading ? null : onPressed;

    return Semantics(
      button: true,
      label: isLoading ? '$label, loading' : null,
      excludeSemantics: isLoading,
      child: switch (variant) {
        AppButtonVariant.filled => FilledButton(
          onPressed: onTap,
          child: child,
        ),
        AppButtonVariant.outlined => OutlinedButton(
          onPressed: onTap,
          child: child,
        ),
      },
    );
  }
}
