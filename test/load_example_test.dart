import 'package:flutter_test/flutter_test.dart';
import 'package:veritium/file_handler.dart';

void main() {
  test('load example json file from examples folder', () async {
    final path = 'examples/straza/id-40086785_date-19091112_vol-01_no-132_middle.json';
    final result = await FileHandler.loadJsonFileFromPath(path, writeBackups: false);
    // Record tuple fields are $1 (path) and $2 (list of boxes)
    expect(result.$1, isA<String>());
    expect(result.$2, isA<List>());
    expect(result.$2.length, greaterThan(0));
  });
}
