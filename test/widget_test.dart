import 'package:flutter_test/flutter_test.dart';

import 'package:kt_remainder_fl/main.dart';

void main() {
  testWidgets('ReminderApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ReminderApp());
    await tester.pumpAndSettle();

    // With no configured URL in test env, app shows the connection error state.
    expect(find.text('Connection Error'), findsOneWidget);
  });
}
