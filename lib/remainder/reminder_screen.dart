import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../settings/settings_screen.dart';
import 'reminder_model.dart';
import 'reminder_service.dart';

// ─── Root screen (handles init state) ────────────────────────────────────────

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

class _ReminderScreenState extends State<ReminderScreen> {
  final ReminderService _service = ReminderService.instance;
  StreamSubscription<Reminder>? _webDueReminderSub;
  StreamSubscription<int>? _customSnoozeSub;
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
    _initialize();
  }

  @override
  void dispose() {
    _webDueReminderSub?.cancel();
    _customSnoozeSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ReminderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.webAppUrl != widget.webAppUrl) {
      _service.reset();
      _initialize();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(onSettingsChanged: widget.onSettingsChanged),
      ),
    );
    if (_isServiceReady) await _reload();
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _initializationError = null;
        _fetchError = null;
      });
    }
    try {
      _validateConfiguration();
      await _service.initialize(webAppUrl: widget.webAppUrl);
      _attachWebDueReminderListener();
      _attachCustomSnoozeListener();
      if (mounted) setState(() => _isServiceReady = true);
      await _reload();
      await _consumePendingCustomSnoozeRequest();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isServiceReady = false;
          _initializationError = e.toString();
        });
      }
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

  Future<void> _consumePendingCustomSnoozeRequest() async {
    final pendingId = await _service.consumePendingCustomSnoozeRequest();
    if (pendingId == null || !mounted) return;
    await _showSnoozePickerForId(pendingId);
  }

  void _validateConfiguration() {
    final url = widget.webAppUrl.trim();
    if (url.isEmpty || url.contains('PASTE_YOUR')) {
      throw const FormatException(
        'Web App URL is not set.\nDeploy scripts/apps_script.gs and paste the URL into lib/config/app_config.dart.',
      );
    }
  }

  Future<void> _reload() async {
    if (!_isServiceReady) return;
    if (mounted) setState(() { _isReloading = true; _fetchError = null; });
    try {
      final list = await _service.fetchRemindersFromSheet();
      if (mounted) setState(() => _reminders = list);
    } catch (e) {
      if (mounted) setState(() => _fetchError = e.toString());
    } finally {
      if (mounted) setState(() => _isReloading = false);
    }
  }

  void _setReminderBusy(int id, bool busy) {
    if (!mounted) return;
    setState(() {
      if (busy) {
        _busyReminderIds.add(id);
      } else {
        _busyReminderIds.remove(id);
      }
    });
  }

  void _replaceReminderLocally(int id, Reminder Function(Reminder current) mapFn) {
    if (!mounted) return;
    setState(() {
      _reminders = _reminders
          .map((r) => r.id == id ? mapFn(r) : r)
          .toList(growable: false);
    });
  }

  Future<void> _cancelReminder(int id) async {
    if (!_isServiceReady) return;
    if (_busyReminderIds.contains(id)) return;
    final previous = List<Reminder>.from(_reminders);
    _setReminderBusy(id, true);
    _replaceReminderLocally(
      id,
      (r) => Reminder(
        id: r.id,
        title: r.title,
        body: r.body,
        scheduledTime: r.scheduledTime,
        repeatFrequency: r.repeatFrequency,
        isActive: false,
      ),
    );
    try {
      await _service.cancelReminder(id);
      unawaited(_reload());
    } catch (e) {
      if (mounted) setState(() => _reminders = previous);
      _snack('Cancel failed: $e');
    } finally {
      _setReminderBusy(id, false);
    }
  }

  Future<void> _addReminder(Reminder reminder) async {
    await _service.scheduleReminder(reminder);
    await _reload();
  }

  Future<void> _editReminder(Reminder reminder) async {
    await _service.scheduleReminder(reminder);
    await _reload();
  }

  Future<void> _completeReminder(int id) async {
    if (!_isServiceReady) return;
    if (_busyReminderIds.contains(id)) return;
    final previous = List<Reminder>.from(_reminders);
    final matches = previous.where((r) => r.id == id);
    if (matches.isEmpty) return;
    final advanced = matches.first.advancedForCompletion();
    _setReminderBusy(id, true);
    _replaceReminderLocally(id, (_) => advanced);
    try {
      await _service.completeReminder(id);
      unawaited(_reload());
      _snack(advanced.isActive
          ? 'Completed! Next on ${SettingsService.instance.formatDateTime(advanced.scheduledTime)}'
          : 'Reminder marked as completed');
    } catch (e) {
      if (mounted) setState(() => _reminders = previous);
      _snack('Complete failed: $e');
    } finally {
      _setReminderBusy(id, false);
    }
  }

  Future<void> _snoozeReminder(int id, Duration by) async {
    if (!_isServiceReady) return;
    if (_busyReminderIds.contains(id)) return;
    final previous = List<Reminder>.from(_reminders);
    final target = DateTime.now().add(by);
    _setReminderBusy(id, true);
    _replaceReminderLocally(
      id,
      (r) => Reminder(
        id: r.id,
        title: r.title,
        body: r.body,
        scheduledTime: target,
        repeatFrequency: r.repeatFrequency,
        isActive: true,
      ),
    );
    try {
      await _service.snoozeReminder(id, by: by);
      unawaited(_reload());
      final mins = by.inMinutes;
      final label = mins < 60 ? '$mins minutes' : '${(mins / 60).round()} hour';
      _snack('Snoozed for $label');
    } catch (e) {
      if (mounted) setState(() => _reminders = previous);
      _snack('Snooze failed: $e');
    } finally {
      _setReminderBusy(id, false);
    }
  }

  Future<void> _snoozeTomorrow(int id) async {
    if (!_isServiceReady) return;
    if (_busyReminderIds.contains(id)) return;
    final previous = List<Reminder>.from(_reminders);
    final source = _reminders.where((r) => r.id == id).cast<Reminder?>().firstWhere(
          (r) => r != null,
          orElse: () => null,
        );
    final now = DateTime.now();
    final target = source == null
        ? DateTime(now.year, now.month, now.day + 1, now.hour, now.minute)
        : DateTime(
            now.year,
            now.month,
            now.day + 1,
            source.scheduledTime.hour,
            source.scheduledTime.minute,
          );
    _setReminderBusy(id, true);
    _replaceReminderLocally(
      id,
      (r) => Reminder(
        id: r.id,
        title: r.title,
        body: r.body,
        scheduledTime: target,
        repeatFrequency: r.repeatFrequency,
        isActive: true,
      ),
    );
    try {
      await _service.snoozeReminderTomorrow(id);
      unawaited(_reload());
      _snack('Snoozed until tomorrow');
    } catch (e) {
      if (mounted) setState(() => _reminders = previous);
      _snack('Snooze failed: $e');
    } finally {
      _setReminderBusy(id, false);
    }
  }

  Future<void> _snoozeCustom(int id) async {
    if (!_isServiceReady) return;
    if (_busyReminderIds.contains(id)) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 30))),
    );
    if (!mounted || time == null) return;
    final when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final previous = List<Reminder>.from(_reminders);
    _setReminderBusy(id, true);
    _replaceReminderLocally(
      id,
      (r) => Reminder(
        id: r.id,
        title: r.title,
        body: r.body,
        scheduledTime: when,
        repeatFrequency: r.repeatFrequency,
        isActive: true,
      ),
    );
    try {
      await _service.snoozeReminderUntil(id, when);
      unawaited(_reload());
      _snack('Snoozed to ${SettingsService.instance.formatDateTime(when)}');
    } catch (e) {
      if (mounted) setState(() => _reminders = previous);
      _snack('Custom snooze failed: $e');
    } finally {
      _setReminderBusy(id, false);
    }
  }

  Future<void> _showSnoozePicker(Reminder reminder) async {
    await _showSnoozePickerForId(reminder.id);
  }

  Future<void> _showSnoozePickerForId(int reminderId) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final options = <({IconData icon, String label, VoidCallback onTap})>[
          (icon: Icons.snooze_rounded, label: '5 minutes', onTap: () {
            Navigator.of(ctx).pop();
            _snoozeReminder(reminderId, const Duration(minutes: 5));
          }),
          (icon: Icons.snooze_rounded, label: '10 minutes', onTap: () {
            Navigator.of(ctx).pop();
            _snoozeReminder(reminderId, const Duration(minutes: 10));
          }),
          (icon: Icons.snooze_rounded, label: '30 minutes', onTap: () {
            Navigator.of(ctx).pop();
            _snoozeReminder(reminderId, const Duration(minutes: 30));
          }),
          (icon: Icons.schedule_rounded, label: '1 hour', onTap: () {
            Navigator.of(ctx).pop();
            _snoozeReminder(reminderId, const Duration(hours: 1));
          }),
          (icon: Icons.today_rounded, label: 'Tomorrow', onTap: () {
            Navigator.of(ctx).pop();
            _snoozeTomorrow(reminderId);
          }),
          (icon: Icons.edit_calendar_rounded, label: 'Custom', onTap: () {
            Navigator.of(ctx).pop();
            _snoozeCustom(reminderId);
          }),
        ];

        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = options[i];
              return ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                onTap: item.onTap,
              );
            },
          ),
        );
      },
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isServiceReady) {
      return _ErrorScreen(
        message: _initializationError ?? 'Could not connect.',
        onRetry: _initialize,
      );
    }
    return _ListScreen(
      reminders: _reminders,
      isReloading: _isReloading,
      busyReminderIds: _busyReminderIds,
      fetchError: _fetchError,
      onRefresh: _reload,
      onCancel: _cancelReminder,
      onComplete: _completeReminder,
      onSnooze: _showSnoozePicker,
      onAdd: _addReminder,
      onEdit: _editReminder,
      onToggleTheme: widget.onToggleTheme,
      onOpenSettings: _openSettings,
      isDark: widget.isDark,
    );
  }
}

// ─── Error screen ─────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 72, color: cs.error.withValues(alpha: 0.7)),
              const SizedBox(height: 20),
              Text('Connection Error', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.55))),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── List screen ──────────────────────────────────────────────────────────────

enum _TaskFilter { all, pending, ongoing, completed }

class _ListScreen extends StatefulWidget {
  const _ListScreen({
    required this.reminders,
    required this.isReloading,
    required this.busyReminderIds,
    this.fetchError,
    required this.onRefresh,
    required this.onCancel,
    required this.onComplete,
    required this.onSnooze,
    required this.onAdd,
    required this.onEdit,
    required this.onToggleTheme,
    required this.onOpenSettings,
    required this.isDark,
  });

  final List<Reminder> reminders;
  final bool isReloading;
  final Set<int> busyReminderIds;
  final String? fetchError;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int) onCancel;
  final Future<void> Function(int) onComplete;
  final Future<void> Function(Reminder) onSnooze;
  final Future<void> Function(Reminder) onAdd;
  final Future<void> Function(Reminder) onEdit;
  final VoidCallback onToggleTheme;
  final Future<void> Function() onOpenSettings;
  final bool isDark;

  @override
  State<_ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<_ListScreen> {
  _TaskFilter _filter = _TaskFilter.pending;
  int _currentIndex = 0;

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AddReminderSheet(onAdd: widget.onAdd),
    );
  }

  void _openEditSheet(BuildContext context, Reminder reminder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AddReminderSheet(
        onAdd: widget.onEdit,
        initialReminder: reminder,
      ),
    );
  }

  Future<bool> _confirmCancel(BuildContext context, Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel reminder?'),
        content: Text(
          'Do you want to cancel "${reminder.title}"?\nThis will mark it as cancelled in your sheet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  String _statusOf(Reminder r) {
    if (!r.isActive) return 'completed';
    return r.scheduledTime.isBefore(DateTime.now()) ? 'overdue' : 'pending';
  }

  List<Reminder> _filteredReminders() {
    final showCancelled = SettingsService.instance.showCancelledReminders;
    final base = showCancelled
        ? widget.reminders
        : widget.reminders.where((r) => r.isActive).toList();
    switch (_filter) {
      case _TaskFilter.all:
        return base;
      case _TaskFilter.pending:
        return base.where((r) => _statusOf(r) == 'pending').toList();
      case _TaskFilter.ongoing:
        return base.where((r) => _statusOf(r) == 'overdue').toList();
      case _TaskFilter.completed:
        return base.where((r) => _statusOf(r) == 'completed').toList();
    }
  }


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visibleReminders = _filteredReminders();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remainders',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        '${visibleReminders.length} tasks for today',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: widget.onToggleTheme,
                    icon: Icon(widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            _filter == _TaskFilter.pending
                                ? 'Upcoming'
                                : _filter == _TaskFilter.ongoing
                                    ? 'Overdue'
                                    : _filter == _TaskFilter.completed
                                        ? 'Completed'
                                        : 'All Tasks',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Refresh',
                            onPressed: widget.isReloading ? null : widget.onRefresh,
                            icon: widget.isReloading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: widget.onRefresh,
                        child: widget.fetchError != null
                            ? _FetchErrorState(error: widget.fetchError!, onRetry: widget.onRefresh)
                            : visibleReminders.isEmpty
                                ? _EmptyState(onAdd: () => _openAddSheet(context))
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                                    itemCount: visibleReminders.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                                    itemBuilder: (context, i) {
                                      final reminder = visibleReminders[i];
                                      final isBusy = widget.busyReminderIds.contains(reminder.id);
                                      return Dismissible(
                                        key: ValueKey('reminder-${reminder.id}-${reminder.isActive}'),
                                        direction: reminder.isActive && !isBusy
                                            ? DismissDirection.endToStart
                                            : DismissDirection.none,
                                        confirmDismiss: (_) => _confirmCancel(context, reminder),
                                        onDismissed: (_) => widget.onCancel(reminder.id),
                                        background: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 20),
                                          alignment: Alignment.centerRight,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.errorContainer,
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            color: Theme.of(context).colorScheme.error,
                                          ),
                                        ),
                                        child: _ReminderCard(
                                          reminder: reminder,
                                          isBusy: isBusy,
                                          onTap: reminder.isActive
                                              ? () => _openEditSheet(context, reminder)
                                              : null,
                                          onComplete: reminder.isActive && !isBusy
                                              ? () => widget.onComplete(reminder.id)
                                              : null,
                                          onSnooze: reminder.isActive && !isBusy
                                              ? () => widget.onSnooze(reminder)
                                              : null,
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navItem(Icons.calendar_today_rounded, 0, _TaskFilter.pending),
            _navItem(Icons.grid_view_rounded, 1, _TaskFilter.all),
            _navItem(Icons.add_rounded, 2, null, isFab: true),
            _navItem(Icons.alarm_on_rounded, 3, _TaskFilter.ongoing),
            _navItem(Icons.settings_outlined, 4, null),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index, _TaskFilter? filter, {bool isFab = false}) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _currentIndex == index;

    if (isFab) {
      return GestureDetector(
        onTap: () => _openAddSheet(context),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: cs.onPrimary, size: 28),
        ),
      );
    }

    return InkWell(
      onTap: () {
        if (index == 4) {
          widget.onOpenSettings();
        } else if (filter != null) {
          setState(() {
            _currentIndex = index;
            _filter = filter;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(
          icon,
          color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.35),
          size: 26,
        ),
      ),
    );
  }
}

// ─── Reminder card ────────────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.isBusy,
    this.onTap,
    this.onComplete,
    this.onSnooze,
  });

  final Reminder reminder;
  final bool isBusy;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onSnooze;

  Color _accent(BuildContext context) {
    if (!reminder.isActive) return Colors.grey;
    switch (reminder.repeatFrequency) {
      case RepeatFrequency.none:
        return Theme.of(context).colorScheme.primary;
      case RepeatFrequency.daily:
        return const Color(0xFF22C55E);
      case RepeatFrequency.weekly:
        return const Color(0xFF8B5CF6);
      case RepeatFrequency.monthly:
        return const Color(0xFFF97316);
    }
  }

  String _fmt(DateTime dt) => SettingsService.instance.formatDateTime(dt);

  IconData _repeatIcon(RepeatFrequency f) => switch (f) {
        RepeatFrequency.daily => Icons.today_rounded,
        RepeatFrequency.weekly => Icons.date_range_rounded,
        RepeatFrequency.monthly => Icons.calendar_month_rounded,
        _ => Icons.notifications_none_rounded,
      };

  String _repeatLabel(RepeatFrequency f) => switch (f) {
        RepeatFrequency.daily => 'Daily',
        RepeatFrequency.weekly => 'Weekly',
        RepeatFrequency.monthly => 'Monthly',
        _ => '',
      };


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = _accent(context);
    
    final isOverdue = reminder.isActive && reminder.scheduledTime.isBefore(DateTime.now());
    final isCompleted = !reminder.isActive;

    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = cs.onSurface;
    final subtitleColor = cs.onSurface.withValues(alpha: 0.5);

    final priorityColor = reminder.priority == ReminderPriority.high 
      ? Colors.red 
      : reminder.priority == ReminderPriority.medium 
        ? Colors.orange 
        : Colors.blue;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (reminder.isActive)
                  SizedBox(
                    width: 48,
                    child: isBusy
                        ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                        : Radio<bool>(
                            value: true,
                            groupValue: false,
                            onChanged: (_) => onComplete?.call(),
                            activeColor: const Color(0xFF10B981),
                          ),
                  )
                else
                  const SizedBox(
                    width: 48,
                    child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                  ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reminder.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                                fontSize: 14, // Reduced title size
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 6, // Slightly smaller priority dot
                            height: 6,
                            decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOverdue ? Icons.alarm_rounded : Icons.calendar_today_rounded,
                                size: 14,
                                color: isOverdue ? const Color(0xFFEF4444) : accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _fmt(reminder.scheduledTime),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isOverdue ? const Color(0xFFEF4444) : subtitleColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          if (reminder.repeatFrequency != RepeatFrequency.none)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_repeatIcon(reminder.repeatFrequency), size: 12, color: accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    _repeatLabel(reminder.repeatFrequency),
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (reminder.isActive) ...[
                  const SizedBox(width: 8),
                  if (!isBusy)
                    TextButton.icon(
                      onPressed: onSnooze,
                      icon: const Icon(Icons.snooze_rounded, size: 16),
                      label: const Text('Snooze', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 36),
                        backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Fetch error state ────────────────────────────────────────────────────────

class _FetchErrorState extends StatelessWidget {
  const _FetchErrorState({required this.error, required this.onRetry});
  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_sync_rounded, size: 64, color: cs.error.withValues(alpha: 0.7)),
                  const SizedBox(height: 16),
                  Text('Could not load reminders',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      error,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onErrorContainer),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(160, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(32),
                ),
                padding: const EdgeInsets.all(24),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EmptyIconRow(color: Color(0xFFF97316)),
                    _EmptyIconRow(color: Color(0xFF3B82F6)),
                    _EmptyIconRow(color: Color(0xFF22C55E)),
                    _EmptyIconRow(color: Color(0xFFA855F7)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'No Reminders Yet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: cs.onSurface,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your schedule looks clear.\nTap below to add your first task.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Reminder'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyIconRow extends StatelessWidget {
  const _EmptyIconRow({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddReminderSheet extends StatefulWidget {
  const _AddReminderSheet({required this.onAdd, this.initialReminder});
  final Future<void> Function(Reminder) onAdd;
  final Reminder? initialReminder;

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  DateTime? _selectedDateTime;
  late RepeatFrequency _repeat;
  late ReminderPriority _priority;
  bool _submitting = false;

  bool get _isEditing => widget.initialReminder != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialReminder;
    if (initial != null) {
      _titleCtrl.text = initial.title;
      _bodyCtrl.text = initial.body;
      _selectedDateTime = initial.scheduledTime;
      _repeat = initial.repeatFrequency;
      _priority = initial.priority;
    } else {
      _repeat = SettingsService.instance.defaultRepeat;
      _priority = ReminderPriority.medium;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime dt) =>
      SettingsService.instance.formatDateTime(dt);

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final init = _selectedDateTime ?? now.add(const Duration(minutes: 30));
    final date = await showDatePicker(
      context: context, initialDate: init,
      firstDate: now, lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context, initialTime: TimeOfDay.fromDateTime(init),
    );
    if (time == null || !mounted) return;
    setState(() {
      _selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedDateTime == null) {
      _snack('Please select a date and time.');
      return;
    }
    if (_selectedDateTime!.isBefore(DateTime.now()) && _repeat == RepeatFrequency.none) {
      _snack('Please select a future date and time.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onAdd(Reminder(
        id: widget.initialReminder?.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        scheduledTime: _selectedDateTime!,
        repeatFrequency: _repeat,
        isActive: widget.initialReminder?.isActive ?? true,
        priority: _priority,
      ));
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(_isEditing ? 'Reminder updated!' : 'Reminder scheduled!'),
            ]),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isEditing ? 'Edit Task' : 'New Task',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'What needs to be done?',
                        hintText: 'e.g. Weekly Grocery Shopping',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bodyCtrl,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Additional Notes',
                        hintText: 'Add some context...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDateTime,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cs.primary.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 18, color: cs.primary),
                                  const SizedBox(width: 12),
                                  Text(
                                    _selectedDateTime == null ? 'Set Time' : _fmt(_selectedDateTime!),
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DropdownButton<RepeatFrequency>(
                            value: _repeat,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            items: RepeatFrequency.values.map((v) {
                              final label = v == RepeatFrequency.none ? 'Once' : v.name.capitalize();
                              return DropdownMenuItem(value: v, child: Text(label, style: const TextStyle(fontSize: 14)));
                            }).toList(),
                            onChanged: (v) => setState(() => _repeat = v ?? RepeatFrequency.none),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel(label: 'Priority', icon: Icons.flag_rounded, color: cs.primary),
                    const SizedBox(height: 8),
                    Row(
                      children: ReminderPriority.values.map((p) {
                        final isSel = _priority == p;
                        final color = p == ReminderPriority.high 
                          ? Colors.red 
                          : p == ReminderPriority.medium 
                            ? Colors.orange 
                            : Colors.blue;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => setState(() => _priority = p),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel ? color.withValues(alpha: 0.15) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel ? color : cs.outline.withValues(alpha: 0.2),
                                    width: isSel ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  p.name.capitalize(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSel ? color : cs.onSurface.withValues(alpha: 0.5),
                                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isEditing ? 'Save Changes' : 'Create Task', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
