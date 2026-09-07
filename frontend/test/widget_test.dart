import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    await tester.pumpWidget(const PrintoutBillingApp());
    expect(find.byType(PrintoutBillingApp), findsOneWidget);
  });
}
