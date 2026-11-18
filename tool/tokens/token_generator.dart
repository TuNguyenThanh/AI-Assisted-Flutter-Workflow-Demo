/// Design-token generator: `design/tokens.json` -> Flutter theme code.
///
/// Pure functions (no IO) so every rule is unit-tested in
/// `test/tool/token_generator_test.dart`. The CLI lives in
/// `tool/generate_tokens.dart`.
library;

import 'dart:math' as math;

/// Color roles the app theme maps onto `ColorScheme`. Figma must provide
/// them in every mode, otherwise generation fails.
const requiredColorRoles = [
  'primary',
  'onPrimary',
  'secondary',
  'onSecondary',
  'error',
  'onError',
  'surface',
  'onSurface',
  'outline',
];

/// `TextTheme` slots. Typography tokens with these names are wired into
/// `AppTypography.textTheme` automatically.
const textThemeSlots = {
  'displayLarge', 'displayMedium', 'displaySmall', //
  'headlineLarge', 'headlineMedium', 'headlineSmall',
  'titleLarge', 'titleMedium', 'titleSmall',
  'bodyLarge', 'bodyMedium', 'bodySmall',
  'labelLarge', 'labelMedium', 'labelSmall',
};

/// WCAG AA for normal text.
const minContrast = 4.5;

class TokenException implements Exception {
  TokenException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'Invalid design tokens:\n- ${errors.join('\n- ')}';
}

class TypographyToken {
  const TypographyToken({
    required this.fontSize,
    required this.fontWeight,
    this.lineHeight,
    this.letterSpacing,
    this.fontFamily,
  });

  final double fontSize;
  final int fontWeight;
  final double? lineHeight;
  final double? letterSpacing;
  final String? fontFamily;
}

class DesignTokens {
  const DesignTokens({
    required this.colors,
    required this.spacing,
    required this.radius,
    required this.typography,
    this.size = const {},
    this.source,
  });

  /// mode (light/dark) -> role -> ARGB int.
  final Map<String, Map<String, int>> colors;
  final Map<String, double> spacing;
  final Map<String, double> radius;

  /// Component sizes (icons, avatars, touch targets). Optional.
  final Map<String, double> size;
  final Map<String, TypographyToken> typography;

  /// Figma file/node the tokens came from (for traceability).
  final String? source;
}

final _identifier = RegExp(r'^[a-z][a-zA-Z0-9]*$');
final _hex = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

/// Figma writes alpha LAST (`#RRGGBBAA`), Flutter wants it FIRST
/// (`0xAARRGGBB`). Getting this wrong silently ships wrong colors.
int parseHexColor(String value) {
  if (!_hex.hasMatch(value)) {
    throw FormatException('Not a #RRGGBB or #RRGGBBAA color: $value');
  }
  final hex = value.substring(1);
  final rgb = int.parse(hex.substring(0, 6), radix: 16);
  final alpha = hex.length == 8 ? int.parse(hex.substring(6), radix: 16) : 255;
  return (alpha << 24) | rgb;
}

double relativeLuminance(int argb) {
  double channel(int shift) {
    final c = ((argb >> shift) & 0xFF) / 255;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}

double contrastRatio(int a, int b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Parses and validates the normalized token JSON. Collects ALL errors
/// so one run tells the designer/dev everything that is wrong.
DesignTokens parseTokens(Map<String, dynamic> json) {
  final errors = <String>[];

  Map<String, dynamic> section(String key, {bool optional = false}) {
    final value = json[key];
    if (value is Map<String, dynamic>) return value;
    if (optional && value == null) return const {};
    errors.add('"$key" must be an object');
    return const {};
  }

  void checkName(String group, String name) {
    if (!_identifier.hasMatch(name)) {
      errors.add('$group "$name" must be lowerCamelCase (e.g. "onPrimary")');
    }
  }

  // Colors -----------------------------------------------------------------
  final colors = <String, Map<String, int>>{};
  for (final MapEntry(key: mode, value: roles) in section('color').entries) {
    if (roles is! Map<String, dynamic>) {
      errors.add('color.$mode must be an object');
      continue;
    }
    final parsed = <String, int>{};
    for (final MapEntry(key: role, value: hex) in roles.entries) {
      checkName('color', role);
      try {
        parsed[role] = parseHexColor('$hex');
      } on FormatException catch (e) {
        errors.add('color.$mode.$role: ${e.message}');
      }
    }
    colors[mode] = parsed;
  }
  for (final mode in ['light', 'dark']) {
    if (!colors.containsKey(mode)) errors.add('color.$mode is missing');
  }
  if (colors.length > 1) {
    final reference = colors.values.first.keys.toSet();
    for (final MapEntry(key: mode, value: roles) in colors.entries) {
      final keys = roles.keys.toSet();
      final missing = reference.difference(keys);
      final extra = keys.difference(reference);
      if (missing.isNotEmpty || extra.isNotEmpty) {
        errors.add(
          'color.$mode roles differ from other modes '
          '(missing: ${missing.join(', ')}; extra: ${extra.join(', ')})',
        );
      }
    }
  }
  for (final MapEntry(key: mode, value: roles) in colors.entries) {
    for (final role in requiredColorRoles) {
      if (!roles.containsKey(role)) {
        errors.add('color.$mode.$role is required');
      }
    }
    // Every `onX` must be readable on `X`.
    for (final MapEntry(key: role, value: fg) in roles.entries) {
      if (!role.startsWith('on') || role.length < 3) continue;
      final base = role[2].toLowerCase() + role.substring(3);
      final bg = roles[base];
      if (bg == null) continue;
      final ratio = contrastRatio(fg, bg);
      if (ratio < minContrast) {
        errors.add(
          'color.$mode.$role on $base has contrast '
          '${ratio.toStringAsFixed(2)}:1 (< $minContrast:1 WCAG AA)',
        );
      }
    }
  }

  // Dimensions -------------------------------------------------------------
  Map<String, double> dimensions(String key, {bool optional = false}) {
    final out = <String, double>{};
    for (final MapEntry(key: name, value: v) in section(
      key,
      optional: optional,
    ).entries) {
      checkName(key, name);
      if (v is num && v >= 0) {
        out[name] = v.toDouble();
      } else {
        errors.add('$key.$name must be a non-negative number, got $v');
      }
    }
    return out;
  }

  final spacing = dimensions('spacing');
  final radius = dimensions('radius');
  final size = dimensions('size', optional: true);

  // Typography -------------------------------------------------------------
  final typography = <String, TypographyToken>{};
  for (final MapEntry(key: name, value: v) in section('typography').entries) {
    checkName('typography', name);
    if (v is! Map<String, dynamic>) {
      errors.add('typography.$name must be an object');
      continue;
    }
    final size = v['fontSize'];
    final weight = v['fontWeight'] ?? 400;
    if (size is! num || size <= 0) {
      errors.add('typography.$name.fontSize must be > 0');
      continue;
    }
    if (weight is! int || weight < 100 || weight > 900 || weight % 100 != 0) {
      errors.add('typography.$name.fontWeight must be 100..900 step 100');
      continue;
    }
    typography[name] = TypographyToken(
      fontSize: size.toDouble(),
      fontWeight: weight,
      lineHeight: (v['lineHeight'] as num?)?.toDouble(),
      letterSpacing: (v['letterSpacing'] as num?)?.toDouble(),
      fontFamily: v['fontFamily'] as String?,
    );
  }

  if (errors.isNotEmpty) throw TokenException(errors);
  return DesignTokens(
    colors: colors,
    spacing: spacing,
    radius: radius,
    size: size,
    typography: typography,
    source: json[r'$source'] as String?,
  );
}

/// Font families used by typography tokens that are not declared under
/// `flutter: fonts:` in pubspec — they would silently fall back to the
/// platform font.
Set<String> undeclaredFontFamilies(DesignTokens t, String pubspec) {
  final declared = RegExp(r'^\s*-\s*family:\s*(.+)$', multiLine: true)
      .allMatches(pubspec)
      .map((m) => m.group(1)!.trim().replaceAll(RegExp('[\'"]'), ''))
      .toSet();
  return t.typography.values
      .map((s) => s.fontFamily)
      .whereType<String>()
      .where((f) => !declared.contains(f))
      .toSet();
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

String _color(int argb) =>
    'Color(0x${argb.toRadixString(16).padLeft(8, '0').toUpperCase()})';

/// Renders the Dart source (unformatted; the CLI runs `dart format`).
String renderDart(DesignTokens t) {
  final b = StringBuffer()
    ..writeln('// GENERATED by tool/generate_tokens.dart from')
    ..writeln('// design/tokens.json. DO NOT EDIT — run /figma-tokens or')
    ..writeln('// `dart run tool/generate_tokens.dart` instead.')
    ..writeln(t.source == null ? '' : '// Source: ${t.source}')
    ..writeln('// ignore_for_file: type=lint')
    ..writeln()
    ..writeln("import 'package:flutter/material.dart';")
    ..writeln();

  void constants(String cls, String doc, Map<String, double> values) {
    b
      ..writeln('/// $doc')
      ..writeln('abstract final class $cls {');
    for (final MapEntry(:key, :value) in values.entries) {
      b.writeln('  static const double $key = ${_num(value)};');
    }
    b
      ..writeln('}')
      ..writeln();
  }

  constants('AppSpacing', 'Spacing scale (logical px).', t.spacing);
  constants('AppRadius', 'Corner radius scale (logical px).', t.radius);
  if (t.size.isNotEmpty) {
    constants('AppSize', 'Component sizes (logical px).', t.size);
  }

  // Typography
  b
    ..writeln('/// Text styles. Colors come from the theme, not from here.')
    ..writeln('abstract final class AppTypography {');
  for (final MapEntry(key: name, value: s) in t.typography.entries) {
    b
      ..writeln('  static const TextStyle $name = TextStyle(')
      ..writeln(
        s.fontFamily == null ? '' : "    fontFamily: '${s.fontFamily}',",
      )
      ..writeln('    fontSize: ${_num(s.fontSize)},')
      ..writeln('    fontWeight: FontWeight.w${s.fontWeight},');
    if (s.lineHeight != null) {
      // Figma line height is in px, Flutter `height` is a multiplier.
      b.writeln('    height: ${_num(s.lineHeight!)} / ${_num(s.fontSize)},');
    }
    if (s.letterSpacing != null) {
      b.writeln('    letterSpacing: ${_num(s.letterSpacing!)},');
    }
    b.writeln('  );');
  }
  final slots = t.typography.keys.where(textThemeSlots.contains).toList();
  b
    ..writeln()
    ..writeln('  static const TextTheme textTheme = TextTheme(');
  for (final slot in slots) {
    b.writeln('    $slot: $slot,');
  }
  b
    ..writeln('  );')
    ..writeln('}')
    ..writeln();

  // Colors as a ThemeExtension (supports animated light/dark switching).
  final roles = t.colors['light']!.keys.toList();
  b
    ..writeln('/// Color tokens per mode. Access with `context.colors`.')
    ..writeln('@immutable')
    ..writeln(
      'class AppColorTokens extends ThemeExtension<AppColorTokens> {',
    )
    ..writeln('  const AppColorTokens({');
  for (final r in roles) {
    b.writeln('    required this.$r,');
  }
  b.writeln('  });');
  for (final mode in t.colors.keys) {
    b.writeln('\n  static const $mode = AppColorTokens(');
    for (final r in roles) {
      b.writeln('    $r: ${_color(t.colors[mode]![r]!)},');
    }
    b.writeln('  );');
  }
  b.writeln();
  for (final r in roles) {
    b.writeln('  final Color $r;');
  }
  b
    ..writeln()
    ..writeln('  @override')
    ..writeln('  AppColorTokens copyWith({');
  for (final r in roles) {
    b.writeln('    Color? $r,');
  }
  b.writeln('  }) => AppColorTokens(');
  for (final r in roles) {
    b.writeln('    $r: $r ?? this.$r,');
  }
  b
    ..writeln('  );')
    ..writeln()
    ..writeln('  @override')
    ..writeln(
      '  AppColorTokens lerp(AppColorTokens? other, double t) {',
    )
    ..writeln('    if (other == null) return this;')
    ..writeln('    return AppColorTokens(');
  for (final r in roles) {
    b.writeln('      $r: Color.lerp($r, other.$r, t)!,');
  }
  b
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}');

  return b.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n');
}
