enum RepeatFrequency { none, daily, weekly, monthly, weekdays, yearly, custom }

enum ReminderPriority { low, medium, high }

class Reminder {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final RepeatFrequency repeatFrequency;
  final bool isActive;
  final ReminderPriority priority;
  
  // Custom repeat fields
  final int? customInterval; // e.g., 3
  final String? customUnit;  // 'days', 'weeks', 'months'

  Reminder({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.repeatFrequency = RepeatFrequency.none,
    this.isActive = true,
    this.priority = ReminderPriority.medium,
    this.customInterval,
    this.customUnit,
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
      'customInterval': customInterval,
      'customUnit': customUnit,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    final idRaw = map['id'];
    final id = idRaw is int ? idRaw : int.parse(idRaw.toString());
    
    final repeatRaw = (map['repeatFrequency'] ?? 'none').toString().toLowerCase();
    final priorityRaw = (map['priority'] ?? 'medium').toString().toLowerCase();
    final activeRaw = map['isActive'];

    return Reminder(
      id: id,
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
      customInterval: map['customInterval'] != null ? int.tryParse(map['customInterval'].toString()) : null,
      customUnit: map['customUnit']?.toString(),
    );
  }

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
        customInterval: customInterval,
        customUnit: customUnit,
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
      customInterval: customInterval,
      customUnit: customUnit,
    );
  }

  DateTime _stepInterval(DateTime t) => switch (repeatFrequency) {
        RepeatFrequency.daily => t.add(const Duration(days: 1)),
        RepeatFrequency.weekly => t.add(const Duration(days: 7)),
        RepeatFrequency.monthly =>
          DateTime(t.year, t.month + 1, t.day, t.hour, t.minute),
        RepeatFrequency.weekdays => _nextWeekday(t),
        RepeatFrequency.yearly => DateTime(t.year + 1, t.month, t.day, t.hour, t.minute),
        RepeatFrequency.custom => _stepCustom(t),
        RepeatFrequency.none => t,
      };

  DateTime _nextWeekday(DateTime t) {
    var next = t.add(const Duration(days: 1));
    while (next.weekday == DateTime.saturday || next.weekday == DateTime.sunday) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  DateTime _stepCustom(DateTime t) {
    final interval = customInterval ?? 1;
    final unit = customUnit ?? 'days';
    return switch (unit) {
      'days' => t.add(Duration(days: interval)),
      'weeks' => t.add(Duration(days: interval * 7)),
      'months' => DateTime(t.year, t.month + interval, t.day, t.hour, t.minute),
      _ => t.add(const Duration(days: 1)),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reminder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          body == other.body &&
          scheduledTime.isAtSameMomentAs(other.scheduledTime) &&
          repeatFrequency == other.repeatFrequency &&
          isActive == other.isActive &&
          priority == other.priority &&
          customInterval == other.customInterval &&
          customUnit == other.customUnit;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      body.hashCode ^
      scheduledTime.hashCode ^
      repeatFrequency.hashCode ^
      isActive.hashCode ^
      priority.hashCode ^
      customInterval.hashCode ^
      customUnit.hashCode;
}
