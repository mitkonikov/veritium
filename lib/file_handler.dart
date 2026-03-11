import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math';
import 'markdown_exporter.dart';

class FileHandler {
  static String generateRandomHash() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(64, (index) => chars[random.nextInt(chars.length)]).join();
  }

  static Future<(String, List<BoundingBox>)> loadJsonFileWithPath() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) {
      throw Exception('No file selected.');
    }
    String filePath = result.files.single.path!;
    return await loadJsonFileFromPath(filePath);
  }

  // Load JSON directly from a provided file path (no FilePicker interaction).
  static Future<(String, List<BoundingBox>)> loadJsonFileFromPath(String filePath, {bool writeBackups = true}) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('No file found at $filePath');
    }
    String fileContent = await file.readAsString();
    final jsonData = jsonDecode(fileContent);
    List<dynamic> pdfInfo = jsonData['pdf_info'] ?? [];
    List<BoundingBox> allBboxes = [];
    bool updated = false;
    for (var page in pdfInfo) {
      List<dynamic> paraBlocks = page['para_blocks'] ?? [];
      for (var block in paraBlocks) {
        if (block['bbox'] != null) {
          if (block['hash'] == null) {
            block['hash'] = generateRandomHash();
            updated = true;
          }

          List<MapEntry<String, String>> hashTextPairs = [];
          bool foundSpans = false;
          for (var line in block['lines'] ?? []) {
            for (var span in line['spans'] ?? []) {
              String content = span['corrected_content'] ?? span['content'] ?? '';
              String hash = span['hash'] ?? generateRandomHash();
              if (span['hash'] == null) {
                span['hash'] = hash;
                updated = true;
              }
              hashTextPairs.add(MapEntry(hash, content));
              foundSpans = true;
            }
          }
          if (!foundSpans) {
            continue;
          }
          allBboxes.add(BoundingBox.fromJson({
            'page_idx': page['page_idx'],
            'hash': block['hash'],
            'hash_text_pairs': hashTextPairs.map((e) => {'hash': e.key, 'text': e.value}).toList(),
            'bbox': block['bbox'],
            'is_flagged': block['flagged'] ?? false,
            'comment': block['comment'] ?? '',
          }));
        }
      }
    }
    if (updated && writeBackups) {
      // Make a backup of the original file
      final backupFile = File('$filePath.bak');
      await backupFile.writeAsString(fileContent);
      // Save the modified JSON back to the file
      await file.writeAsString(JsonEncoder.withIndent('  ').convert(jsonData));
    }
    return (filePath, allBboxes);
  }

  static Future<void> renderBoxes(
    String pdfFilePath,
    List<BoundingBox> allBboxes,
    bool spans,
    double dpi, {
    void Function(int processed, int total)? onProgress,
  }) async {
    File pdfFile = File(pdfFilePath);
    if (!pdfFile.existsSync()) {
      throw Exception('PDF file not found: $pdfFilePath');
    }
    final doc = await pdfrx.PdfDocument.openFile(pdfFilePath);
    // Group bounding boxes by page index
    Map<int, List<BoundingBox>> bboxesByPage = {};
    for (var bbox in allBboxes) {
      bboxesByPage.putIfAbsent(bbox.pageIndex, () => []).add(bbox);
    }
    final int totalBoxes = bboxesByPage.values.fold<int>(0, (s, e) => s + e.length);
    int processedBoxes = 0;
    for (var entry in bboxesByPage.entries) {
      int pageIndex = entry.key;
      List<BoundingBox> pageBboxes = entry.value;
      if (pageIndex < doc.pages.length) {
        final page = doc.pages[pageIndex];
        final pageImage = await page.render(
          fullWidth: page.width * (dpi / 72),
          fullHeight: page.height * (dpi / 72),
        );
        final img = await pageImage?.createImage();
        if (img == null) continue;
        final double scaleX = img.width / page.width;
        final double scaleY = img.height / page.height;
        for (var bbox in pageBboxes) {
          final int left = (bbox.xMin * scaleX).round();
          final int top = (bbox.yMin * scaleY).round();
          final int width = ((bbox.xMax - bbox.xMin) * scaleX).round();
          final int height = ((bbox.yMax - bbox.yMin) * scaleY).round();
          final ui.PictureRecorder recorder = ui.PictureRecorder();
          final ui.Canvas canvas = ui.Canvas(recorder);
          final paint = ui.Paint();
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(left.toDouble(), top.toDouble(), width.toDouble(), height.toDouble()),
            Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
            paint,
          );
          final cropped = await recorder.endRecording().toImage(width, height);
          final pngBytes = await cropped.toByteData(format: ui.ImageByteFormat.png);
          if (spans) {
            bbox.croppedSpans = cropped;
            bbox.croppedSpansPngBytes = pngBytes?.buffer.asUint8List();
          } else {
            bbox.croppedImage = cropped;
            bbox.croppedPngBytes = pngBytes?.buffer.asUint8List();
          }
          // update progress
          processedBoxes += 1;
          if (onProgress != null) {
            try {
              onProgress(processedBoxes, totalBoxes);
            } catch (_) {}
          }
        }
      }
    }
    // No UI side effects, errors are thrown to be handled by the caller
  }

  static Future<void> pdfrxInitialize() async {
    pdfrx.pdfrxFlutterInitialize();
  }

  static Future<void> saveCorrectedJsonFile(String originalJsonFile, String jsonFilePath, List<BoundingBox> boxes) async {
    try {
      final file = File(originalJsonFile);
      String fileContent = await file.readAsString();
      final jsonData = jsonDecode(fileContent);
      List<dynamic> pdfInfo = jsonData['pdf_info'] ?? [];
      // Accumulate all hashes from every box
      final Map<String, String> hashToText = {};
      final Map<String, BoundingBox> hashToBox = {};
      for (final box in boxes) {
        for (final pair in box.hashTextPairs) {
          hashToText[pair.key] = pair.value;
        }
        hashToBox[box.hash] = box;
      }

      for (var page in pdfInfo) {
        List<dynamic> paraBlocks = page['para_blocks'] ?? [];
        for (var block in paraBlocks) {
          List<dynamic> lines = block['lines'] ?? [];
          if (block['hash'] != null && hashToBox.containsKey(block['hash'])) {
            final box = hashToBox[block['hash']]!;
            block['flagged'] = box.isFlagged;
            block['comment'] = box.comment;
          }
          for (var line in lines) {
            List<dynamic> spans = line['spans'] ?? [];
            for (var span in spans) {
              final String hash = (span['hash'] ?? '').toString();
              if (hash.isNotEmpty && hashToText.containsKey(hash)) {
                final corrected = hashToText[hash]!;
                if (span['content'] != corrected) {
                  span['corrected_content'] = corrected;
                }
              }
            }
          }
        }
      }

      if (originalJsonFile == jsonFilePath) {
        // Save the modified JSON back to the file
        await file.writeAsString(JsonEncoder.withIndent('  ').convert(jsonData));
      } else {
        // Save to a new file
        final newFile = File(jsonFilePath);
        await newFile.writeAsString(JsonEncoder.withIndent('  ').convert(jsonData));
      }
    } catch (e) {
      // Handle errors
      debugPrint('Error saving corrected JSON: $e');
    }
  }

  static Future<void> saveNewCorrectedJsonFile(String originalJsonFile, List<BoundingBox> boxes) async {
    String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Corrected JSON As',
      fileName: 'corrected_output.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (savePath != null) {
      saveCorrectedJsonFile(originalJsonFile, savePath, boxes);
    }
  }

  static Map<String, String> _hashTextOverrides(List<BoundingBox> boxes) {
    final Map<String, String> hashToText = {};
    for (final box in boxes) {
      for (final pair in box.hashTextPairs) {
        hashToText[pair.key] = pair.value;
      }
    }
    return hashToText;
  }

  static Future<String> buildMarkdownFromJson(String originalJsonFile, List<BoundingBox> boxes) {
    return MarkdownExporter.buildFromJsonFile(
      originalJsonFile,
      hashTextOverrides: _hashTextOverrides(boxes),
    );
  }

  static Future<bool> exportMarkdownFromJson(String originalJsonFile, List<BoundingBox> boxes) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Markdown As',
      fileName: MarkdownExporter.defaultOutputFileName(originalJsonFile),
      type: FileType.custom,
      allowedExtensions: ['md'],
    );

    if (savePath == null) {
      return false;
    }

    await MarkdownExporter.exportToFile(
      inputJsonFile: originalJsonFile,
      outputMarkdownFile: savePath,
      hashTextOverrides: _hashTextOverrides(boxes),
    );
    return true;
  }
}

class BoundingBox {
  final int pageIndex;
  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;
  List<MapEntry<String, String>> hashTextPairs;
  String hash;
  ui.Image? croppedImage;
  Uint8List? croppedPngBytes;
  ui.Image? croppedSpans;
  Uint8List? croppedSpansPngBytes;
  bool isFlagged;
  String comment = '';
  bool isDirty = false;

  BoundingBox({
    required this.pageIndex,
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
    required this.hashTextPairs,
    required this.hash,
    this.croppedImage,
    this.croppedPngBytes,
    this.isFlagged = false,
    this.comment = '',
    this.isDirty = false,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    List<MapEntry<String, String>> pairs = [];
    if (json['hash_text_pairs'] != null) {
      for (var pair in json['hash_text_pairs']) {
        if (pair is MapEntry) {
          pairs.add(MapEntry(
            pair.key.toString(),
            pair.value.toString(),
          ));
        } else if (pair is Map) {
          pairs.add(MapEntry(
            (pair['hash'] ?? '').toString(),
            (pair['text'] ?? '').toString(),
          ));
        }
      }
    }
    return BoundingBox(
      pageIndex: json['page_idx'],
      hash: json['hash'] ?? '',
      hashTextPairs: pairs,
      xMin: json['bbox'][0],
      yMin: json['bbox'][1],
      xMax: json['bbox'][2],
      yMax: json['bbox'][3],
      isFlagged: json['is_flagged'] ?? false,
      comment: json['comment'] ?? '',
      isDirty: false,
    );
  }

  String get text {
    return hashTextPairs.map((e) => e.value).join('\n');
  }

  void updateText(String newText) {
    List<String> lines = newText.split('\n');
    for (int i = 0; i < hashTextPairs.length; i++) {
      if (i < lines.length) {
        hashTextPairs[i] = MapEntry(hashTextPairs[i].key, lines[i]);
      } else {
        hashTextPairs[i] = MapEntry(hashTextPairs[i].key, '');
      }
    }
    isDirty = true;
  }
}