import 'dart:io';

import 'package:veritium/markdown_exporter.dart';

void main(List<String> args) async {
  final parseResult = _parseArgs(args);

  if (parseResult.showHelp) {
    _printUsage();
    return;
  }

  if (parseResult.error != null) {
    stderr.writeln('Error: ${parseResult.error}');
    stderr.writeln('');
    _printUsage();
    exitCode = 64;
    return;
  }

  final inputPath = parseResult.inputPath!;
  final outputPath = parseResult.outputPath ?? _defaultOutputPathFor(inputPath);

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Error: Input file not found: $inputPath');
    exitCode = 66;
    return;
  }

  try {
    await MarkdownExporter.exportToFile(
      inputJsonFile: inputPath,
      outputMarkdownFile: outputPath,
      includeImages: parseResult.includeImages,
    );
    stdout.writeln('Exported markdown to: $outputPath');
  } catch (e) {
    stderr.writeln('Error: Failed to export markdown: $e');
    exitCode = 1;
  }
}

String _defaultOutputPathFor(String inputPath) {
  final inputFile = File(inputPath);
  final dir = inputFile.parent.path;
  final outputFileName = MarkdownExporter.defaultOutputFileName(inputPath);
  return '$dir${Platform.pathSeparator}$outputFileName';
}

void _printUsage() {
  stdout.writeln('Usage: dart run bin/export_markdown.dart --input <path/to/file_middle.json> [--output <path/to/output.md>]');
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln('  -i, --input      Path to MinerU middle JSON file (required)');
  stdout.writeln('  -o, --output     Output markdown file path (optional)');
  stdout.writeln('      --no-images  Skip markdown image entries from image blocks');
  stdout.writeln('  -h, --help       Show this help message');
}

_ParseResult _parseArgs(List<String> args) {
  String? inputPath;
  String? outputPath;
  bool includeImages = true;

  for (int index = 0; index < args.length; index++) {
    final arg = args[index];

    if (arg == '-h' || arg == '--help') {
      return const _ParseResult(showHelp: true);
    }

    if (arg == '-i' || arg == '--input') {
      if (index + 1 >= args.length) {
        return const _ParseResult(error: 'Missing value for --input');
      }
      inputPath = args[++index];
      continue;
    }

    if (arg == '-o' || arg == '--output') {
      if (index + 1 >= args.length) {
        return const _ParseResult(error: 'Missing value for --output');
      }
      outputPath = args[++index];
      continue;
    }

    if (arg == '--no-images') {
      includeImages = false;
      continue;
    }

    return _ParseResult(error: 'Unknown argument: $arg');
  }

  if (inputPath == null || inputPath.trim().isEmpty) {
    return const _ParseResult(error: 'Input file is required (--input)');
  }

  return _ParseResult(
    inputPath: inputPath,
    outputPath: outputPath,
    includeImages: includeImages,
  );
}

class _ParseResult {
  final String? inputPath;
  final String? outputPath;
  final bool includeImages;
  final bool showHelp;
  final String? error;

  const _ParseResult({
    this.inputPath,
    this.outputPath,
    this.includeImages = true,
    this.showHelp = false,
    this.error,
  });
}
