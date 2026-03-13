import 'dart:io';

import 'package:veritium/markdown_exporter.dart';

class CliExportParseResult {
  final String? inputPath;
  final String? outputPath;
  final bool includeImages;
  final bool preferCorrectedContent;
  final bool listsAsText;
  final bool showHelp;
  final String? error;

  const CliExportParseResult({
    this.inputPath,
    this.outputPath,
    this.includeImages = true,
    this.preferCorrectedContent = true,
    this.listsAsText = false,
    this.showHelp = false,
    this.error,
  });
}

bool shouldRunEmbeddedCliMode(List<String> args) {
  if (args.isEmpty) return false;
  if (args.contains('--cli-export')) return true;
  const directCliSwitches = <String>{
    '--input',
    '-i',
    '--output',
    '-o',
    '--no-images',
    '--original-content',
    '--lists-as-text',
    '--help',
    '-h',
  };
  return args.any(directCliSwitches.contains);
}

String cliExportUsage(String command) {
  return [
    'Usage: $command --input <path/to/file_middle.json> [--output <path/to/output.md>] [--no-images] [--original-content] [--lists-as-text]',
    '',
    'Options:',
    '  -i, --input             Path to MinerU middle JSON file (required)',
    '  -o, --output            Output markdown file path (optional)',
    '      --no-images         Skip markdown image entries from image blocks',
    '      --original-content  Prefer original OCR content over corrected_content',
    '      --lists-as-text     Render list blocks as plain text (no markdown dashes)',
    '  -h, --help              Show this help message',
  ].join('\n');
}

CliExportParseResult parseCliExportArgs(List<String> args) {
  String? inputPath;
  String? outputPath;
  bool includeImages = true;
  bool preferCorrectedContent = true;
  bool listsAsText = false;

  for (int index = 0; index < args.length; index++) {
    final arg = args[index];

    if (arg == '-h' || arg == '--help') {
      return const CliExportParseResult(showHelp: true);
    }

    if (arg == '-i' || arg == '--input') {
      if (index + 1 >= args.length) {
        return const CliExportParseResult(error: 'Missing value for --input');
      }
      inputPath = args[++index];
      continue;
    }

    if (arg == '-o' || arg == '--output') {
      if (index + 1 >= args.length) {
        return const CliExportParseResult(error: 'Missing value for --output');
      }
      outputPath = args[++index];
      continue;
    }

    if (arg == '--no-images') {
      includeImages = false;
      continue;
    }

    if (arg == '--original-content') {
      preferCorrectedContent = false;
      continue;
    }

    if (arg == '--lists-as-text') {
      listsAsText = true;
      continue;
    }

    return CliExportParseResult(error: 'Unknown argument: $arg');
  }

  if (inputPath == null || inputPath.trim().isEmpty) {
    return const CliExportParseResult(error: 'Input file is required (--input)');
  }

  return CliExportParseResult(
    inputPath: inputPath,
    outputPath: outputPath,
    includeImages: includeImages,
    preferCorrectedContent: preferCorrectedContent,
    listsAsText: listsAsText,
  );
}

String defaultCliOutputPathForInput(String inputPath) {
  final inputFile = File(inputPath);
  final dir = inputFile.parent.path;
  final outputFileName = MarkdownExporter.defaultOutputFileName(inputPath);
  return '$dir${Platform.pathSeparator}$outputFileName';
}

Future<int> runCliExportCommand(
  List<String> args, {
  required String command,
  void Function(String)? out,
  void Function(String)? err,
}) async {
  final writeOut = out ?? stdout.writeln;
  final writeErr = err ?? stderr.writeln;

  final parseResult = parseCliExportArgs(args);

  if (parseResult.showHelp) {
    writeOut(cliExportUsage(command));
    return 0;
  }

  if (parseResult.error != null) {
    writeErr('Error: ${parseResult.error}');
    writeErr('');
    writeOut(cliExportUsage(command));
    return 64;
  }

  final inputPath = parseResult.inputPath!;
  final outputPath = parseResult.outputPath ?? defaultCliOutputPathForInput(inputPath);

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    writeErr('Error: Input file not found: $inputPath');
    return 66;
  }

  try {
    await MarkdownExporter.exportToFile(
      inputJsonFile: inputPath,
      outputMarkdownFile: outputPath,
      includeImages: parseResult.includeImages,
      preferCorrectedContent: parseResult.preferCorrectedContent,
      listsAsText: parseResult.listsAsText,
    );
    writeOut('Exported markdown to: $outputPath');
    return 0;
  } catch (e) {
    writeErr('Error: Failed to export markdown: $e');
    return 1;
  }
}
