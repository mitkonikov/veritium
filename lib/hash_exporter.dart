import 'dart:convert';
import 'dart:io';

class HashExporter {
  static String defaultOutputFileName(String originalJsonFile) {
    final normalized = originalJsonFile.replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    if (fileName.endsWith('_middle.json')) {
      return '${fileName.substring(0, fileName.length - '_middle.json'.length)}_empty_corrected_hashes.txt';
    }
    if (fileName.endsWith('.json')) {
      return '${fileName.substring(0, fileName.length - '.json'.length)}_empty_corrected_hashes.txt';
    }
    return '${fileName}_empty_corrected_hashes.txt';
  }

  static Future<List<String>> buildEmptyCorrectedHashesFromJsonFile(
    String jsonFilePath,
  ) async {
    final file = File(jsonFilePath);
    if (!file.existsSync()) {
      throw Exception('No file found at $jsonFilePath');
    }

    final content = await file.readAsString();
    final dynamic decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid JSON format in $jsonFilePath');
    }

    return buildEmptyCorrectedHashesFromJsonData(decoded);
  }

  static List<String> buildEmptyCorrectedHashesFromJsonData(
    Map<String, dynamic> jsonData,
  ) {
    final List<dynamic> pdfInfo = jsonData['pdf_info'] ?? [];
    final results = <String>[];

    for (final page in pdfInfo) {
      if (page is! Map) continue;
      final paraBlocks = page['para_blocks'];
      if (paraBlocks is! List) continue;

      for (final block in paraBlocks) {
        if (block is! Map) continue;
        final lines = block['lines'];
        if (lines is! List) continue;

        for (final line in lines) {
          if (line is! Map) continue;
          final spans = line['spans'];
          if (spans is! List) continue;

          for (final span in spans) {
            if (span is! Map) continue;

            final hash = (span['hash'] ?? '').toString().trim();
            if (hash.isEmpty) continue;

            if (span.containsKey('corrected_content') && span['corrected_content'].toString().trim().isEmpty) {
              results.add(hash);
            }
          }
        }
      }
    }

    return results;
  }

  static Future<void> exportToFile({
    required String inputJsonFile,
    required String outputHashFile,
  }) async {
    final hashes = await buildEmptyCorrectedHashesFromJsonFile(inputJsonFile);

    final outputFile = File(outputHashFile);
    if (hashes.isEmpty) {
      await outputFile.writeAsString('');
      return;
    }

    await outputFile.writeAsString('${hashes.join('\n')}\n');
  }
}
