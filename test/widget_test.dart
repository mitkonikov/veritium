import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veritium/main.dart';

void main() {
  testWidgets('Veritium app shows File menu', (WidgetTester tester) async {
    await tester.pumpWidget(const Veritium());
    expect(find.text('File'), findsOneWidget);
  });

  testWidgets('CorrectionPage shows load file prompt when no file is loaded', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CorrectionPage()));
    expect(find.text('Please load a file to begin.'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(find.textContaining('Flag'), findsNothing);
  });
}
