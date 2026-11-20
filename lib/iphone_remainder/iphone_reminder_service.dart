import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../remainder/reminder_model.dart';
import 'iphone_reminder_model.dart';

class IphoneReminderService extends ChangeNotifier {
  IphoneReminderService._();
  static final IphoneReminderService instance = IphoneReminderService._();

  static const String _kCustomListsKey = 'iphone_custom_lists';

  List<ReminderListInfo> _customLists = [
    const ReminderListInfo(name: 'Reminders', color: Color(0xFFFF9500), icon: Icons.list_rounded),
  ];

  List<ReminderListInfo> get customLists => _customLists;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCustomListsKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).map((e) => ReminderListInfo.fromJson(e)).toList();
        if (list.isNotEmpty) {
          _customLists = list;
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> addCustomList(ReminderListInfo listInfo) async {
    if (_customLists.any((l) => l.name.toLowerCase() == listInfo.name.toLowerCase())) return;
    _customLists.add(listInfo);
    await _saveLists();
    notifyListeners();
  }

  Future<void> deleteCustomList(String name) async {
    _customLists.removeWhere((l) => l.name.toLowerCase() == name.toLowerCase());
    await _saveLists();
    notifyListeners();
  }

  Future<void> _saveLists() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_customLists.map((l) => l.toJson()).toList());
    await prefs.setString(_kCustomListsKey, jsonStr);
  }

  List<Reminder> getTodayReminders(List<Reminder> all) {
    final now = DateTime.now();
    return all.where((r) {
      if (!r.isActive) return false;
      final dt = r.scheduledTime;
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList();
  }

  List<Reminder> getScheduledReminders(List<Reminder> all) {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return all.where((r) {
      if (!r.isActive) return false;
      return r.scheduledTime.isAfter(todayEnd);
    }).toList();
  }

  List<Reminder> getAllReminders(List<Reminder> all) {
    return all.where((r) => r.isActive).toList();
  }

  List<Reminder> getFlaggedReminders(List<Reminder> all) {
    return all.where((r) => r.isActive && r.priority == ReminderPriority.high).toList();
  }

  List<Reminder> getRemindersForList(String listName, List<Reminder> all) {
    return all.where((r) {
      if (!r.isActive) return false;
      final rList = (r.customUnit != null && r.customUnit!.startsWith('list:'))
          ? r.customUnit!.substring(5)
          : 'Reminders';
      return rList.toLowerCase() == listName.toLowerCase();
    }).toList();
  }
}
