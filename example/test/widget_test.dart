// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:rich_text_editor_example/main.dart';

void main() {
  testWidgets('demo screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());

    expect(find.text('Rich Text Editor Feature Demo'), findsOneWidget);
    expect(find.text('JSON'), findsOneWidget);
    expect(find.text('HTML'), findsOneWidget);
  });
}
