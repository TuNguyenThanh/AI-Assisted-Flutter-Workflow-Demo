// CLI: dart run tool/generate_tokens.dart [--check]
//
// Reads design/tokens.json, validates it and writes
// lib/core/theme/app_tokens.g.dart. With --check (used in CI) it only
// verifies that the committed file is up to date.
import 'dart:convert';
import 'dart:io';

import 'tokens/token_generator.dart';

const _input = 'design/tokens.json';
const _output = 'lib/core/theme/app_tokens.g.dart';

Future<void> main(List<String> args) async {
  final check = args.contains('--check');

  final DesignTokens tokens;
  try {
    final json = jsonDecode(await File(_input).readAsString());
    tokens = parseTokens(json as Map<String, dynamic>);
  } on TokenException catch (e) {
    stderr.writeln(e);
    exit(1);
  } on FormatException catch (e) {
    stderr.writeln('$_input is not valid JSON: ${e.message}');
    exit(1);
  }

  final missingFonts = undeclaredFontFamilies(
    tokens,
    await File('pubspec.yaml').readAsString(),
  );
  if (missingFonts.isNotEmpty) {
    stderr.writeln(
      'Font families not declared in pubspec.yaml (flutter: fonts:): '
      '${missingFonts.join(', ')}. Add the font files or use google_fonts.',
    );
    exit(1);
  }

  final formatted = await _format(renderDart(tokens));
  final target = File(_output);

  if (check) {
    final current = target.existsSync() ? await target.readAsString() : '';
    if (current != formatted) {
      stderr.writeln(
        '$_output is out of date with $_input. '
        'Run: dart run tool/generate_tokens.dart',
      );
      exit(1);
    }
    stdout.writeln('Design tokens up to date.');
    return;
  }

  await target.writeAsString(formatted);
  stdout.writeln(
    'Wrote $_output: ${tokens.colors['light']!.length} colors x '
    '${tokens.colors.length} modes, ${tokens.spacing.length} spacing, '
    '${tokens.radius.length} radius, ${tokens.size.length} sizes, '
    '${tokens.typography.length} text styles.',
  );
}

/// Formats with the same Dart SDK that runs this script, so output is
/// identical locally (fvm) and in CI.
Future<String> _format(String source) async {
  final tmp = await Directory.systemTemp.createTemp('tokens');
  try {
    final file = File('${tmp.path}/app_tokens.g.dart');
    await file.writeAsString(source);
    final result = await Process.run(Platform.resolvedExecutable, [
      'format',
      '--language-version=3.8',
      file.path,
    ]);
    if (result.exitCode != 0) {
      stderr.writeln(result.stderr);
      exit(1);
    }
    return await file.readAsString();
  } finally {
    await tmp.delete(recursive: true);
  }
}
