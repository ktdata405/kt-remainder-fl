import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kt_remainder_fl/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('ReminderApp renders', (WidgetTester tester) async {
    // Initialize mock values for SharedPreferences
    SharedPreferences.setMockInitialValues({});
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ReminderApp());
    
    // The app starts in an initialization state showing a CircularProgressIndicator.
    // pumpAndSettle() would timeout here because the indicator animates infinitely.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Re-pump to allow async initialization to progress
    await tester.pump();
    
    // In a test environment without a real webAppUrl, it eventually shows "Connection Error"
    // We wait a bit for the async initialize() to complete in ReminderScreen.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Connection Error'), findsOneWidget);
  });
}
