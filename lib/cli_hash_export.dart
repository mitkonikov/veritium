import 'dart:io';

import 'package:veritium/hash_exporter.dart';

class CliHashExportParseResult {
  final String? inputPath;
  final String? outputPath;
  final bool showHelp;
  final String? error;

  const CliHashExportParseResult({
    this.inputPath,
    this.outputPath,
    this.showHelp = false,
    this.error,
  });
}

bool shouldRunEmbeddedCliHashMode(List<String> args) {
  return args.contains('--cli-export-empty-hashes');
}

String cliHashExportUsage(String command) {
  return [
    'Usage: $command --input <path/to/file_middle.json> [--output <path/to/hashes.txt>]',
    '',
    'Options:',
    '  -i, --input             Path to MinerU middle JSON file (required)',
    '  -o, --output            Output text file path (optional)',
    '  -h, --help              Show this help message',
  ].join('\n');
}

CliHashExportParseResult parseCliHashExportArgs(List<String> args) {
  String? inputPath;
  String? outputPath;

  for (int index = 0; index < args.length; index++) {
    final arg = args[index];

    if (arg == '-h' || arg == '--help') {
      return const CliHashExportParseResult(showHelp: true);
    }

    if (arg == '-i' || arg == '--input') {
      if (index + 1 >= args.length) {
        return const CliHashExportParseResult(error: 'Missing value for --input');
      }
      inputPath = args[++index];
      continue;
    }

    if (arg == '-o' || arg == '--output') {
      if (index + 1 >= args.length) {
        return const CliHashExportParseResult(error: 'Missing value for --output');
      }
      outputPath = args[++index];
      continue;
    }

    return CliHashExportParseResult(error: 'Unknown argument: $arg');
  }

  if (inputPath == null || inputPath.trim().isEmpty) {
    return const CliHashExportParseResult(error: 'Input file is required (--input)');
  }

  return CliHashExportParseResult(
    inputPath: inputPath,
    outputPath: outputPath,
  );
}

String defaultCliHashOutputPathForInput(String inputPath) {
  final inputFile = File(inputPath);
  final dir = inputFile.parent.path;
  final outputFileName = HashExporter.defaultOutputFileName(inputPath);
  return '$dir${Platform.pathSeparator}$outputFileName';
}

Future<int> runCliHashExportCommand(
  List<String> args, {
  required String command,
  void Function(String)? out,
  void Function(String)? err,
}) async {
  final writeOut = out ?? stdout.writeln;
  final writeErr = err ?? stderr.writeln;

  final parseResult = parseCliHashExportArgs(args);

  if (parseResult.showHelp) {
    writeOut(cliHashExportUsage(command));
    return 0;
  }

  if (parseResult.error != null) {
    writeErr('Error: ${parseResult.error}');
    writeErr('');
    writeOut(cliHashExportUsage(command));
    return 64;
  }

  final inputPath = parseResult.inputPath!;
  final outputPath = parseResult.outputPath ?? defaultCliHashOutputPathForInput(inputPath);

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    writeErr('Error: Input file not found: $inputPath');
    return 66;
  }

  try {
    await HashExporter.exportToFile(
      inputJsonFile: inputPath,
      outputHashFile: outputPath,
    );
    writeOut('Exported empty corrected hashes to: $outputPath');
    return 0;
  } catch (e) {
    writeErr('Error: Failed to export empty corrected hashes: $e');
    return 1;
  }
}
