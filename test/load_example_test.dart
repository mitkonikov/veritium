import 'package:flutter_test/flutter_test.dart';
import 'package:veritium/file_handler.dart';
import 'package:veritium/markdown_exporter.dart';

void main() {
  test('load example json file from examples folder', () async {
    final path = 'examples/straza/id-40086785_date-19091112_vol-01_no-132_middle.json';
    final result = await FileHandler.loadJsonFileFromPath(path, writeBackups: false);
    // Record tuple fields are $1 (path) and $2 (list of boxes)
    expect(result.$1, isA<String>());
    expect(result.$2, isA<List>());
    expect(result.$2.length, greaterThan(0));
  });

  test('build markdown from example middle json', () async {
    final path = 'examples/straza/id-40086785_date-19091112_vol-01_no-132_middle.json';
    final markdown = await MarkdownExporter.buildFromJsonFile(path);

    expect(markdown, isNotEmpty);
    expect(markdown, contains('# '));
    expect(markdown, contains('- '));
    expect(markdown, contains('![]('));
  });

  test('build markdown without image entries', () async {
    final path = 'examples/straza/id-40086785_date-19091112_vol-01_no-132_middle.json';
    final markdown = await MarkdownExporter.buildFromJsonFile(
      path,
      includeImages: false,
    );

    expect(markdown, isNotEmpty);
    expect(markdown, isNot(contains('![](')));
  });

  test('default markdown filename is derived from _middle.json', () {
    const input = 'examples/straza/sample_middle.json';
    final output = MarkdownExporter.defaultOutputFileName(input);
    expect(output, 'sample.md');
  });
}
