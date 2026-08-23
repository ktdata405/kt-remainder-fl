import 'package:flutter_test/flutter_test.dart';
import 'package:kt_remainder_fl/remainder/reminder_model.dart';

void main() {
  test('Reminder serialization roundtrip', () {
    final original = Reminder(
      id: 1,
      title: 'Title',
      body: 'Body',
      scheduledTime: DateTime.utc(2026, 1, 1, 10, 30),
    );

    final encoded = original.toMap();
    final decoded = Reminder.fromMap(encoded);

    expect(decoded.id, original.id);
    expect(decoded.title, original.title);
    expect(decoded.body, original.body);
    expect(decoded.scheduledTime, original.scheduledTime);
  });
}

