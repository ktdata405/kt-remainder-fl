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

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<Reminder> _webDueReminderController =
      StreamController<Reminder>.broadcast();
  final StreamController<int> _customSnoozeRequestController =
      StreamController<int>.broadcast();

  String _webAppUrl = '';
  bool _isInitialized = false;
  Timer? _webReminderTimer;
  final Set<String> _webShownReminderKeys = <String>{};

  Stream<Reminder> get webDueReminderStream => _webDueReminderController.stream;
  Stream<int> get customSnoozeRequestStream => _customSnoozeRequestController.stream;

  // ─── Public API ──────────────────────────────────────────────────────────

  /// Resets initialization state so [initialize] can be called again.
  /// Use this after changing the Web App URL in settings.
  void reset() {
    _isInitialized = false;
    _webAppUrl = '';
    _webReminderTimer?.cancel();
    _webReminderTimer = null;
    _webShownReminderKeys.clear();
  }

  Future<void> initialize({required String webAppUrl}) async {
    if (_isInitialized) return;

    if (webAppUrl.trim().isEmpty || webAppUrl.contains('PASTE_YOUR')) {
      throw const FormatException(
        'Web App URL is not set. Deploy scripts/apps_script.gs and '
        'paste the URL into lib/config/app_config.dart.',
      );
    }

    _webAppUrl = webAppUrl.trim();
    await _configureLocalTimezone();

    // Local notifications — Android only (not supported on web).
    if (!kIsWeb) {
      try {
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInit);
        await _notifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: handleNotificationAction,
          onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
        );
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.requestNotificationsPermission();
        await androidPlugin?.requestExactAlarmsPermission();
        await androidPlugin?.createNotificationChannel(_channel);
      } catch (_) {
        // Notifications not available on this platform — continue.
      }
    }

    _isInitialized = true;

    // Reschedule notifications best-effort — don't block or fail init if sheet
    // is unreachable or data is malformed.
    rescheduleActiveRemindersFromSheet().catchError((e) {
      debugPrint('rescheduleActiveRemindersFromSheet skipped: $e');
    });
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    _assertInitialized();
    if (reminder.scheduledTime.isBefore(DateTime.now()) &&
        reminder.repeatFrequency == RepeatFrequency.none) {
      throw ArgumentError('Cannot schedule a one-time reminder in the past.');
    }
    final active = Reminder(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      scheduledTime: reminder.scheduledTime,
      repeatFrequency: reminder.repeatFrequency,
      isActive: true,
    );
    await _upsertRemote(active);
    await _scheduleNotification(active);
  }

  Future<void> completeReminder(int id) async {
    await cancelReminder(id);
  }

  Future<void> snoozeReminder(int id, {Duration by = const Duration(minutes: 10)}) async {
    _assertInitialized();
    final reminders = await fetchRemindersFromSheet();
    Reminder? existing;
    for (final r in reminders) {
      if (r.id == id) {
        existing = r;
        break;
      }
    }
    if (existing == null) {
      throw StateError('Reminder not found for snooze: $id');
    }
    final snoozed = Reminder(
      id: existing.id,
      title: existing.title,
      body: existing.body,
      scheduledTime: DateTime.now().add(by),
      repeatFrequency: existing.repeatFrequency,
      isActive: true,
    );
    await _upsertRemote(snoozed);
    await _scheduleNotification(snoozed);
  }

  Future<void> snoozeReminderTomorrow(int id) async {
    _assertInitialized();
    final source = await _findReminderById(id);
    if (source == null) {
      throw StateError('Reminder not found for snooze: $id');
    }
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day + 1,
      source.scheduledTime.hour,
      source.scheduledTime.minute,
    );
    await _applySnooze(source, tomorrow);
  }

  Future<void> snoozeReminderUntil(int id, DateTime when) async {
    _assertInitialized();
    final source = await _findReminderById(id);
    if (source == null) {
      throw StateError('Reminder not found for snooze: $id');
    }
    await _applySnooze(source, when);
  }

  Future<int?> consumePendingCustomSnoozeRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_kPendingCustomSnoozeId);
    if (id != null) {
      await prefs.remove(_kPendingCustomSnoozeId);
    }
    return id;
  }

  Future<List<Reminder>> fetchRemindersFromSheet() async {
    _assertInitialized();
    final uri = Uri.parse(_webAppUrl)
        .replace(queryParameters: {'action': 'fetch'});
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError(
          'Fetch failed (HTTP ${response.statusCode}): ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded.containsKey('error')) {
      throw StateError('Fetch error from Apps Script: ${decoded['error']}');
    }
    final rows = (decoded as List<dynamic>).cast<Map<String, dynamic>>();
    final reminders = rows.map(_mapToReminder).whereType<Reminder>().toList();
    reminders.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return reminders;
  }

  Future<void> cancelReminder(int id) async {
    _assertInitialized();
    if (!kIsWeb) {
      await _notifications.cancel(id).catchError((_) {});
    }
    await _cancelRemoteById(id);
  }

  Future<void> _cancelRemoteById(int id) async {
    await _ensureWebUrlLoaded();
    if (_webAppUrl.trim().isEmpty || _webAppUrl.contains('PASTE_YOUR')) {
      throw StateError('Web App URL is not configured.');
    }
    final uri = Uri.parse(_webAppUrl).replace(
        queryParameters: {'action': 'cancel', 'id': id.toString()});
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError(
          'Cancel failed (HTTP ${response.statusCode}): ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded.containsKey('error')) {
      throw StateError('Cancel error from Apps Script: ${decoded['error']}');
    }
  }

  Future<void> rescheduleActiveRemindersFromSheet() async {
    _assertInitialized();
    if (!kIsWeb) {
      await _notifications.cancelAll().catchError((_) {});
    }
    final reminders = await fetchRemindersFromSheet();
    if (kIsWeb) {
      _startWebDueReminderLoop(reminders);
    }
    for (final reminder in reminders.where((r) => r.isActive)) {
      await _scheduleNotification(reminder);
    }
  }
  Future<void> _configureLocalTimezone() async {
    tz.initializeTimeZones();
    if (kIsWeb) return;
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (e) {
      debugPrint('Could not set local timezone. Falling back to UTC: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }


  // ─── Private helpers ──────────────────────────────────────────────────────

  void _assertInitialized() {
    if (!_isInitialized) {
      throw StateError(
          'ReminderService is not initialized. Call initialize() first.');
    }
  }

  Future<void> _upsertRemote(Reminder reminder) async {
    final data = jsonEncode({
      'id': reminder.id,
      'title': reminder.title,
      'body': reminder.body,
      'scheduledTime': reminder.scheduledTime.toIso8601String(),
      'repeatFrequency': reminder.repeatFrequency.name,
      'isActive': reminder.isActive,
    });
    final uri = Uri.parse(_webAppUrl)
        .replace(queryParameters: {'action': 'upsert', 'data': data});
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError(
          'Upsert failed (HTTP ${response.statusCode}): ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded.containsKey('error')) {
      throw StateError('Upsert error from Apps Script: ${decoded['error']}');
    }
  }

  Future<void> _upsertRemoteMap(Map<String, dynamic> data) async {
    await _ensureWebUrlLoaded();
    if (_webAppUrl.trim().isEmpty || _webAppUrl.contains('PASTE_YOUR')) return;
    final json = jsonEncode(data);
    final uri = Uri.parse(_webAppUrl)
        .replace(queryParameters: {'action': 'upsert', 'data': json});
    await http.get(uri).timeout(const Duration(seconds: 10));
  }

  Future<Reminder?> _findReminderById(int id) async {
    final reminders = await fetchRemindersFromSheet();
    for (final r in reminders) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> _applySnooze(Reminder source, DateTime when) async {
    final target = Reminder(
      id: source.id,
      title: source.title,
      body: source.body,
      scheduledTime: when,
      repeatFrequency: source.repeatFrequency,
      isActive: true,
    );
    await _upsertRemote(target);
    await _scheduleNotification(target);
  }

  Future<void> _ensureWebUrlLoaded() async {
    if (_webAppUrl.trim().isNotEmpty && !_webAppUrl.contains('PASTE_YOUR')) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final persisted = (prefs.getString('web_app_url') ?? '').trim();
    if (persisted.isNotEmpty && !persisted.contains('PASTE_YOUR')) {
      _webAppUrl = persisted;
      return;
    }
    if (kWebAppUrl.trim().isNotEmpty && !kWebAppUrl.contains('PASTE_YOUR')) {
      _webAppUrl = kWebAppUrl.trim();
    }
  }

  Reminder? _mapToReminder(Map<String, dynamic> row) {
    try {
      final id = row['id'];
      final title = row['title']?.toString() ?? '';
      final body = row['body']?.toString() ?? '';
      final rawTime = row['scheduledTime']?.toString() ?? '';

      if (id == null || rawTime.isEmpty) {
        debugPrint('Skipping reminder row with missing id or scheduledTime: $row');
        return null;
      }

      final scheduledTime = _parseDateTime(rawTime);
      if (scheduledTime == null) {
        debugPrint('Skipping reminder row — unrecognized date format "$rawTime": $row');
        return null;
      }
      final localScheduledTime = scheduledTime.isUtc
          ? scheduledTime.toLocal()
          : scheduledTime;

      return Reminder(
        id: (id is num) ? id.toInt() : int.parse(id.toString()),
        title: title,
        body: body,
        scheduledTime: localScheduledTime,
        repeatFrequency: RepeatFrequency.values.firstWhere(
          (v) => v.name == (row['repeatFrequency']?.toString() ?? 'none'),
          orElse: () => RepeatFrequency.none,
        ),
        isActive: _parseBool(row['isActive']),
      );
    } catch (e) {
      debugPrint('Skipping malformed reminder row: $row\nError: $e');
      return null;
    }
  }

  /// Tries ISO 8601 first, then common fallback formats.
  DateTime? _parseDateTime(String raw) {
    // ISO 8601 (standard format used by this app)
    try { return DateTime.parse(raw); } catch (_) {}
    // Common manual entry formats
    final formats = [
      RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+(\d{1,2}):(\d{2})(?:\s*(AM|PM))?)?$', caseSensitive: false),
      RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})(?:\s+(\d{1,2}):(\d{2})(?:\s*(AM|PM))?)?$', caseSensitive: false),
    ];
    for (final re in formats) {
      final m = re.firstMatch(raw.trim());
      if (m != null) {
        final month = int.parse(m.group(1)!);
        final day   = int.parse(m.group(2)!);
        final year  = int.parse(m.group(3)!);
        var hour    = m.group(4) != null ? int.parse(m.group(4)!) : 0;
        final min   = m.group(5) != null ? int.parse(m.group(5)!) : 0;
        final ampm  = m.group(6)?.toUpperCase();
        if (ampm == 'PM' && hour < 12) hour += 12;
        if (ampm == 'AM' && hour == 12) hour = 0;
        return DateTime(year, month, day, hour, min);
      }
    }
    return null;
  }

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }

  Future<void> _scheduleNotification(Reminder reminder) async {
    if (kIsWeb) return; // Web uses foreground due-reminder loop instead.
    if (!reminder.isActive) return;
    final nextTime = _nextScheduleTime(reminder);
    if (nextTime == null) return;
    try {
      final tzDateTime = tz.TZDateTime.from(nextTime, tz.local);
      const androidDetails = AndroidNotificationDetails(
        'reminders_channel',
        'Reminders',
        channelDescription: 'Reminder notifications',
        importance: Importance.max,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            _actionComplete,
            'Complete',
            cancelNotification: true,
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            _actionSnooze5,
            'Snooze 5m',
            cancelNotification: true,
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            _actionSnooze10,
            'Snooze 10m',
            cancelNotification: true,
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            _actionSnooze30,
            'Snooze 30m',
            cancelNotification: true,
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            _actionSnooze60,
            'Snooze 1h',
            cancelNotification: true,
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            _actionSnoozeTomorrow,
            'Tomorrow',
            cancelNotification: true,
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            _actionSnoozeCustom,
            'Custom',
            cancelNotification: true,
            showsUserInterface: true,
          ),
        ],
      );
      final payload = jsonEncode({
        'id': reminder.id,
        'title': reminder.title,
        'body': reminder.body,
        'scheduledTime': reminder.scheduledTime.toIso8601String(),
        'repeatFrequency': reminder.repeatFrequency.name,
      });
      try {
        await _notifications.zonedSchedule(
          reminder.id,
          reminder.title,
          reminder.body,
          tzDateTime,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: _matchComponentsFor(reminder.repeatFrequency),
          payload: payload,
        );
      } catch (_) {
        // Fallback for devices that deny exact alarms.
        await _notifications.zonedSchedule(
          reminder.id,
          reminder.title,
          reminder.body,
          tzDateTime,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: _matchComponentsFor(reminder.repeatFrequency),
          payload: payload,
        );
      }
    } catch (_) {
      // Notifications not supported on this platform — silently skip.
    }
  }

  Future<void> handleNotificationAction(NotificationResponse response) async {
    final actionId = response.actionId;
    if (actionId == null || actionId.isEmpty) return;

    try {
      await _ensureWebUrlLoaded();
      if (_webAppUrl.trim().isEmpty || _webAppUrl.contains('PASTE_YOUR')) return;

      final payloadData = _decodePayload(response.payload);
      final id = _payloadId(payloadData['id']);
      if (id == null) return;

      if (actionId == _actionComplete) {
        await _cancelRemoteById(id);
        await _notifications.cancel(id).catchError((_) {});
        return;
      }

      if (actionId == _actionSnoozeCustom) {
        await _notifications.cancel(id).catchError((_) {});
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_kPendingCustomSnoozeId, id);
        if (!_customSnoozeRequestController.isClosed) {
          _customSnoozeRequestController.add(id);
        }
        return;
      }

      if ({_actionSnooze5, _actionSnooze10, _actionSnooze30, _actionSnooze60, _actionSnoozeTomorrow}
          .contains(actionId)) {
        await _notifications.cancel(id).catchError((_) {});
        final scheduledBase = _parseDateTime(
          (payloadData['scheduledTime'] ?? DateTime.now().toIso8601String())
              .toString(),
        ) ?? DateTime.now();

        final now = DateTime.now();
        DateTime target;
        switch (actionId) {
          case _actionSnooze5:
            target = now.add(const Duration(minutes: 5));
            break;
          case _actionSnooze10:
            target = now.add(const Duration(minutes: 10));
            break;
          case _actionSnooze30:
            target = now.add(const Duration(minutes: 30));
            break;
          case _actionSnooze60:
            target = now.add(const Duration(hours: 1));
            break;
          case _actionSnoozeTomorrow:
            target = DateTime(
              now.year,
              now.month,
              now.day + 1,
              scheduledBase.hour,
              scheduledBase.minute,
            );
            break;
          default:
            return;
        }

        final updated = {
          'id': id,
          'title': payloadData['title'] ?? 'Reminder',
          'body': payloadData['body'] ?? '',
          'scheduledTime': target.toIso8601String(),
          'repeatFrequency': payloadData['repeatFrequency'] ?? 'none',
          'isActive': true,
        };
        await _upsertRemoteMap(updated);

        if (!kIsWeb) {
          final reminder = Reminder(
            id: id,
            title: (payloadData['title'] ?? 'Reminder').toString(),
            body: (payloadData['body'] ?? '').toString(),
            scheduledTime: target,
            repeatFrequency: RepeatFrequency.values.firstWhere(
              (v) => v.name == (payloadData['repeatFrequency'] ?? 'none').toString(),
              orElse: () => RepeatFrequency.none,
            ),
            isActive: true,
          );
          await _scheduleNotification(reminder);
        }
      }
    } catch (e) {
      debugPrint('Notification action handling failed: $e');
    }
  }

  Map<String, dynamic> _decodePayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      final id = int.tryParse(payload.trim());
      if (id != null) {
        return {'id': id};
      }
    }
    return {};
  }

  int? _payloadId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  void _startWebDueReminderLoop(List<Reminder> reminders) {
    _webReminderTimer?.cancel();
    _webShownReminderKeys.clear();
    _webReminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final now = DateTime.now();
      for (final reminder in reminders.where((r) => r.isActive)) {
        if (_isWebDueNow(reminder, now)) {
          final key = _webOccurrenceKey(reminder, now);
          if (_webShownReminderKeys.contains(key)) continue;
          _webShownReminderKeys.add(key);
          if (!_webDueReminderController.isClosed) {
            _webDueReminderController.add(reminder);
          }
        }
      }
    });
  }

  bool _isWebDueNow(Reminder reminder, DateTime now) {
    final scheduled = reminder.scheduledTime;
    switch (reminder.repeatFrequency) {
      case RepeatFrequency.none:
        final diff = now.difference(scheduled);
        return !diff.isNegative && diff <= const Duration(seconds: 59);
      case RepeatFrequency.daily:
        return now.hour == scheduled.hour && now.minute == scheduled.minute;
      case RepeatFrequency.weekly:
        return now.weekday == scheduled.weekday &&
            now.hour == scheduled.hour &&
            now.minute == scheduled.minute;
      case RepeatFrequency.monthly:
        return now.day == scheduled.day &&
            now.hour == scheduled.hour &&
            now.minute == scheduled.minute;
    }
  }

  String _webOccurrenceKey(Reminder reminder, DateTime now) {
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${reminder.id}-$y$m$d';
  }

  DateTime? _nextScheduleTime(Reminder reminder) {
    final now = DateTime.now();
    final candidate = reminder.scheduledTime;
    if (!candidate.isBefore(now)) return candidate;
    switch (reminder.repeatFrequency) {
      case RepeatFrequency.none:
        return null;
      case RepeatFrequency.daily:
        var next = candidate;
        while (next.isBefore(now)) {
          next = next.add(const Duration(days: 1));
        }
        return next;
      case RepeatFrequency.weekly:
        var next = candidate;
        while (next.isBefore(now)) {
          next = next.add(const Duration(days: 7));
        }
        return next;
      case RepeatFrequency.monthly:
        var next = candidate;
        while (next.isBefore(now)) {
          next = DateTime(
              next.year, next.month + 1, next.day, next.hour, next.minute);
        }
        return next;
    }
  }

  DateTimeComponents? _matchComponentsFor(RepeatFrequency freq) {
    switch (freq) {
      case RepeatFrequency.none:
        return null;
      case RepeatFrequency.daily:
        return DateTimeComponents.time;
      case RepeatFrequency.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case RepeatFrequency.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
    }
  }
}
