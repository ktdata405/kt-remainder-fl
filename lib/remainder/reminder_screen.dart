import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import 'reminder_model.dart';
import 'reminder_service.dart';
import 'widgets/list_view_container.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({
    super.key,
    required this.webAppUrl,
    required this.onToggleTheme,
    required this.isDark,
    required this.onSettingsChanged,
  });

  final String webAppUrl;
  final VoidCallback onToggleTheme;
  final bool isDark;
  final VoidCallback onSettingsChanged;

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> with WidgetsBindingObserver {
  final ReminderService _service = ReminderService.instance;
  StreamSubscription<Reminder>? _webDueReminderSub;
  StreamSubscription<int>? _customSnoozeSub;
  StreamSubscription<void>? _updatesSub;
  final Set<int> _busyReminderIds = <int>{};
  bool _isInitializing = true;
  bool _isReloading = false;
  bool _isServiceReady = false;
  String? _initializationError;
  String? _fetchError;
  List<Reminder> _reminders = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webDueReminderSub?.cancel();
    _customSnoozeSub?.cancel();
    _updatesSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingSnooze();
    }
  }

  Future<void> _checkPendingSnooze() async {
    final id = await _service.consumePendingCustomSnoozeRequest();
    if (id != null && mounted) {
      _showSnoozePickerForId(id);
    }
  }

  Future<void> _initialize() async {
    if (mounted) setState(() { _isInitializing = true; _initializationError = null; });
    try {
      await _service.initialize(webAppUrl: widget.webAppUrl);
      _attachWebDueReminderListener();
      _attachCustomSnoozeListener();
      _attachUpdatesListener();
      if (mounted) {
        setState(() => _isServiceReady = true);
        
        if (SettingsService.instance.useLocalStorage) {
          final local = await _service.getLocalReminders();
          setState(() => _reminders = local);
        } else {
          await _service.rescheduleActiveRemindersFromSheet();
          final remote = await _service.getLocalReminders();
          setState(() => _reminders = remote);
        }
        await _checkPendingSnooze();
      }
    } catch (e) {
      if (mounted) setState(() { _isServiceReady = false; _initializationError = e.toString(); });
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  void _attachWebDueReminderListener() {
    if (!kIsWeb || _webDueReminderSub != null) return;
    _webDueReminderSub = _service.webDueReminderStream.listen((reminder) {
      _snack('🔔 ${reminder.title} is due now');
    });
  }

  void _attachCustomSnoozeListener() {
    if (_customSnoozeSub != null) return;
    _customSnoozeSub = _service.customSnoozeRequestStream.listen((id) async {
      if (!mounted) return;
      await _showSnoozePickerForId(id);
    });
  }

  void _attachUpdatesListener() {
    if (_updatesSub != null) return;
    _updatesSub = _service.reminderUpdatesStream.listen((_) {
      if (!mounted) return;
      _reload(backgroundSync: false); 
    });
  }

  Future<void> _reload({bool backgroundSync = true}) async {
    if (!_isServiceReady) return;
    if (mounted) setState(() { _isReloading = true; _fetchError = null; });
    try {
      final localList = await _service.getLocalReminders();
      if (mounted) setState(() => _reminders = localList);

      if (backgroundSync) {
        await _service.rescheduleActiveRemindersFromSheet();
        if (mounted) {
          final updatedLocal = await _service.getLocalReminders();
          setState(() => _reminders = updatedLocal);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _fetchError = e.toString());
    } finally {
      if (mounted) setState(() => _isReloading = false);
    }
  }

  Future<void> _cancelReminder(int id) async {
    if (_busyReminderIds.contains(id)) return;
    setState(() => _busyReminderIds.add(id));
    try {
      await _service.cancelReminder(id);
      await _reload();
    } catch (e) {
      _snack('Cancel failed: $e');
    } finally {
      setState(() => _busyReminderIds.remove(id));
    }
  }

  Future<void> _completeReminder(int id) async {
    if (_busyReminderIds.contains(id)) return;
    setState(() => _busyReminderIds.add(id));
    try {
      await _service.completeReminder(id);
      await _reload();
      _snack('Reminder updated');
    } catch (e) {
      _snack('Update failed: $e');
    } finally {
      setState(() => _busyReminderIds.remove(id));
    }
  }

  Future<void> _snoozeReminder(int id, Duration by) async {
    if (_busyReminderIds.contains(id)) return;
    setState(() => _busyReminderIds.add(id));
    try {
      await _service.snoozeReminder(id, by: by);
      await _reload();
      _snack('Snoozed');
    } catch (e) {
      _snack('Snooze failed: $e');
    } finally {
      setState(() => _busyReminderIds.remove(id));
    }
  }

  Future<void> _snoozeCustom(int id) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context, 
      initialDate: now, 
      firstDate: now, 
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context, 
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 30))),
    );
    if (time == null || !mounted) return;
    final when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await _service.snoozeReminderUntil(id, when);
    await _reload();
    _snack('Custom snooze set');
  }

  Future<void> _showSnoozePickerForId(int id) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, 
              height: 4, 
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(
              'Snooze Duration', 
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _snoozeBtn(ctx, '5m', () => _snoozeReminder(id, const Duration(minutes: 5))),
                _snoozeBtn(ctx, '10m', () => _snoozeReminder(id, const Duration(minutes: 10))),
                _snoozeBtn(ctx, '15m', () => _snoozeReminder(id, const Duration(minutes: 15))),
                _snoozeBtn(ctx, '30m', () => _snoozeReminder(id, const Duration(minutes: 30))),
                _snoozeBtn(ctx, '1h', () => _snoozeReminder(id, const Duration(hours: 1))),
                _snoozeBtn(ctx, 'Tomorrow', () => _service.snoozeReminderTomorrow(id).then((_) => _reload())),
                _snoozeBtn(ctx, 'Custom', () => _snoozeCustom(id), isAccent: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _snoozeBtn(BuildContext ctx, String label, VoidCallback onTap, {bool isAccent = false}) {
    final theme = Theme.of(ctx);
    return SizedBox(
      width: 100,
      child: FilledButton.tonal(
        onPressed: () { Navigator.pop(ctx); onTap(); },
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: isAccent ? theme.colorScheme.primary : null,
          foregroundColor: isAccent ? theme.colorScheme.onPrimary : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_isServiceReady) return Scaffold(body: Center(child: Text(_initializationError ?? 'Connection Error')));

    return ListViewContainer(
      reminders: _reminders,
      isReloading: _isReloading,
      busyReminderIds: _busyReminderIds,
      fetchError: _fetchError,
      onRefresh: _reload,
      onCancel: _cancelReminder,
      onComplete: _completeReminder,
      onSnooze: (r) => _showSnoozePickerForId(r.id),
      onAdd: (r) => _service.scheduleReminder(r).then((_) => _reload()),
      onEdit: (r) => _service.scheduleReminder(r).then((_) => _reload()),
      onToggleTheme: widget.onToggleTheme,
      onOpenSettings: () {}, // Handled inside ListViewContainer
      isDark: widget.isDark,
      onSettingsChanged: widget.onSettingsChanged,
    );
  }
}
