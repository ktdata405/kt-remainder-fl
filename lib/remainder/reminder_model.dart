enum RepeatFrequency { none, daily, weekly, monthly }

class Reminder {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final RepeatFrequency repeatFrequency;
  final bool isActive;

  Reminder({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.repeatFrequency = RepeatFrequency.none,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'scheduledTime': scheduledTime.toIso8601String(),
      'repeatFrequency': repeatFrequency.name,
      'isActive': isActive,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    final repeatRaw = (map['repeatFrequency'] ?? 'none').toString();
    final activeRaw = map['isActive'];

    return Reminder(
      id: map['id'],
      title: map['title'],
      body: map['body'],
      scheduledTime: DateTime.parse(map['scheduledTime']),
      repeatFrequency: RepeatFrequency.values.firstWhere(
        (value) => value.name == repeatRaw,
        orElse: () => RepeatFrequency.none,
      ),
      isActive: activeRaw is bool ? activeRaw : activeRaw.toString() == 'true',
    );
  }
}

