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

  testWidgets('AppBar contains Goto and View menu with UI Scale', (WidgetTester tester) async {
    await tester.pumpWidget(const Veritium());

    // Ensure Goto exists
    expect(find.text('Goto'), findsOneWidget);

    // Open the View menu and check for UI Scale option
    expect(find.text('View'), findsOneWidget);
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(find.text('UI Scale'), findsOneWidget);
  });
}
