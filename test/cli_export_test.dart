import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veritium/cli_export.dart';
import 'package:veritium/markdown_exporter.dart';

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

  test('parse CLI args with lists-as-text mode', () {
    final result = parseCliExportArgs([
      '--input',
      'examples/straza/id-40086785_date-19091112_vol-01_no-132_middle.json',
      '--lists-as-text',
    ]);

    expect(result.error, isNull);
    expect(result.listsAsText, isTrue);
  });

  test('parse CLI args with skip-hashes file', () {
    final result = parseCliExportArgs([
      '--input',
      'examples/straza/id-40086785_date-19091112_vol-01_no-132_middle.json',
      '--skip-hashes',
      'build/skip_hashes.txt',
    ]);

    expect(result.error, isNull);
    expect(result.skipHashesPath, 'build/skip_hashes.txt');
    expect(result.skipHashesMode, SkipHashesMode.span);
  });

  test('parse CLI args with skip-hashes-mode line', () {
    final result = parseCliExportArgs([
      '--input',
      'examples/straza/id-40086785_date-19091112_vol-01_no-132_middle.json',
      '--skip-hashes-mode',
      'line',
    ]);

    expect(result.error, isNull);
    expect(result.skipHashesMode, SkipHashesMode.line);
  });

  test('parse CLI args with all-as-text and single block separator', () {
    final result = parseCliExportArgs([
      '--input',
      'examples/straza/id-40086785_date-19091112_vol-01_no-132_middle.json',
      '--all-as-text',
      '--block-separator',
      'single',
    ]);

    expect(result.error, isNull);
    expect(result.allAsText, isTrue);
    expect(result.blockSeparator, '\n');
  });

  test('loadSkipHashes reads trimmed unique hashes', () async {
    final tempDir = await Directory.systemTemp.createTemp('veritium_cli_skip_hashes_');
    try {
      final hashesPath = '${tempDir.path}${Platform.pathSeparator}skip_hashes.txt';
      await File(hashesPath).writeAsString(' h1 \n\n h2\n h1\n');

      final hashes = await loadSkipHashes(hashesPath);
      expect(hashes, {'h1', 'h2'});
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
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

  test('CLI can render list blocks as plain text', () async {
    final tempDir = await Directory.systemTemp.createTemp('veritium_cli_lists_mode_');
    try {
      final inputPath = '${tempDir.path}${Platform.pathSeparator}input_middle.json';
      final defaultOutputPath = '${tempDir.path}${Platform.pathSeparator}default.md';
      final textOutputPath = '${tempDir.path}${Platform.pathSeparator}text.md';

      final json = '''
{
  "pdf_info": [
    {
      "para_blocks": [
        {
          "type": "list",
          "lines": [
            {
              "spans": [
                {"type": "text", "content": "first item"}
              ]
            },
            {
              "spans": [
                {"type": "text", "content": "second item"}
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

      final defaultExitCode = await runCliExportCommand(
        ['--input', inputPath, '--output', defaultOutputPath],
        command: 'test-list-default',
      );
      expect(defaultExitCode, 0);

      final textExitCode = await runCliExportCommand(
        ['--input', inputPath, '--output', textOutputPath, '--lists-as-text'],
        command: 'test-list-text',
      );
      expect(textExitCode, 0);

      final defaultContent = await File(defaultOutputPath).readAsString();
      final textContent = await File(textOutputPath).readAsString();

      expect(defaultContent, contains('- first item'));
      expect(defaultContent, contains('- second item'));
      expect(textContent, contains('first item second item'));
      expect(textContent, isNot(contains('- first item')));
      expect(textContent, isNot(contains('- second item')));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('CLI all-as-text renders titles lists and images without markdown syntax', () async {
    final tempDir = await Directory.systemTemp.createTemp('veritium_cli_all_as_text_');
    try {
      final inputPath = '${tempDir.path}${Platform.pathSeparator}input_middle.json';
      final outputPath = '${tempDir.path}${Platform.pathSeparator}output.md';

      final json = '''
{
  "pdf_info": [
    {
      "para_blocks": [
        {
          "type": "title",
          "lines": [
            {"spans": [{"type": "text", "content": "Section Title"}]}
          ]
        },
        {
          "type": "list",
          "lines": [
            {"spans": [{"type": "text", "content": "List item"}]}
          ]
        },
        {
          "type": "image",
          "blocks": [
            {
              "type": "image_body",
              "lines": [
                {
                  "spans": [
                    {"type": "image", "image_path": "images/sample.png"}
                  ]
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

      final exitCode = await runCliExportCommand(
        ['--input', inputPath, '--output', outputPath, '--all-as-text'],
        command: 'test-all-as-text',
      );

      expect(exitCode, 0);
      final content = await File(outputPath).readAsString();
      expect(content, contains('Section Title'));
      expect(content, contains('List item'));
      expect(content, contains('images/sample.png'));
      expect(content, isNot(contains('# Section Title')));
      expect(content, isNot(contains('- List item')));
      expect(content, isNot(contains('![](images/sample.png)')));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('CLI block-separator single uses single newline between blocks', () async {
    final tempDir = await Directory.systemTemp.createTemp('veritium_cli_block_separator_');
    try {
      final inputPath = '${tempDir.path}${Platform.pathSeparator}input_middle.json';
      final outputPath = '${tempDir.path}${Platform.pathSeparator}output.md';

      final json = '''
{
  "pdf_info": [
    {
      "para_blocks": [
        {
          "type": "text",
          "lines": [
            {"spans": [{"type": "text", "content": "First block"}]}
          ]
        },
        {
          "type": "text",
          "lines": [
            {"spans": [{"type": "text", "content": "Second block"}]}
          ]
        }
      ]
    }
  ]
}
''';

      await File(inputPath).writeAsString(json);

      final exitCode = await runCliExportCommand(
        [
          '--input',
          inputPath,
          '--output',
          outputPath,
          '--block-separator',
          'single',
        ],
        command: 'test-block-separator-single',
      );

      expect(exitCode, 0);
      final content = await File(outputPath).readAsString();
      expect(content, contains('First block\nSecond block\n'));
      expect(content, isNot(contains('First block\n\nSecond block')));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('image caption is excluded when images are disabled', () async {
    final tempDir = await Directory.systemTemp.createTemp('veritium_cli_no_images_caption_');
    try {
      final inputPath = '${tempDir.path}${Platform.pathSeparator}input_middle.json';
      final outputPath = '${tempDir.path}${Platform.pathSeparator}output.md';

      final json = '''
{
  "pdf_info": [
    {
      "para_blocks": [
        {
          "type": "image",
          "bbox": [595, 196, 693, 331],
          "blocks": [
            {
              "type": "image_caption",
              "bbox": [594, 183, 613, 193],
              "group_id": 0,
              "lines": [
                {
                  "bbox": [593, 181, 615, 195],
                  "spans": [
                    {
                      "bbox": [593, 181, 615, 195],
                      "score": 1.0,
                      "content": "1087",
                      "type": "text"
                    }
                  ],
                  "index": 62
                }
              ],
              "index": 62
            }
          ]
        },
        {
          "type": "text",
          "lines": [
            {
              "spans": [
                {"type": "text", "content": "Regular text remains."}
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

      final exitCode = await runCliExportCommand(
        ['--input', inputPath, '--output', outputPath, '--no-images'],
        command: 'test-no-images-caption',
      );

      expect(exitCode, 0);
      final content = await File(outputPath).readAsString();
      expect(content, contains('Regular text remains.'));
      expect(content, isNot(contains('1087')));
      expect(content, isNot(contains('[Image]')));
      expect(content, isNot(contains('![](')));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('hyphenated wrapped lines are concatenated without spaces', () async {
    final tempDir = await Directory.systemTemp.createTemp('veritium_cli_hyphen_wrap_');
    try {
      final inputPath = '${tempDir.path}${Platform.pathSeparator}input_middle.json';
      final outputPath = '${tempDir.path}${Platform.pathSeparator}output.md';

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
                {"type": "text", "content": "conca-"}
              ]
            },
            {
              "spans": [
                {"type": "text", "content": "tenated"}
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

      final exitCode = await runCliExportCommand(
        ['--input', inputPath, '--output', outputPath],
        command: 'test-hyphen-wrap',
      );

      expect(exitCode, 0);
      final content = await File(outputPath).readAsString();
      expect(content, contains('concatenated'));
      expect(content, isNot(contains('conca tenated')));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('unicode dash wrapped lines are concatenated without spaces', () async {
    final tempDir = await Directory.systemTemp.createTemp('veritium_cli_unicode_dash_wrap_');
    try {
      final inputPath = '${tempDir.path}${Platform.pathSeparator}input_middle.json';
      final outputPath = '${tempDir.path}${Platform.pathSeparator}output.md';

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
                {"type": "text", "content": "co\u2010"}
              ]
            },
            {
              "spans": [
                {"type": "text", "content": "operate"}
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

      final exitCode = await runCliExportCommand(
        ['--input', inputPath, '--output', outputPath],
        command: 'test-unicode-dash-wrap',
      );

      expect(exitCode, 0);
      final content = await File(outputPath).readAsString();
      expect(content, contains('cooperate'));
      expect(content, isNot(contains('co operate')));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('hyphenated word split across spans in same line is concatenated', () async {
    final tempDir = await Directory.systemTemp.createTemp('veritium_cli_span_hyphen_wrap_');
    try {
      final inputPath = '${tempDir.path}${Platform.pathSeparator}input_middle.json';
      final outputPath = '${tempDir.path}${Platform.pathSeparator}output.md';

      final json = '''
{
  "pdf_info": [
    {
      "para_blocks": [
        {
          "type": "text",
          "lines": [
            {
              "bbox": [312, 778, 590, 806],
              "spans": [
                {
                  "bbox": [312, 778, 590, 801],
                  "score": 0.963,
                  "content": "Uranjeka tri lepe pesmi, nakar je predsednik go-",
                  "type": "text",
                  "hash": "lh4o0rv4j86zqmbdkmabr25ouj5fib91hcv9gvsmq7bao1881mpjrizdh2y09ccs"
                },
                {
                  "bbox": [315, 793, 517, 806],
                  "score": 0.987,
                  "content": "spod Poto\u010dnik zaklju\u010dil zborovanje.",
                  "type": "text",
                  "hash": "lhvrd95y4e5cz1tv6h65pn8bygmwwysp711rmmsv7vzbwmi0qu21yo8momico0pq"
                }
              ],
              "index": 168
            }
          ]
        }
      ]
    }
  ]
}
''';

      await File(inputPath).writeAsString(json);

      final exitCode = await runCliExportCommand(
        ['--input', inputPath, '--output', outputPath],
        command: 'test-span-hyphen-wrap',
      );

      expect(exitCode, 0);
      final content = await File(outputPath).readAsString();
      expect(content, contains('Uranjeka tri lepe pesmi, nakar je predsednik gospod Poto\u010dnik zaključil zborovanje.'));
      expect(content, isNot(contains('go- spod')));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('CLI skip-hashes default mode removes only matching spans', () async {
    final tempDir = await Directory.systemTemp.createTemp('veritium_cli_skip_hashes_behavior_');
    try {
      final inputPath = '${tempDir.path}${Platform.pathSeparator}input_middle.json';
      final outputPath = '${tempDir.path}${Platform.pathSeparator}output.md';
      final skipHashesPath = '${tempDir.path}${Platform.pathSeparator}skip_hashes.txt';

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
                {"type": "text", "hash": "keep-hash", "content": "Keep this line"}
              ]
            },
            {
              "spans": [
                {"type": "text", "hash": "keep-prefix", "content": "Keep"},
                {"type": "text", "hash": "skip-hash", "content": "Skip"},
                {"type": "text", "hash": "keep-suffix", "content": "line"}
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
      await File(skipHashesPath).writeAsString('skip-hash\n');

      final exitCode = await runCliExportCommand(
        [
          '--input',
          inputPath,
          '--output',
          outputPath,
          '--skip-hashes',
          skipHashesPath,
        ],
        command: 'test-skip-hashes',
      );

      expect(exitCode, 0);

      final content = await File(outputPath).readAsString();
      expect(content, contains('Keep this line'));
      expect(content, contains('Keep line'));
      expect(content, isNot(contains('Skip')));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('CLI skip-hashes line mode removes full matching lines', () async {
    final tempDir = await Directory.systemTemp.createTemp('veritium_cli_skip_hashes_line_mode_');
    try {
      final inputPath = '${tempDir.path}${Platform.pathSeparator}input_middle.json';
      final outputPath = '${tempDir.path}${Platform.pathSeparator}output.md';
      final skipHashesPath = '${tempDir.path}${Platform.pathSeparator}skip_hashes.txt';

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
                {"type": "text", "hash": "keep-hash", "content": "Keep this line"}
              ]
            },
            {
              "spans": [
                {"type": "text", "hash": "keep-prefix", "content": "Keep"},
                {"type": "text", "hash": "skip-hash", "content": "Skip"},
                {"type": "text", "hash": "keep-suffix", "content": "line"}
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
      await File(skipHashesPath).writeAsString('skip-hash\n');

      final exitCode = await runCliExportCommand(
        [
          '--input',
          inputPath,
          '--output',
          outputPath,
          '--skip-hashes',
          skipHashesPath,
          '--skip-hashes-mode',
          'line',
        ],
        command: 'test-skip-hashes-line',
      );

      expect(exitCode, 0);

      final content = await File(outputPath).readAsString();
      expect(content, contains('Keep this line'));
      expect(content, isNot(contains('Keep line')));
      expect(content, isNot(contains('Skip')));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}
