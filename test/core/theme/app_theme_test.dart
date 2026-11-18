import 'package:demo_ai_workflow/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (name, theme, tokens) in [
    ('light', AppTheme.light(), AppColorTokens.light),
    ('dark', AppTheme.dark(), AppColorTokens.dark),
  ]) {
    test('$name theme maps tokens onto ColorScheme', () {
      expect(theme.colorScheme.primary, tokens.primary);
      expect(theme.colorScheme.onPrimary, tokens.onPrimary);
      expect(theme.colorScheme.surface, tokens.surface);
      expect(theme.extension<AppColorTokens>(), tokens);
    });
  }

  test('Material 3 roles without a token get tonal values, not copies', () {
    final scheme = AppTheme.light().colorScheme;
    expect(scheme.primaryContainer, isNot(scheme.primary));
    expect(scheme.surfaceContainerHighest, isNot(scheme.surface));
    expect(scheme.onSurfaceVariant, isNot(scheme.onSurface));
  });

  testWidgets('context.colors exposes non-Material tokens', (tester) async {
    late Color success;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            success = context.colors.success;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(success, AppColorTokens.light.success);
  });

  testWidgets('context.colors falls back when AppTheme is not used', (
    tester,
  ) async {
    late Color error;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(
          builder: (context) {
            error = context.colors.error;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(error, AppColorTokens.dark.error);
  });

  test('light/dark tokens interpolate for animated theme switches', () {
    final mid = AppColorTokens.light.lerp(AppColorTokens.dark, 0.5);
    expect(mid.primary, isNot(AppColorTokens.light.primary));
    expect(AppColorTokens.light.lerp(null, 0.5), AppColorTokens.light);
  });
}
