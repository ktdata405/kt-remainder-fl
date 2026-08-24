enum RepeatFrequency { none, daily, weekly, monthly }

enum ReminderPriority { low, medium, high }

class Reminder {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final RepeatFrequency repeatFrequency;
  final bool isActive;
  final ReminderPriority priority;

  Reminder({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.repeatFrequency = RepeatFrequency.none,
    this.isActive = true,
    this.priority = ReminderPriority.medium,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'scheduledTime': scheduledTime.toIso8601String(),
      'repeatFrequency': repeatFrequency.name,
      'isActive': isActive,
      'priority': priority.name,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    final repeatRaw = (map['repeatFrequency'] ?? 'none').toString().toLowerCase();
    final priorityRaw = (map['priority'] ?? 'medium').toString().toLowerCase();
    final activeRaw = map['isActive'];

    return Reminder(
      id: map['id'],
      title: map['title'],
      body: map['body'],
      scheduledTime: DateTime.parse(map['scheduledTime']),
      repeatFrequency: RepeatFrequency.values.firstWhere(
        (value) => value.name.toLowerCase() == repeatRaw,
        orElse: () => RepeatFrequency.none,
      ),
      isActive: activeRaw is bool ? activeRaw : activeRaw.toString().toLowerCase() == 'true',
      priority: ReminderPriority.values.firstWhere(
        (value) => value.name.toLowerCase() == priorityRaw,
        orElse: () => ReminderPriority.medium,
      ),
    );
  }

  /// Returns the reminder state after the user completes its current
  /// occurrence.
  ///
  /// * One-time ([RepeatFrequency.none]) or already inactive reminders come
  ///   back deactivated (`isActive: false`).
  /// * Repeating reminders stay active and [scheduledTime] moves to the next
  ///   occurrence: exactly one interval after the completed slot, then stepped
  ///   forward until it lies in the future relative to [now] so overdue items
  ///   skip missed days instead of resurfacing in the past.
  Reminder advancedForCompletion({DateTime? now}) {
    final ref = now ?? DateTime.now();
    if (!isActive || repeatFrequency == RepeatFrequency.none) {
      return Reminder(
        id: id,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
        repeatFrequency: repeatFrequency,
        isActive: false,
        priority: priority,
      );
    }
    var next = _stepInterval(scheduledTime);
    while (!next.isAfter(ref)) {
      next = _stepInterval(next);
    }
    return Reminder(
      id: id,
      title: title,
      body: body,
      scheduledTime: next,
      repeatFrequency: repeatFrequency,
      isActive: true,
      priority: priority,
    );
  }

  DateTime _stepInterval(DateTime t) => switch (repeatFrequency) {
        RepeatFrequency.daily => t.add(const Duration(days: 1)),
        RepeatFrequency.weekly => t.add(const Duration(days: 7)),
        RepeatFrequency.monthly =>
          DateTime(t.year, t.month + 1, t.day, t.hour, t.minute),
        RepeatFrequency.none => t,
      };
}

