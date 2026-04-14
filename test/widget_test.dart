// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/main.dart';

void main() {
  testWidgets('Betrugsradar app renders key sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Betrugsradar'), findsOneWidget);
    expect(find.text('Risk Analyzer'), findsOneWidget);
    expect(find.text('Incoming Call Simulation'), findsOneWidget);
    expect(find.text('Nummer analysieren'), findsOneWidget);
  });
}
