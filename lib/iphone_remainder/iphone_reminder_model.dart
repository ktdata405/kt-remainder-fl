import 'package:flutter/material.dart';

class ReminderListInfo {
  final String name;
  final Color color;
  final IconData icon;

  const ReminderListInfo({
    required this.name,
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'color': color.toARGB32(),
    'icon': icon.codePoint,
  };

  factory ReminderListInfo.fromJson(Map<String, dynamic> json) => ReminderListInfo(
    name: json['name'] ?? 'Reminders',
    color: Color(json['color'] ?? 0xFF007AFF),
    icon: IconData(json['icon'] ?? Icons.list_rounded.codePoint, fontFamily: 'MaterialIcons'),
  );
}
