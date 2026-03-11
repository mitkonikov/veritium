import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veritium/cli_export.dart';

void main() {
  test('embedded CLI mode detection', () {
    expect(shouldRunEmbeddedCliMode([]), isFalse);
    expect(shouldRunEmbeddedCliMode(['--cli-export']), isTrue);
    expect(shouldRunEmbeddedCliMode(['--input', 'sample_middle.json']), isTrue);
    expect(shouldRunEmbeddedCliMode(['--help']), isTrue);
    expect(shouldRunEmbeddedCliMode(['some_other_arg']), isFalse);
  });

  test('parse CLI args with no-images', () {
    final result = parseCliExportArgs([
      '--input',
      'examples/straza/id-40086785_date-19091112_vol-01_no-132_middle.json',
      '--no-images',
    ]);

    expect(result.error, isNull);
    expect(result.showHelp, isFalse);
    expect(result.includeImages, isFalse);
    expect(result.preferCorrectedContent, isTrue);
    expect(result.inputPath, isNotNull);
  });

  test('parse CLI args with original-content mode', () {
    final result = parseCliExportArgs([
      '--input',
      'examples/straza/id-40086785_date-19091112_vol-01_no-132_middle.json',
      '--original-content',
    ]);

    expect(result.error, isNull);
    expect(result.preferCorrectedContent, isFalse);
  });

  test('runCliExportCommand exports markdown file', () async {
    final tempDir = await Directory.systemTemp.createTemp('veritium_cli_test_');
    try {
      final outputPath = '${tempDir.path}${Platform.pathSeparator}output.md';
      final out = <String>[];
      final err = <String>[];

      final exitCode = await runCliExportCommand(
        [
          '--input',
          'examples/straza/id-40086785_date-19091112_vol-01_no-132_middle.json',
          '--output',
          outputPath,
          '--no-images',
        ],
        command: 'test-command',
        out: out.add,
        err: err.add,
      );

      expect(exitCode, 0);
      expect(err, isEmpty);
      expect(File(outputPath).existsSync(), isTrue);

      final content = await File(outputPath).readAsString();
      expect(content, isNotEmpty);
      expect(content, isNot(contains('![](')));
      expect(out.any((line) => line.contains('Exported markdown to:')), isTrue);
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('runCliExportCommand shows usage for help', () async {
    final out = <String>[];
    final err = <String>[];

    final exitCode = await runCliExportCommand(
      ['--help'],
      command: 'test-help',
      out: out.add,
      err: err.add,
    );

    expect(exitCode, 0);
    expect(err, isEmpty);
    expect(out.join('\n'), contains('Usage: test-help'));
  });

  test('CLI defaults to corrected content and can switch to original content', () async {
    final tempDir = await Directory.systemTemp.createTemp('veritium_cli_content_mode_');
    try {
      final inputPath = '${tempDir.path}${Platform.pathSeparator}input_middle.json';
      final correctedOutputPath = '${tempDir.path}${Platform.pathSeparator}corrected.md';
      final originalOutputPath = '${tempDir.path}${Platform.pathSeparator}original.md';

      final json = '''
{
  "pdf_info": [
    {
      "para_blocks": [
        {
          "type": "text",
          "lines": [
            {
              "spans": [
                {
                  "type": "text",
                  "content": "original value",
                  "corrected_content": "corrected value"
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''';
      await File(inputPath).writeAsString(json);

      final correctedExitCode = await runCliExportCommand(
        ['--input', inputPath, '--output', correctedOutputPath],
        command: 'test-corrected',
      );
      expect(correctedExitCode, 0);

      final originalExitCode = await runCliExportCommand(
        ['--input', inputPath, '--output', originalOutputPath, '--original-content'],
        command: 'test-original',
      );
      expect(originalExitCode, 0);

      final correctedContent = await File(correctedOutputPath).readAsString();
      final originalContent = await File(originalOutputPath).readAsString();

      expect(correctedContent, contains('corrected value'));
      expect(correctedContent, isNot(contains('original value')));
      expect(originalContent, contains('original value'));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}
