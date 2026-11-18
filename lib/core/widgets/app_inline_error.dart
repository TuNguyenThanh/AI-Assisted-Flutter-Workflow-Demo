import 'package:demo_ai_workflow/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Inline form error. `liveRegion` makes TalkBack/VoiceOver announce it
/// when it appears, otherwise blind users never learn why login failed.
class AppInlineError extends StatelessWidget {
  const AppInlineError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.colors.error),
      ),
    );
  }
}
