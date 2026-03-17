import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veritium/cli_hash_export.dart';

void main() {
  test('embedded hash CLI mode detection', () {
    expect(shouldRunEmbeddedCliHashMode([]), isFalse);
    expect(shouldRunEmbeddedCliHashMode(['--cli-export-empty-hashes']), isTrue);
    expect(
      shouldRunEmbeddedCliHashMode([
        '--cli-export-empty-hashes',
        '--input',
        'sample_middle.json',
      ]),
      isTrue,
    );
  });

  test('parse hash export args', () {
    final result = parseCliHashExportArgs([
      '--input',
      'examples/straza/id-40086785_date-19091112_vol-01_no-132_middle.json',
      '--output',
      'build/empty_hashes.txt',
    ]);

    expect(result.error, isNull);
    expect(result.showHelp, isFalse);
    expect(result.inputPath, isNotNull);
    expect(result.outputPath, 'build/empty_hashes.txt');
  });

  test('runCliHashExportCommand shows usage for help', () async {
    final out = <String>[];
    final err = <String>[];

    final exitCode = await runCliHashExportCommand(
      ['--help'],
      command: 'test-help',
      out: out.add,
      err: err.add,
    );

    expect(exitCode, 0);
    expect(err, isEmpty);
    expect(out.join('\n'), contains('Usage: test-help'));
  });

  test('runCliHashExportCommand exports only hashes with empty corrected_content', () async {
    final tempDir = await Directory.systemTemp.createTemp('veritium_cli_hash_export_');
    try {
      final inputPath = '${tempDir.path}${Platform.pathSeparator}input_middle.json';
      final outputPath = '${tempDir.path}${Platform.pathSeparator}empty_hashes.txt';

      final json = {
        'pdf_info': [
          {
            'para_blocks': [
              {
                'type': 'text',
                'lines': [
                  {
                    'spans': [
                      {
                        'type': 'text',
                        'hash': 'hash-empty-1',
                        'content': 'A',
                        'corrected_content': '',
                      },
                      {
                        'type': 'text',
                        'hash': 'hash-filled',
                        'content': 'B',
                        'corrected_content': 'fixed',
                      },
                      {
                        'type': 'text',
                        'hash': 'hash-empty-2',
                        'content': 'C',
                      },
                      {
                        'type': 'text',
                        'content': 'No hash',
                        'corrected_content': '',
                      },
                      {
                        'type': 'text',
                        'hash': 'hash-empty-1',
                        'content': 'duplicate',
                        'corrected_content': '',
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      };

      await File(inputPath).writeAsString(const JsonEncoder.withIndent('  ').convert(json));

      final exitCode = await runCliHashExportCommand(
        ['--input', inputPath, '--output', outputPath],
        command: 'test-hashes',
      );

      expect(exitCode, 0);
      final exported = await File(outputPath).readAsLines();
      expect(exported, ['hash-empty-1', 'hash-empty-2']);
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('runCliHashExportCommand writes default output file when --output omitted', () async {
    final tempDir = await Directory.systemTemp.createTemp('veritium_cli_hash_default_output_');
    try {
      final inputPath = '${tempDir.path}${Platform.pathSeparator}sample_middle.json';

      final json = {
        'pdf_info': [
          {
            'para_blocks': [
              {
                'type': 'text',
                'lines': [
                  {
                    'spans': [
                      {
                        'type': 'text',
                        'hash': 'hash-default-1',
                        'content': 'A',
                        'corrected_content': '',
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      };

      await File(inputPath).writeAsString(const JsonEncoder.withIndent('  ').convert(json));

      final exitCode = await runCliHashExportCommand(
        ['--input', inputPath],
        command: 'test-default-output',
      );
      expect(exitCode, 0);

      final defaultOutputPath =
          '${tempDir.path}${Platform.pathSeparator}sample_empty_corrected_hashes.txt';
      expect(File(defaultOutputPath).existsSync(), isTrue);

      final exported = await File(defaultOutputPath).readAsLines();
      expect(exported, ['hash-default-1']);
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}
