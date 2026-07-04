// Basic smoke test for the Munshi walking skeleton.

import 'package:flutter_test/flutter_test.dart';

import 'package:munshi/main.dart';

void main() {
  testWidgets('App boots to the dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MunshiApp());
    await tester.pumpAndSettle();

    // Dashboard hero + nav shell are present.
    expect(find.text('Safe to spend today'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
  });
}
