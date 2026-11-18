import 'package:demo_ai_workflow/core/theme/app_tokens.g.dart';
import 'package:flutter/material.dart';

export 'app_tokens.g.dart';

/// Maps generated design tokens onto Material's `ThemeData`.
///
/// Hand-written on purpose: token VALUES come from Figma (generated), but
/// how they map to components is an engineering decision reviewed in PRs.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppColorTokens.light);

  static ThemeData dark() => _build(Brightness.dark, AppColorTokens.dark);

  static ThemeData _build(Brightness brightness, AppColorTokens c) {
    // Seed first so every Material 3 role we don't have a token for
    // (primaryContainer, surfaceContainer*, outlineVariant, …) gets a
    // harmonious tonal value instead of collapsing to `primary`/`surface`.
    // Then override with the exact Figma tokens.
    final scheme =
        ColorScheme.fromSeed(
          seedColor: c.primary,
          brightness: brightness,
        ).copyWith(
          primary: c.primary,
          onPrimary: c.onPrimary,
          secondary: c.secondary,
          onSecondary: c.onSecondary,
          error: c.error,
          onError: c.onError,
          surface: c.surface,
          onSurface: c.onSurface,
          outline: c.outline,
        );
    final textTheme = AppTypography.textTheme.apply(
      bodyColor: c.onSurface,
      displayColor: c.onSurface,
    );
    // Figma: buttons are pills (Radius/full).
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.full)),
    );
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    );
    const fieldRadius = BorderRadius.all(Radius.circular(AppRadius.md));
    OutlineInputBorder fieldBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: c.surface,
      textTheme: textTheme,
      extensions: [c],
      // Figma "Text Field": light outline at rest, placeholder in a muted
      // tone, label rendered above the box by `AppTextField`.
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        border: fieldBorder(scheme.outlineVariant),
        enabledBorder: fieldBorder(scheme.outlineVariant),
        disabledBorder: fieldBorder(
          scheme.onSurface.withValues(alpha: 0.12),
        ),
        focusedBorder: fieldBorder(scheme.primary, width: 2),
        errorBorder: fieldBorder(scheme.error),
        focusedErrorBorder: fieldBorder(scheme.error, width: 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: buttonShape,
          padding: buttonPadding,
          textStyle: AppTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: buttonShape,
          padding: buttonPadding,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: AppTypography.labelLarge,
        ),
      ),
    );
  }
}

extension AppThemeContext on BuildContext {
  /// All color tokens, including ones Material has no slot for
  /// (e.g. `context.colors.success`). Falls back to the static tokens when
  /// a widget is rendered outside `AppTheme` (previews, other test setups)
  /// instead of crashing on a null extension.
  AppColorTokens get colors {
    final theme = Theme.of(this);
    return theme.extension<AppColorTokens>() ??
        (theme.brightness == Brightness.dark
            ? AppColorTokens.dark
            : AppColorTokens.light);
  }
}
