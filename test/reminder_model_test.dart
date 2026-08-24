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

  group('advancedForCompletion', () {
    Reminder reminderAt(
      DateTime time, {
      RepeatFrequency repeat = RepeatFrequency.none,
      bool isActive = true,
    }) =>
        Reminder(
          id: 1,
          title: 'T',
          body: 'B',
          scheduledTime: time,
          repeatFrequency: repeat,
          isActive: isActive,
        );

    test('one-time reminder is deactivated, date untouched', () {
      final now = DateTime(2026, 8, 24, 14);
      final r = reminderAt(DateTime(2026, 8, 24, 9));

      final out = r.advancedForCompletion(now: now);

      expect(out.isActive, isFalse);
      expect(out.scheduledTime, r.scheduledTime);
      expect(out.repeatFrequency, RepeatFrequency.none);
    });

    test('daily reminder completed after due time moves to tomorrow', () {
      final now = DateTime(2026, 8, 24, 14); // completed 14:00
      final r = reminderAt(DateTime(2026, 8, 24, 9), repeat: RepeatFrequency.daily);

      final out = r.advancedForCompletion(now: now);

      expect(out.isActive, isTrue);
      expect(out.scheduledTime, DateTime(2026, 8, 25, 9));
    });

    test('daily reminder completed before due time still skips today', () {
      final now = DateTime(2026, 8, 24, 8); // completed early, 08:00
      final r = reminderAt(DateTime(2026, 8, 24, 21), repeat: RepeatFrequency.daily);

      final out = r.advancedForCompletion(now: now);

      expect(out.isActive, isTrue);
      expect(out.scheduledTime, DateTime(2026, 8, 25, 21));
    });

    test('overdue daily reminder skips missed days', () {
      // Due Aug 22 09:00, only completed on Aug 24 at 15:00.
      final now = DateTime(2026, 8, 24, 15);
      final r = reminderAt(DateTime(2026, 8, 22, 9), repeat: RepeatFrequency.daily);

      final out = r.advancedForCompletion(now: now);

      expect(out.isActive, isTrue);
      expect(out.scheduledTime, DateTime(2026, 8, 25, 9));
    });

    test('weekly reminder advances exactly 7 days', () {
      final now = DateTime(2026, 8, 24, 12);
      final r = reminderAt(DateTime(2026, 8, 20, 7, 30), repeat: RepeatFrequency.weekly);

      final out = r.advancedForCompletion(now: now);

      expect(out.isActive, isTrue);
      expect(out.scheduledTime, DateTime(2026, 8, 27, 7, 30));
    });

    test('monthly reminder advances one month keeping the time', () {
      final now = DateTime(2026, 8, 24, 12);
      final r = reminderAt(DateTime(2026, 8, 10, 6, 15), repeat: RepeatFrequency.monthly);

      final out = r.advancedForCompletion(now: now);

      expect(out.isActive, isTrue);
      expect(out.scheduledTime, DateTime(2026, 9, 10, 6, 15));
    });
  });
}

