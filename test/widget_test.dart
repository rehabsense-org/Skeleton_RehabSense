import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_rehabsense/main.dart';

void main() {
  testWidgets('RehabSenseApp widget loads MaterialApp', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RehabSenseApp());

    // Verify MaterialApp is present
    expect(find.byType(MaterialApp), findsOneWidget);

    // Verify the title is RehabSense
    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.title, 'RehabSense');
  });
}
