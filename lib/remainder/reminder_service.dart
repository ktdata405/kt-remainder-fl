import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../config/app_config.dart';
import '../services/database_service.dart';
import 'reminder_model.dart';

const String _actionComplete = 'action_complete';
const String _actionSnooze5 = 'action_snooze_5m';
const String _actionSnooze10 = 'action_snooze_10m';
const String _actionSnooze30 = 'action_snooze_30m';
const String _actionSnooze60 = 'action_snooze_60m';
const String _actionSnoozeTomorrow = 'action_snooze_tomorrow';
const String _actionSnoozeCustom = 'action_snooze_custom';
const String _kPendingCustomSnoozeId = 'pending_custom_snooze_id';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  ReminderService.instance.handleNotificationAction(response);
}

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'reminders_channel',
    'Reminders',
    description: 'Reminder notifications',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final StreamController<Reminder> _webDueReminderController = StreamController<Reminder>.broadcast();
  final StreamController<int> _customSnoozeRequestController = StreamController<int>.broadcast();

  String _webAppUrl = '';
  bool _isInitialized = false;
  Timer? _webReminderTimer;
  final Set<String> _webShownReminderKeys = <String>{};

  Stream<Reminder> get webDueReminderStream => _webDueReminderController.stream;
  Stream<int> get customSnoozeRequestStream => _customSnoozeRequestController.stream;

  void reset() {
    _isInitialized = false;
    _webAppUrl = '';
    _webReminderTimer?.cancel();
    _webReminderTimer = null;
    _webShownReminderKeys.clear();
  }

  Future<void> initialize({required String webAppUrl}) async {
    if (_isInitialized) return;
    _webAppUrl = webAppUrl.trim();
    await _configureLocalTimezone();
    if (!kIsWeb) {
      try {
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInit);
        await _notifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: handleNotificationAction,
          onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
        );
        final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
        await androidPlugin?.requestExactAlarmsPermission();
        await androidPlugin?.createNotificationChannel(_channel);
      } catch (_) {}
    }
    _isInitialized = true;
    rescheduleActiveRemindersFromSheet().catchError((e) {
      debugPrint('rescheduleActiveRemindersFromSheet skipped: $e');
    });
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    _assertInitialized();
    final active = Reminder(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      scheduledTime: reminder.scheduledTime,
      repeatFrequency: reminder.repeatFrequency,
      isActive: true,
      priority: reminder.priority,
      customInterval: reminder.customInterval,
      customUnit: reminder.customUnit,
    );
    // Offline first: save locally
    await DatabaseService.instance.insertReminder(active);
    await _scheduleNotification(active);
    
    // Background sync
    _upsertRemote(active).catchError((e) => debugPrint('Sync failed: $e'));
  }

  Future<void> completeReminder(int id) async {
    _assertInitialized();
    final source = await _findReminderById(id);
    if (source == null) throw StateError('Reminder not found: $id');
    final updated = source.advancedForCompletion();
    
    if (!updated.isActive) {
      await cancelReminder(id);
      return;
    }
    
    await DatabaseService.instance.updateReminder(updated);
    await _scheduleNotification(updated);
    
    _upsertRemote(updated).catchError((e) => debugPrint('Sync failed: $e'));
  }

  Future<void> snoozeReminder(int id, {Duration by = const Duration(minutes: 10)}) async {
    _assertInitialized();
    final source = await _findReminderById(id);
    if (source == null) throw StateError('Reminder not found: $id');
    final snoozed = Reminder(
      id: source.id,
      title: source.title,
      body: source.body,
      scheduledTime: DateTime.now().add(by),
      repeatFrequency: source.repeatFrequency,
      isActive: true,
      priority: source.priority,
      customInterval: source.customInterval,
      customUnit: source.customUnit,
    );
    
    await DatabaseService.instance.updateReminder(snoozed);
    await _scheduleNotification(snoozed);
    
    _upsertRemote(snoozed).catchError((e) => debugPrint('Sync failed: $e'));
  }

  Future<void> snoozeReminderTomorrow(int id) async {
    _assertInitialized();
    final source = await _findReminderById(id);
    if (source == null) throw StateError('Reminder not found: $id');
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, source.scheduledTime.hour, source.scheduledTime.minute);
    await _applySnooze(source, tomorrow);
  }

  Future<void> snoozeReminderUntil(int id, DateTime when) async {
    _assertInitialized();
    final source = await _findReminderById(id);
    if (source == null) throw StateError('Reminder not found: $id');
    await _applySnooze(source, when);
  }

  Future<int?> consumePendingCustomSnoozeRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_kPendingCustomSnoozeId);
    if (id != null) await prefs.remove(_kPendingCustomSnoozeId);
    return id;
  }

  Future<List<Reminder>> getLocalReminders() async {
    return await DatabaseService.instance.getAllReminders();
  }

  Future<List<Reminder>> fetchRemindersFromSheet() async {
    _assertInitialized();
    final uri = Uri.parse(_webAppUrl).replace(queryParameters: {'action': 'fetch'});
    final response = await http.get(uri);
    if (response.statusCode != 200) throw StateError('Fetch failed: ${response.body}');
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded.containsKey('error')) throw StateError('Fetch error: ${decoded['error']}');
    final rows = (decoded as List<dynamic>).cast<Map<String, dynamic>>();
    final reminders = rows.map(_mapToReminder).whereType<Reminder>().toList();
    reminders.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return reminders;
  }

  Future<void> cancelReminder(int id) async {
    _assertInitialized();
    if (!kIsWeb) await _notifications.cancel(id).catchError((_) {});
    await DatabaseService.instance.deleteReminder(id);
    _cancelRemoteById(id).catchError((e) => debugPrint('Sync failed: $e'));
  }

  Future<void> _cancelRemoteById(int id) async {
    final uri = Uri.parse(_webAppUrl).replace(queryParameters: {'action': 'cancel', 'id': id.toString()});
    final response = await http.get(uri);
    if (response.statusCode != 200) throw StateError('Cancel failed: ${response.body}');
  }

  Future<void> rescheduleActiveRemindersFromSheet() async {
    _assertInitialized();
    
    // 1. Load local first for immediate availability
    final localReminders = await DatabaseService.instance.getAllReminders();
    if (localReminders.isNotEmpty) {
      if (!kIsWeb) await _notifications.cancelAll().catchError((_) {});
      for (final reminder in localReminders.where((r) => r.isActive)) {
        await _scheduleNotification(reminder);
      }
    }

    // 2. Then background fetch from remote to sync
    try {
      final remoteReminders = await fetchRemindersFromSheet();
      
      // OPTIMIZATION: Check if remote data matches local data exactly to avoid redundant work
      if (listEquals(localReminders, remoteReminders)) {
        debugPrint('Sync skipped: Data matches local cache.');
        return;
      }

      // Merge Logic: Update local with remote data, but don't clear everything 
      // to avoid losing local-only items (like unsynced new reminders).
      final remoteIds = remoteReminders.map((r) => r.id).toSet();
      
      // Update/Insert all remote reminders into local database
      for (final r in remoteReminders) {
        await DatabaseService.instance.insertReminder(r);
      }
      
      // If the remote list is the source of truth for deletions, 
      // we could remove local items not in remoteIds. 
      // However, to be safe with offline usage, we only delete if the item was 
      // explicitly cancelled or completed.
      
      final updatedList = await DatabaseService.instance.getAllReminders();
      
      if (!kIsWeb) await _notifications.cancelAll().catchError((_) {});
      if (kIsWeb) _startWebDueReminderLoop(updatedList);
      for (final reminder in updatedList.where((r) => r.isActive)) {
        await _scheduleNotification(reminder);
      }
    } catch (e) {
      debugPrint('Remote sync failed: $e');
    }
  }

  Future<void> _configureLocalTimezone() async {
    tz.initializeTimeZones();
    if (kIsWeb) return;
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  void _assertInitialized() {
    if (!_isInitialized) throw StateError('ReminderService not initialized.');
  }

  Future<void> _upsertRemote(Reminder r) async {
    final data = jsonEncode(r.toMap());
    final uri = Uri.parse(_webAppUrl).replace(queryParameters: {'action': 'upsert', 'data': data});
    final response = await http.get(uri);
    if (response.statusCode != 200) throw StateError('Upsert failed: ${response.body}');
  }

  Future<void> _upsertRemoteMap(Map<String, dynamic> data) async {
    final uri = Uri.parse(_webAppUrl).replace(queryParameters: {'action': 'upsert', 'data': jsonEncode(data)});
    await http.get(uri).timeout(const Duration(seconds: 10));
  }

  Future<Reminder?> _findReminderById(int id) async {
    return await DatabaseService.instance.getReminderById(id);
  }

  Future<void> _applySnooze(Reminder source, DateTime when) async {
    final target = Reminder(
      id: source.id,
      title: source.title,
      body: source.body,
      scheduledTime: when,
      repeatFrequency: source.repeatFrequency,
      isActive: true,
      priority: source.priority,
      customInterval: source.customInterval,
      customUnit: source.customUnit,
    );
    await _upsertRemote(target);
    await _scheduleNotification(target);
  }

  Reminder? _mapToReminder(Map<String, dynamic> row) {
    try {
      return Reminder.fromMap(row);
    } catch (e) {
      debugPrint('Malformed row: $row\n$e');
      return null;
    }
  }

  Future<void> _scheduleNotification(Reminder r) async {
    if (kIsWeb || !r.isActive) return;
    final nextTime = _nextScheduleTime(r);
    if (nextTime == null) return;
    try {
      final tzDateTime = tz.TZDateTime.from(nextTime, tz.local);
      const androidDetails = AndroidNotificationDetails(
        'reminders_channel', 'Reminders',
        importance: Importance.max, priority: Priority.high,
        actions: [
          AndroidNotificationAction(_actionComplete, 'Complete', cancelNotification: true),
          AndroidNotificationAction(_actionSnoozeCustom, 'Snooze', cancelNotification: true),
        ],
      );
      await _notifications.zonedSchedule(
        r.id, r.title, r.body, tzDateTime,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: _matchComponentsFor(r.repeatFrequency),
        payload: jsonEncode(r.toMap()),
      );
    } catch (_) {}
  }

  Future<void> handleNotificationAction(NotificationResponse resp) async {
    final actionId = resp.actionId;
    if (actionId == null || actionId.isEmpty) return;
    try {
      final payloadData = jsonDecode(resp.payload ?? '{}') as Map<String, dynamic>;
      final id = payloadData['id'] as int?;
      if (id == null) return;

      if (actionId == _actionSnoozeCustom) {
        await _notifications.cancel(id).catchError((_) {});
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_kPendingCustomSnoozeId, id);
        _customSnoozeRequestController.add(id);
        return;
      }

      if (actionId == _actionComplete) {
        await completeReminder(id);
        await _notifications.cancel(id).catchError((_) {});
        return;
      }
    } catch (e) {
      debugPrint('Notification failed: $e');
    }
  }

  void _startWebDueReminderLoop(List<Reminder> reminders) {
    _webReminderTimer?.cancel();
    _webReminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final now = DateTime.now();
      for (final r in reminders.where((r) => r.isActive)) {
        if (_isWebDueNow(r, now)) {
          final key = '${r.id}-${now.year}${now.month}${now.day}';
          if (_webShownReminderKeys.contains(key)) continue;
          _webShownReminderKeys.add(key);
          _webDueReminderController.add(r);
        }
      }
    });
  }

  bool _isWebDueNow(Reminder r, DateTime now) {
    final sch = r.scheduledTime;
    return switch (r.repeatFrequency) {
      RepeatFrequency.none => now.difference(sch).inSeconds.abs() < 30,
      RepeatFrequency.daily => now.hour == sch.hour && now.minute == sch.minute,
      RepeatFrequency.weekly => now.weekday == sch.weekday && now.hour == sch.hour && now.minute == sch.minute,
      RepeatFrequency.monthly => now.day == sch.day && now.hour == sch.hour && now.minute == sch.minute,
      RepeatFrequency.weekdays => now.weekday < 6 && now.hour == sch.hour && now.minute == sch.minute,
      RepeatFrequency.yearly => now.month == sch.month && now.day == sch.day && now.hour == sch.hour && now.minute == sch.minute,
      RepeatFrequency.custom => _isCustomDue(r, now),
    };
  }

  bool _isCustomDue(Reminder r, DateTime now) {
    // Basic check for custom due — improved in actual scheduling logic
    return now.hour == r.scheduledTime.hour && now.minute == r.scheduledTime.minute;
  }

  DateTime? _nextScheduleTime(Reminder r) {
    final now = DateTime.now();
    var next = r.scheduledTime;
    if (!next.isBefore(now)) return next;
    if (r.repeatFrequency == RepeatFrequency.none) return null;
    while (next.isBefore(now)) {
      next = r.advancedForCompletion(now: next).scheduledTime;
    }
    return next;
  }

  DateTimeComponents? _matchComponentsFor(RepeatFrequency freq) => switch (freq) {
    RepeatFrequency.daily => DateTimeComponents.time,
    RepeatFrequency.weekly => DateTimeComponents.dayOfWeekAndTime,
    RepeatFrequency.monthly => DateTimeComponents.dayOfMonthAndTime,
    RepeatFrequency.weekdays => DateTimeComponents.time, // handled via loop/nextSchedule
    RepeatFrequency.yearly => DateTimeComponents.dateAndTime,
    _ => null,
  };
}
