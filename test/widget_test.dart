import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veritium/main.dart';

void main() {
  testWidgets('Veritium app shows File menu', (WidgetTester tester) async {
    await tester.pumpWidget(const Veritium());
    expect(find.text('File'), findsOneWidget);
  });

  testWidgets('CorrectionPage shows Save and Flag buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CorrectionPage()));
    expect(find.text('Save'), findsOneWidget);
    expect(find.textContaining('Flag'), findsOneWidget);
  });
}
