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
      await _service.completeReminder(id);
      unawaited(_reload());
      _snack('Reminder marked as completed');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    return r.scheduledTime.isBefore(DateTime.now()) ? 'ongoing' : 'pending';
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
        return base.where((r) => _statusOf(r) == 'ongoing').toList();
      case _TaskFilter.completed:
        return base.where((r) => _statusOf(r) == 'completed').toList();
    }
  }

  Widget _filterChip(String label, _TaskFilter value) {
    final selected = _filter == value;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? cs.surface.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: selected ? 0.98 : 0.78),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visibleReminders = _filteredReminders();

    return Scaffold(
      backgroundColor: const Color(0xFF1F716C),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                      ),
                      const Expanded(
                        child: Text(
                          'My Remainders',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 26,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onOpenSettings,
                        icon: const Icon(Icons.settings_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _filterChip('Pending', _TaskFilter.pending),
                        _filterChip('All', _TaskFilter.all),
                        _filterChip('Ongoing', _TaskFilter.ongoing),
                        _filterChip('Completed', _TaskFilter.completed),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Row(
                        children: [
                          Text(
                            'All Task',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1F4D4B),
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
                          IconButton(
                            tooltip: widget.isDark ? 'Light mode' : 'Dark mode',
                            onPressed: widget.onToggleTheme,
                            icon: Icon(widget.isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded),
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
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                                    itemCount: visibleReminders.length,
                                    separatorBuilder: (_, __) => const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Divider(height: 4, thickness: 0.8),
                                    ),
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
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.symmetric(horizontal: 20),
                                          alignment: Alignment.centerRight,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.errorContainer,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Icon(
                                            Icons.delete_forever_rounded,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(context),
        tooltip: 'Add Reminder',
        child: const Icon(Icons.add_rounded),
        elevation: 4,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = _accent(context);
    final status = !reminder.isActive
        ? 'Completed'
        : reminder.scheduledTime.isBefore(DateTime.now())
            ? 'In Progress'
            : 'Pending';
    final statusColor = switch (status) {
      'Completed' => const Color(0xFF19A766),
      'In Progress' => const Color(0xFF7B61FF),
      _ => const Color(0xFFE58D2B),
    };
    final progress = switch (status) {
      'Completed' => 1.0,
      'In Progress' => 0.75,
      _ => 0.0,
    };
    final serial = 'SER${reminder.id.toString().padLeft(6, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 4,
                    height: 92,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                serial,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _ProgressBadge(value: progress),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF0F766E).withValues(alpha: 0.30),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 14, color: Color(0xFF0F766E)),
                                const SizedBox(width: 6),
                                Text(
                                  _fmt(reminder.scheduledTime),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF0F766E),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          reminder.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF204646),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                reminder.body.isEmpty ? 'My Department' : reminder.body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? const Color(0xFFA6CFCA)
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (reminder.isActive) ...[
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: isBusy
                                ? Padding(
                                    key: const ValueKey('busy-loader'),
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Updating...',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox(key: ValueKey('busy-loader-hidden')),
                          ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isBusy ? 0.65 : 1,
                            child: Row(
                              children: [
                                TextButton.icon(
                                  onPressed: isBusy ? null : onSnooze,
                                  icon: const Icon(Icons.snooze_rounded, size: 18),
                                  label: const Text('Snooze'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF0EA5E9),
                                    backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.10),
                                    side: BorderSide(
                                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.35),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    minimumSize: const Size(0, 40),
                                    tapTargetSize: MaterialTapTargetSize.padded,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                TextButton.icon(
                                  onPressed: isBusy ? null : onComplete,
                                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                                  label: const Text('Complete'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF19A766),
                                    backgroundColor: const Color(0xFF19A766).withValues(alpha: 0.10),
                                    side: BorderSide(
                                      color: const Color(0xFF19A766).withValues(alpha: 0.35),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    minimumSize: const Size(0, 40),
                                    tapTargetSize: MaterialTapTargetSize.padded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF75E6D4), width: 2),
      ),
      child: Center(
        child: Text(
          '$pct%',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2D6360),
              ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_none_rounded, size: 52, color: cs.primary.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 20),
              Text('No Reminders Yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.45))),
              const SizedBox(height: 8),
              Text('Tap the button below to schedule\nyour first reminder.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.3))),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_alarm_rounded),
                label: const Text('Add Reminder', style: TextStyle(fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(180, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Add reminder bottom sheet ────────────────────────────────────────────────

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
    } else {
      _repeat = SettingsService.instance.defaultRepeat;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, sc) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_alarm_rounded, color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isEditing ? 'Edit Reminder' : 'New Reminder',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        Text(_isEditing ? 'Update reminder details' : 'Fill in the details below',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
            // Form
            Expanded(
              child: SingleChildScrollView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Title *',
                          hintText: 'e.g. Team standup',
                          prefixIcon: Icon(Icons.short_text_rounded, color: cs.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: cs.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 16),
                      // Body
                      TextFormField(
                        controller: _bodyCtrl,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Description *',
                          hintText: 'What do you need to remember?',
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: Icon(Icons.notes_rounded, color: cs.primary),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: cs.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Description is required' : null,
                      ),
                      const SizedBox(height: 16),
                      // Date & Time
                      _SectionLabel(label: 'When', icon: Icons.calendar_today_rounded, color: cs.primary),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickDateTime,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: _selectedDateTime != null
                                ? cs.primary.withValues(alpha: 0.08)
                                : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _selectedDateTime != null
                                  ? cs.primary.withValues(alpha: 0.5)
                                  : cs.outline.withValues(alpha: 0.4),
                              width: _selectedDateTime != null ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.event_rounded,
                                color: _selectedDateTime != null ? cs.primary : cs.onSurface.withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedDateTime == null
                                      ? 'Tap to choose date & time'
                                      : _fmt(_selectedDateTime!),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: _selectedDateTime != null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: _selectedDateTime != null
                                        ? cs.primary
                                        : cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: cs.onSurface.withValues(alpha: 0.3)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Repeat
                      _SectionLabel(label: 'Repeat', icon: Icons.repeat_rounded, color: cs.primary),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<RepeatFrequency>(
                        value: _repeat,
                        borderRadius: BorderRadius.circular(14),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.loop_rounded, color: cs.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: cs.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        ),
                        items: RepeatFrequency.values.map((v) {
                          final labels = {
                            RepeatFrequency.none: '🔔  No repeat',
                            RepeatFrequency.daily: '📅  Daily',
                            RepeatFrequency.weekly: '📆  Weekly',
                            RepeatFrequency.monthly: '🗓  Monthly',
                          };
                          return DropdownMenuItem(value: v, child: Text(labels[v]!));
                        }).toList(),
                        onChanged: (v) => setState(() => _repeat = v ?? RepeatFrequency.none),
                      ),
                      const SizedBox(height: 32),
                      // Submit
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_isEditing
                                      ? Icons.save_rounded
                                      : Icons.alarm_add_rounded),
                                  const SizedBox(width: 10),
                                  Text(_isEditing ? 'Update Reminder' : 'Schedule Reminder'),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
