import 'dart:convert';
import 'dart:io';

class MarkdownExporter {
  static const List<String> _lineJoinDashes = <String>[
    '-',
    '\u00AD', // soft hyphen
    '\u2010', // hyphen
    '\u2011', // non-breaking hyphen
    '\u2012', // figure dash
    '\u2013', // en dash
    '\u2014', // em dash
    '\uFE58', // small em dash
    '\uFE63', // small hyphen-minus
    '\uFF0D', // full-width hyphen-minus
  ];

  static String defaultOutputFileName(String originalJsonFile) {
    final normalized = originalJsonFile.replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    if (fileName.endsWith('_middle.json')) {
      return '${fileName.substring(0, fileName.length - '_middle.json'.length)}.md';
    }
    if (fileName.endsWith('.json')) {
      return '${fileName.substring(0, fileName.length - '.json'.length)}.md';
    }
    return '$fileName.md';
  }

  static Future<String> buildFromJsonFile(
    String jsonFilePath, {
    Map<String, String>? hashTextOverrides,
    bool includeImages = true,
    bool preferCorrectedContent = true,
    bool listsAsText = false,
  }) async {
    final file = File(jsonFilePath);
    if (!file.existsSync()) {
      throw Exception('No file found at $jsonFilePath');
    }

    final content = await file.readAsString();
    final dynamic decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid JSON format in $jsonFilePath');
    }

    return buildFromJsonData(
      decoded,
      hashTextOverrides: hashTextOverrides,
      includeImages: includeImages,
      preferCorrectedContent: preferCorrectedContent,
      listsAsText: listsAsText,
    );
  }

  static String buildFromJsonData(
    Map<String, dynamic> jsonData, {
    Map<String, String>? hashTextOverrides,
    bool includeImages = true,
    bool preferCorrectedContent = true,
    bool listsAsText = false,
  }) {
    final overrides = hashTextOverrides ?? const <String, String>{};
    final List<dynamic> pdfInfo = jsonData['pdf_info'] ?? [];
    final outputBlocks = <String>[];

    for (final page in pdfInfo) {
      if (page is! Map) continue;
      final paraBlocks = page['para_blocks'];
      if (paraBlocks is! List) continue;

      for (final block in paraBlocks) {
        if (block is! Map) continue;
        final String blockType = (block['type'] ?? '').toString().toLowerCase();

        if (blockType == 'image') {
          final rendered = _renderImageBlock(
            block,
            overrides,
            includeImages: includeImages,
            preferCorrectedContent: preferCorrectedContent,
          );
          if (rendered.isNotEmpty) {
            outputBlocks.addAll(rendered);
          }
          continue;
        }

        final normalizedLines = _extractBlockLines(
          block,
          overrides,
          preferCorrectedContent: preferCorrectedContent,
        );
        if (normalizedLines.isEmpty) continue;

        if (blockType == 'title') {
          outputBlocks.add('# ${normalizedLines.join(' ')}');
        } else if (blockType == 'list') {
          if (listsAsText) {
            outputBlocks.add(normalizedLines.join(' '));
          } else {
            outputBlocks.addAll(normalizedLines.map((line) => '- $line'));
          }
        } else {
          outputBlocks.add(normalizedLines.join(' '));
        }
      }
    }

    if (outputBlocks.isEmpty) return '';
    return '${outputBlocks.join('\n\n').trimRight()}\n';
  }

  static Future<void> exportToFile({
    required String inputJsonFile,
    required String outputMarkdownFile,
    Map<String, String>? hashTextOverrides,
    bool includeImages = true,
    bool preferCorrectedContent = true,
    bool listsAsText = false,
  }) async {
    final markdown = await buildFromJsonFile(
      inputJsonFile,
      hashTextOverrides: hashTextOverrides,
      includeImages: includeImages,
      preferCorrectedContent: preferCorrectedContent,
      listsAsText: listsAsText,
    );

    final outputFile = File(outputMarkdownFile);
    await outputFile.writeAsString(markdown);
  }

  static List<String> _renderImageBlock(
    Map<dynamic, dynamic> block,
    Map<String, String> overrides,
    {
    required bool includeImages,
    required bool preferCorrectedContent,
  }
  ) {
    final imagePaths = <String>[];
    final captions = <String>[];

    final nestedBlocks = block['blocks'];
    if (nestedBlocks is! List) return const [];

    for (final nested in nestedBlocks) {
      if (nested is! Map) continue;
      final nestedType = (nested['type'] ?? '').toString().toLowerCase();

      if (nestedType == 'image_body') {
        final lines = nested['lines'];
        if (lines is! List) continue;

        for (final line in lines) {
          if (line is! Map) continue;
          final spans = line['spans'];
          if (spans is! List) continue;

          for (final span in spans) {
            if (span is! Map) continue;
            if ((span['type'] ?? '').toString().toLowerCase() == 'image') {
              final imagePath = (span['image_path'] ?? '').toString().trim();
              if (imagePath.isNotEmpty) {
                imagePaths.add(imagePath);
              }
            }
          }
        }
      } else {
        captions.addAll(
          _extractBlockLines(
            nested,
            overrides,
            preferCorrectedContent: preferCorrectedContent,
          ),
        );
      }
    }

    final output = <String>[];
    if (includeImages && imagePaths.isEmpty && captions.isNotEmpty) {
      output.add('[Image]');
    }
    if (includeImages) {
      for (final imagePath in imagePaths) {
        output.add('![]($imagePath)');
      }
    }
    if (captions.isNotEmpty) {
      output.add(captions.join(' '));
    }

    return output;
  }

  static String _resolveSpanText(
    dynamic span,
    Map<String, String> overrides,
    {
    bool preferCorrectedContent = true,
  }
  ) {
    if (span is! Map) return '';

    final String hash = (span['hash'] ?? '').toString();
    if (hash.isNotEmpty && overrides.containsKey(hash)) {
      return overrides[hash]!.trim();
    }

    final String corrected = (span['corrected_content'] ?? '').toString().trim();
    final String original = (span['content'] ?? '').toString().trim();

    if (preferCorrectedContent) {
      if (corrected.isNotEmpty) return corrected;
      return original;
    }

    if (original.isNotEmpty) return original;
    return corrected;
  }

  static String _extractLineText(
    dynamic line,
    Map<String, String> overrides,
    {
    bool preferCorrectedContent = true,
  }
  ) {
    if (line is! Map) return '';
    final spans = line['spans'];
    if (spans is! List) return '';

    final parts = <String>[];
    for (final span in spans) {
      final text = _resolveSpanText(
        span,
        overrides,
        preferCorrectedContent: preferCorrectedContent,
      );
      if (text.isNotEmpty) {
        parts.add(text);
      }
    }

    return parts.join(' ').trim();
  }

  static List<String> _extractBlockLines(
    dynamic block,
    Map<String, String> overrides,
    {
    bool preferCorrectedContent = true,
  }
  ) {
    if (block is! Map) return const [];
    final lines = block['lines'];
    if (lines is! List) return const [];

    final results = <String>[];
    bool appendToPreviousLine = false;
    for (final line in lines) {
      var text = _extractLineText(
        line,
        overrides,
        preferCorrectedContent: preferCorrectedContent,
      );

      text = text.trimRight();
      final lineEndsWithHyphen = _lineJoinDashes.any(text.endsWith);
      if (lineEndsWithHyphen) {
        for (final dash in _lineJoinDashes) {
          if (text.endsWith(dash)) {
            text = text.substring(0, text.length - dash.length).trimRight();
            break;
          }
        }
      }

      if (text.isNotEmpty) {
        if (appendToPreviousLine && results.isNotEmpty) {
          results[results.length - 1] = '${results.last}${text.trimLeft()}';
        } else {
          results.add(text);
        }
      }

      appendToPreviousLine = lineEndsWithHyphen;
    }

    return results;
  }
}
