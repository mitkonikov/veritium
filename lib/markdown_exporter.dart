import 'dart:convert';
import 'dart:io';

enum SkipHashesMode { span, line }

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
      bool allAsText = false,
      String blockSeparator = '\n\n',
      Set<String> skipHashes = const <String>{},
      SkipHashesMode skipHashesMode = SkipHashesMode.span,
    }
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

    return buildFromJsonData(
      decoded,
      hashTextOverrides: hashTextOverrides,
      includeImages: includeImages,
      preferCorrectedContent: preferCorrectedContent,
      listsAsText: listsAsText,
      allAsText: allAsText,
      blockSeparator: blockSeparator,
      skipHashes: skipHashes,
      skipHashesMode: skipHashesMode,
    );
  }

  static String buildFromJsonData(
    Map<String, dynamic> jsonData, {
    Map<String, String>? hashTextOverrides,
    bool includeImages = true,
    bool preferCorrectedContent = true,
    bool listsAsText = false,
    bool allAsText = false,
    String blockSeparator = '\n\n',
    Set<String> skipHashes = const <String>{},
    SkipHashesMode skipHashesMode = SkipHashesMode.span,
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

        if (blockType == 'image' || blockType == 'image_caption') {
          final rendered = _renderImageBlock(
            block,
            overrides,
            includeImages: includeImages,
            preferCorrectedContent: preferCorrectedContent,
            allAsText: allAsText,
            skipHashes: skipHashes,
            skipHashesMode: skipHashesMode,
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
          skipHashes: skipHashes,
          skipHashesMode: skipHashesMode,
        );
        if (normalizedLines.isEmpty) continue;

        if (allAsText) {
          outputBlocks.add(normalizedLines.join(' '));
        } else if (blockType == 'title') {
          outputBlocks.add('# ${normalizedLines.join(' ')}');
        } else if (blockType == 'list') {
          if (listsAsText) {
            outputBlocks.add(normalizedLines.join(' '));
          } else {
            outputBlocks.addAll(normalizedLines.map((line) => '- $line'));
          }
        } else if (blockType == 'image_caption') {
          if (includeImages) {
            outputBlocks.add(normalizedLines.join(' '));
          }
        } else {
          outputBlocks.add(normalizedLines.join(' '));
        }
      }
    }

    if (outputBlocks.isEmpty) return '';
    return '${outputBlocks.join(blockSeparator).trimRight()}\n';
  }

  static Future<void> exportToFile({
    required String inputJsonFile,
    required String outputMarkdownFile,
    Map<String, String>? hashTextOverrides,
    bool includeImages = true,
    bool preferCorrectedContent = true,
    bool listsAsText = false,
    bool allAsText = false,
    String blockSeparator = '\n\n',
    Set<String> skipHashes = const <String>{},
    SkipHashesMode skipHashesMode = SkipHashesMode.span,
  }) async {
    final markdown = await buildFromJsonFile(
      inputJsonFile,
      hashTextOverrides: hashTextOverrides,
      includeImages: includeImages,
      preferCorrectedContent: preferCorrectedContent,
      listsAsText: listsAsText,
      allAsText: allAsText,
      blockSeparator: blockSeparator,
      skipHashes: skipHashes,
      skipHashesMode: skipHashesMode,
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
      required bool allAsText,
      required Set<String> skipHashes,
      required SkipHashesMode skipHashesMode,
    }
  ) {
    if (!includeImages) {
      return const [];
    }

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
            skipHashes: skipHashes,
            skipHashesMode: skipHashesMode,
          ),
        );
      }
    }

    final output = <String>[];
    if (imagePaths.isEmpty && captions.isNotEmpty) {
      output.add(allAsText ? 'Image' : '[Image]');
    }
    for (final imagePath in imagePaths) {
      output.add(allAsText ? imagePath : '![]($imagePath)');
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

    if (preferCorrectedContent) {
      if (span.containsKey('corrected_content')) {
        return (span['corrected_content'] ?? '').toString().trim();
      } else {
        return (span['content'] ?? '').toString().trim();
      }
    }

    return (span['content'] ?? '').toString().trim();
  }

  static String _extractLineText(
    dynamic line,
    Map<String, String> overrides,
    {
      bool preferCorrectedContent = true,
      Set<String> skipHashes = const <String>{},
      SkipHashesMode skipHashesMode = SkipHashesMode.span,
    }
  ) {
    if (line is! Map) return '';
    final spans = line['spans'];
    if (spans is! List) return '';

    final parts = <String>[];
    bool appendToPreviousPart = false;
    for (final span in spans) {
      if (skipHashesMode == SkipHashesMode.span && span is Map) {
        final hash = (span['hash'] ?? '').toString().trim();
        if (hash.isNotEmpty && skipHashes.contains(hash)) {
          continue;
        }
      }

      var text = _resolveSpanText(
        span,
        overrides,
        preferCorrectedContent: preferCorrectedContent,
      );

      text = text.trimRight();
      final spanEndsWithHyphen = _lineJoinDashes.any(text.endsWith);
      if (spanEndsWithHyphen) {
        for (final dash in _lineJoinDashes) {
          if (text.endsWith(dash)) {
            text = text.substring(0, text.length - dash.length).trimRight();
            break;
          }
        }
      }

      if (text.isNotEmpty) {
        if (appendToPreviousPart && parts.isNotEmpty) {
          parts[parts.length - 1] = '${parts.last}${text.trimLeft()}';
        } else {
          parts.add(text);
        }
      }

      appendToPreviousPart = spanEndsWithHyphen;
    }

    return parts.join(' ').trim();
  }

  static bool _lineContainsSkippedHash(dynamic line, Set<String> skipHashes) {
    if (skipHashes.isEmpty) return false;
    if (line is! Map) return false;

    final spans = line['spans'];
    if (spans is! List) return false;

    for (final span in spans) {
      if (span is! Map) continue;
      final hash = (span['hash'] ?? '').toString().trim();
      if (hash.isNotEmpty && skipHashes.contains(hash)) {
        return true;
      }
    }

    return false;
  }

  static bool _lineEndsWithJoinDash(
    dynamic line,
    Map<String, String> overrides,
    {
      bool preferCorrectedContent = true,
      Set<String> skipHashes = const <String>{},
      SkipHashesMode skipHashesMode = SkipHashesMode.span,
    }
  ) {
    if (line is! Map) return false;
    final spans = line['spans'];
    if (spans is! List) return false;

    for (int index = spans.length - 1; index >= 0; index--) {
      final span = spans[index];
      if (skipHashesMode == SkipHashesMode.span && span is Map) {
        final hash = (span['hash'] ?? '').toString().trim();
        if (hash.isNotEmpty && skipHashes.contains(hash)) {
          continue;
        }
      }

      final text = _resolveSpanText(
        span,
        overrides,
        preferCorrectedContent: preferCorrectedContent,
      ).trimRight();

      if (text.isEmpty) {
        continue;
      }

      return _lineJoinDashes.any(text.endsWith);
    }

    return false;
  }

  static List<String> _extractBlockLines(
    dynamic block,
    Map<String, String> overrides,
    {
      bool preferCorrectedContent = true,
      Set<String> skipHashes = const <String>{},
      SkipHashesMode skipHashesMode = SkipHashesMode.span,
    }
  ) {
    if (block is! Map) return const [];
    final lines = block['lines'];
    if (lines is! List) return const [];

    final results = <String>[];
    bool appendToPreviousLine = false;
    for (final line in lines) {
      if (skipHashesMode == SkipHashesMode.line && _lineContainsSkippedHash(line, skipHashes)) {
        appendToPreviousLine = false;
        continue;
      }

      final lineEndsWithHyphen = _lineEndsWithJoinDash(
        line,
        overrides,
        preferCorrectedContent: preferCorrectedContent,
        skipHashes: skipHashes,
        skipHashesMode: skipHashesMode,
      );

      var text = _extractLineText(
        line,
        overrides,
        preferCorrectedContent: preferCorrectedContent,
        skipHashes: skipHashes,
        skipHashesMode: skipHashesMode,
      );

      text = text.trimRight();

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
