import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';
import 'dart:convert';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math';

class FileHandler {
  static Future<void> loadAltoXml(BuildContext context) async {
    try {
      // Open file picker to select an XML file
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xml']);

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        File file = File(filePath);

        // Read the XML file
        String fileContent = await file.readAsString();

        // Parse the XML content (not used)
        XmlDocument.parse(fileContent); 

        if (context.mounted) {
          // Display success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully loaded XML file: $filePath')),
          );
        }

        // Perform further processing with `xmlDocument` if needed
      } else {
        // User canceled the file picker
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No file selected.')),
          );
        }
      }
    } catch (e) {
      // Handle errors
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading XML file: $e')),
        );
      }
    }
  }

  static String generateRandomHash() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(64, (index) => chars[random.nextInt(chars.length)]).join();
  }

  static Future<(String, List<BoundingBox>)> loadJsonFileWithPath() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result == null || result.files.single.path == null) {
      throw Exception('No file selected.');
    }
    String filePath = result.files.single.path!;
    File file = File(filePath);
    String fileContent = await file.readAsString();
    final jsonData = jsonDecode(fileContent);
    List<dynamic> pdfInfo = jsonData['pdf_info'] ?? [];
    List<BoundingBox> allBboxes = [];
    bool updated = false;
    for (var page in pdfInfo) {
      List<dynamic> paraBlocks = page['para_blocks'] ?? [];
      for (var block in paraBlocks) {
        if (block['bbox'] != null) {
          List<MapEntry<String, String>> hashTextPairs = [];
          bool foundSpans = false;
          for (var line in block['lines'] ?? []) {
            for (var span in line['spans'] ?? []) {
              String content = span['corrected_content'] ?? span['content'] ?? '';
              String hash = span['content_hash'] ?? generateRandomHash();
              if (span['content_hash'] == null) {
                span['content_hash'] = hash;
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
            'hash_text_pairs': hashTextPairs.map((e) => {'hash': e.key, 'text': e.value}).toList(),
            'bbox': block['bbox'],
          }));
        }
      }
    }
    if (updated) {
      // Make a backup of the original file
      final backupFile = File('$filePath.bak');
      await backupFile.writeAsString(fileContent);
      // Save the modified JSON back to the file
      await file.writeAsString(JsonEncoder.withIndent('  ').convert(jsonData));
    }
    return (filePath, allBboxes);
  }

  static Future<void> renderBoxes(String jsonFilePath, List<BoundingBox> allBboxes) async {
    String pdfFilePath = jsonFilePath.replaceAll('_middle.json', '_origin.pdf');
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
    for (var entry in bboxesByPage.entries) {
      int pageIndex = entry.key;
      List<BoundingBox> pageBboxes = entry.value;
      if (pageIndex < doc.pages.length) {
        final page = doc.pages[pageIndex];
        final pageImage = await page.render();
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
          bbox.croppedImage = cropped;
          bbox.croppedPngBytes = pngBytes?.buffer.asUint8List();
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
      final Set<String> flaggedHashes = {};
      for (final box in boxes) {
        for (final pair in box.hashTextPairs) {
          hashToText[pair.key] = pair.value;
          if (box.isFlagged) {
            flaggedHashes.add(pair.key);
          }
        }
      }

      for (var page in pdfInfo) {
        List<dynamic> paraBlocks = page['para_blocks'] ?? [];
        for (var block in paraBlocks) {
          List<dynamic> lines = block['lines'] ?? [];
          for (var line in lines) {
            List<dynamic> spans = line['spans'] ?? [];
            for (var span in spans) {
              final String hash = (span['content_hash'] ?? '').toString();
              if (hash.isNotEmpty && hashToText.containsKey(hash)) {
                final corrected = hashToText[hash]!;
                if (span['content'] != corrected) {
                  span['corrected_content'] = corrected;
                }
                // Save flagged status
                if (flaggedHashes.contains(hash)) {
                  span['flagged'] = true;
                } else {
                  span['flagged'] = false;
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
}

class BoundingBox {
  final int pageIndex;
  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;
  List<MapEntry<String, String>> hashTextPairs;
  ui.Image? croppedImage;
  Uint8List? croppedPngBytes;
  bool isFlagged;

  BoundingBox({
    required this.pageIndex,
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
    required this.hashTextPairs,
    this.croppedImage,
    this.croppedPngBytes,
    this.isFlagged = false,
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
      hashTextPairs: pairs,
      xMin: json['bbox'][0],
      yMin: json['bbox'][1],
      xMax: json['bbox'][2],
      yMax: json['bbox'][3],
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
  }
}