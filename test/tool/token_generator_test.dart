import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/tokens/token_generator.dart';

Map<String, dynamic> validJson() =>
    jsonDecode(File('design/tokens.json').readAsStringSync())
        as Map<String, dynamic>;

List<String> errorsOf(Map<String, dynamic> json) {
  try {
    parseTokens(json);
    return const [];
  } on TokenException catch (e) {
    return e.errors;
  }
}

void main() {
  group('parseHexColor', () {
    test('adds full alpha to #RRGGBB', () {
      expect(parseHexColor('#3F51B5'), 0xFF3F51B5);
    });

    test('moves Figma alpha (#RRGGBBAA) to Flutter position (0xAARRGGBB)', () {
      expect(parseHexColor('#0000001A'), 0x1A000000);
    });

    test('rejects other formats', () {
      expect(() => parseHexColor('3F51B5'), throwsFormatException);
      expect(() => parseHexColor('#FFF'), throwsFormatException);
      expect(() => parseHexColor('rgb(0,0,0)'), throwsFormatException);
    });
  });

  test('contrast ratio matches WCAG reference values', () {
    expect(contrastRatio(0xFF000000, 0xFFFFFFFF), closeTo(21, 0.01));
    expect(contrastRatio(0xFF777777, 0xFFFFFFFF), closeTo(4.48, 0.01));
  });

  group('parseTokens', () {
    test('committed design/tokens.json is valid', () {
      final tokens = parseTokens(validJson());
      expect(tokens.colors.keys, containsAll(['light', 'dark']));
      expect(tokens.spacing['md'], 16);
    });

    test('requires every ColorScheme role in every mode', () {
      final json = validJson();
      (json['color'] as Map)['dark'] = Map.of(
        (json['color'] as Map)['dark'] as Map<String, dynamic>,
      )..remove('outline');
      final errors = errorsOf(json);
      expect(errors, contains('color.dark.outline is required'));
      expect(errors.any((e) => e.contains('roles differ')), isTrue);
    });

    test('fails when on-color contrast is below WCAG AA', () {
      final json = validJson();
      ((json['color'] as Map)['light'] as Map)['onPrimary'] = '#5C6BC0';
      expect(
        errorsOf(json),
        contains(startsWith('color.light.onPrimary on primary has contrast')),
      );
    });

    test('rejects names that are not valid Dart identifiers', () {
      final json = validJson();
      (json['spacing'] as Map)['2xl'] = 48;
      expect(
        errorsOf(json),
        contains(contains('"2xl" must be lowerCamelCase')),
      );
    });

    test('validates typography weights and sizes', () {
      final json = validJson();
      (json['typography'] as Map)['bodyLarge'] = {
        'fontSize': 16,
        'fontWeight': 450,
      };
      (json['typography'] as Map)['bodySmall'] = {'fontSize': 0};
      final errors = errorsOf(json);
      expect(errors, contains(contains('bodyLarge.fontWeight')));
      expect(errors, contains(contains('bodySmall.fontSize')));
    });

    test('reports all errors at once', () {
      final json = validJson();
      (json['spacing'] as Map)['md'] = -1;
      (json['radius'] as Map)['sm'] = 'big';
      expect(errorsOf(json).length, greaterThanOrEqualTo(2));
    });
  });

  group('optional sections and fonts', () {
    test('size is optional', () {
      final json = validJson()..remove('size');
      expect(parseTokens(json).size, isEmpty);
    });

    test('flags font families missing from pubspec', () {
      final json = validJson();
      (json['typography'] as Map)['bodyLarge'] = {
        'fontSize': 16,
        'fontFamily': 'Inter',
      };
      final tokens = parseTokens(json);
      expect(undeclaredFontFamilies(tokens, 'flutter:\n'), {'Inter'});
      expect(
        undeclaredFontFamilies(
          tokens,
          'flutter:\n  fonts:\n    - family: Inter\n',
        ),
        isEmpty,
      );
    });
  });

  group('renderDart', () {
    final source = renderDart(parseTokens(validJson()));

    test('converts Figma line height (px) to Flutter height multiplier', () {
      expect(source, contains('height: 32 / 24'));
    });

    test('wires TextTheme slots only for known names', () {
      expect(source, contains('headlineSmall: headlineSmall,'));
    });

    test('generates a ThemeExtension with lerp for every role', () {
      expect(source, contains('extends ThemeExtension<AppColorTokens>'));
      expect(
        source,
        contains('success: Color.lerp(success, other.success, t)!'),
      );
    });
  });
}
