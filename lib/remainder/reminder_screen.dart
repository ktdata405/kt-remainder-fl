import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../settings/settings_screen.dart';
import 'reminder_model.dart';
import 'reminder_service.dart';

// ─── Root screen ─────────────────────────────────────────────────────────────

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

  Future<void> _initialize() async {
    if (mounted) setState(() { _isInitializing = true; _initializationError = null; });
    try {
      await _service.initialize(webAppUrl: widget.webAppUrl);
      _attachWebDueReminderListener();
      _attachCustomSnoozeListener();
      if (mounted) setState(() => _isServiceReady = true);
      await _reload();
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
    final date = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: DateTime(now.year + 5));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 30))));
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Snooze Duration', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
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
    return SizedBox(
      width: 100,
      child: FilledButton.tonal(
        onPressed: () { Navigator.pop(ctx); onTap(); },
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: isAccent ? Theme.of(ctx).colorScheme.primary : null,
          foregroundColor: isAccent ? Theme.of(ctx).colorScheme.onPrimary : null,
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

    return _ListScreen(
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
      onOpenSettings: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(onSettingsChanged: widget.onSettingsChanged))).then((_) => _reload()),
      isDark: widget.isDark,
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
  final VoidCallback onOpenSettings;
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
      backgroundColor: Colors.transparent,
      builder: (_) => _AddReminderSheet(onAdd: widget.onAdd),
    );
  }

  void _openEditSheet(BuildContext context, Reminder r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddReminderSheet(onAdd: widget.onEdit, initialReminder: r),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showAll = SettingsService.instance.showCancelledReminders;
    
    var visible = widget.reminders;
    if (!showAll) {
      visible = visible.where((r) => r.isActive).toList();
    }
    
    if (_filter == _TaskFilter.ongoing) {
      visible = visible.where((r) => r.isActive && r.scheduledTime.isBefore(DateTime.now())).toList();
    } else if (_filter == _TaskFilter.completed) {
      visible = visible.where((r) => !r.isActive).toList();
    }

    final today = DateTime.now();
    final todayTasks = visible.where((r) => r.isActive && r.scheduledTime.year == today.year && r.scheduledTime.month == today.month && r.scheduledTime.day == today.day).toList();
    final upcomingTasks = visible.where((r) => r.isActive && r.scheduledTime.isAfter(DateTime(today.year, today.month, today.day, 23, 59))).toList();

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
                      Text('Remainder', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
                      Text('${visible.length} tasks', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                  const Spacer(),
                  IconButton.filledTonal(onPressed: widget.onToggleTheme, icon: Icon(widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded)),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: widget.fetchError != null 
                  ? _FetchErrorState(error: widget.fetchError!, onRetry: widget.onRefresh)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      children: [
                        if (_filter == _TaskFilter.pending) ...[
                          if (todayTasks.isNotEmpty) ...[
                            const _SectionHeader(title: 'Today Remainders'),
                            ...todayTasks.map((r) => _reminderItem(r)),
                            const SizedBox(height: 24),
                          ],
                          if (upcomingTasks.isNotEmpty) ...[
                            const _SectionHeader(title: 'Upcoming Remainders'),
                            ...upcomingTasks.map((r) => _reminderItem(r)),
                          ],
                          if (todayTasks.isEmpty && upcomingTasks.isEmpty) _EmptyState(onAdd: () => _openAddSheet(context)),
                        ] else ...[
                          if (visible.isEmpty) _EmptyState(onAdd: () => _openAddSheet(context)),
                          ...visible.map((r) => _reminderItem(r)),
                        ],
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

  Widget _reminderItem(Reminder r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _ReminderCard(
        reminder: r,
        isBusy: widget.busyReminderIds.contains(r.id),
        onTap: () => _openEditSheet(context, r),
        onComplete: () => widget.onComplete(r.id),
        onSnooze: () => widget.onSnooze(r),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: cs.surface, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))]),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        height: 72,
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(36), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0))),
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
        child: Container(width: 52, height: 52, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]), child: Icon(icon, color: cs.onPrimary, size: 28)),
      );
    }
    return InkWell(
      onTap: () {
        if (index == 4) { widget.onOpenSettings(); }
        else if (filter != null) { setState(() { _currentIndex = index; _filter = filter; }); }
      },
      child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Icon(icon, color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.35), size: 26)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Theme.of(context).colorScheme.primary, letterSpacing: 1.2)),
    );
  }
}

// ─── Reminder card ────────────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder, required this.isBusy, this.onTap, this.onComplete, this.onSnooze});
  final Reminder reminder;
  final bool isBusy;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onSnooze;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final isOverdue = reminder.isActive && reminder.scheduledTime.isBefore(DateTime.now());
    final isCompleted = !reminder.isActive;
    final priorityColor = reminder.priority == ReminderPriority.high ? Colors.red : reminder.priority == ReminderPriority.medium ? Colors.orange : Colors.blue;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: reminder.isActive 
                    ? Radio<bool>(value: true, groupValue: false, onChanged: (_) => onComplete?.call(), activeColor: const Color(0xFF10B981))
                    : const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(decoration: isCompleted ? TextDecoration.lineThrough : null),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOverdue ? Colors.red.withValues(alpha: 0.1) : cs.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isOverdue ? Colors.red.withValues(alpha: 0.2) : cs.primary.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time_filled_rounded, size: 12, color: isOverdue ? Colors.red : cs.primary),
                            const SizedBox(width: 6),
                            Text(
                              SettingsService.instance.formatDateTime(reminder.scheduledTime),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: isOverdue ? Colors.red : cs.primary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (reminder.repeatFrequency != RepeatFrequency.none) ...[
                            Icon(_repeatIcon(reminder.repeatFrequency), size: 10, color: cs.primary.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(_repeatLabel(reminder), style: theme.textTheme.bodySmall?.copyWith(fontSize: 9, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: priorityColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(reminder.priority.name.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: priorityColor)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (reminder.isActive && !isBusy)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilledButton.tonal(
                      onPressed: onSnooze,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.snooze_rounded, size: 14),
                          SizedBox(width: 4),
                          Text('Snooze', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _repeatIcon(RepeatFrequency f) => switch (f) {
    RepeatFrequency.daily => Icons.today_rounded,
    RepeatFrequency.weekly => Icons.date_range_rounded,
    RepeatFrequency.monthly => Icons.calendar_month_rounded,
    RepeatFrequency.weekdays => Icons.work_outline_rounded,
    RepeatFrequency.yearly => Icons.event_available_rounded,
    RepeatFrequency.custom => Icons.tune_rounded,
    _ => Icons.notifications_none_rounded,
  };

  String _repeatLabel(Reminder r) {
    if (r.repeatFrequency == RepeatFrequency.custom) return 'Every ${r.customInterval} ${r.customUnit}';
    return r.repeatFrequency.name[0].toUpperCase() + r.repeatFrequency.name.substring(1);
  }
}

// ─── Add reminder sheet ──────────────────────────────────────────────────────

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
  RepeatFrequency _repeat = RepeatFrequency.none;
  ReminderPriority _priority = ReminderPriority.medium;
  int _customInterval = 1;
  String _customUnit = 'days';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialReminder != null) {
      final r = widget.initialReminder!;
      _titleCtrl.text = r.title; _bodyCtrl.text = r.body; _selectedDateTime = r.scheduledTime;
      _repeat = r.repeatFrequency; _priority = r.priority;
      _customInterval = r.customInterval ?? 1; _customUnit = r.customUnit ?? 'days';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(widget.initialReminder == null ? 'New Task' : 'Edit Task', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'What needs to be done?'), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _bodyCtrl, decoration: const InputDecoration(labelText: 'Notes (Optional)'), maxLines: 2),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _pickBtn('Scheduled Time', _selectedDateTime == null ? 'Not Set' : SettingsService.instance.formatDateTime(_selectedDateTime!), Icons.access_time_filled_rounded, () async {
                    final d = await showDatePicker(context: context, initialDate: _selectedDateTime ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                    if (d != null && mounted) {
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()));
                      if (t != null) setState(() => _selectedDateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                    }
                  })),
                ],
              ),
              const SizedBox(height: 16),
              _dropdown<RepeatFrequency>('Repeat Frequency', _repeat, RepeatFrequency.values, (v) => setState(() => _repeat = v!)),
              if (_repeat == RepeatFrequency.custom) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(initialValue: _customInterval.toString(), decoration: const InputDecoration(labelText: 'Interval'), keyboardType: TextInputType.number, onChanged: (v) => _customInterval = int.tryParse(v) ?? 1)),
                    const SizedBox(width: 12),
                    Expanded(child: _dropdown<String>('Unit', _customUnit, ['days', 'weeks', 'months'], (v) => setState(() => _customUnit = v!))),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              const Text('Task Priority', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                children: ReminderPriority.values.map((p) => Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Center(child: Text(p.name.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))),
                    selected: _priority == p,
                    onSelected: (s) => setState(() => _priority = p),
                  ),
                ))).toList(),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Reminder', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickBtn(String label, String value, IconData icon, VoidCallback onTap) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1))), child: Row(children: [Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7), fontWeight: FontWeight.w800)), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))])])));

  Widget _dropdown<T>(String label, T value, List<T> items, ValueChanged<T?> onChanged) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.05), border: Border.all(color: Colors.grey.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(16)), child: DropdownButtonHideUnderline(child: DropdownButton<T>(value: value, isExpanded: true, items: items.map((i) => DropdownMenuItem(value: i, child: Text(i is Enum ? i.name.toUpperCase() : i.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)))).toList(), onChanged: onChanged)));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedDateTime == null) return;
    setState(() => _submitting = true);
    final r = Reminder(id: widget.initialReminder?.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000, title: _titleCtrl.text, body: _bodyCtrl.text, scheduledTime: _selectedDateTime!, repeatFrequency: _repeat, priority: _priority, customInterval: _customInterval, customUnit: _customUnit);
    await widget.onAdd(r);
    if (mounted) Navigator.pop(context);
  }
}

class _FetchErrorState extends StatelessWidget {
  final String error; final VoidCallback onRetry;
  const _FetchErrorState({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) { return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 16), Text('Failed to load tasks'), TextButton(onPressed: onRetry, child: const Text('Retry'))])); }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.all(20),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _EmptyIconRow(color: Color(0xFFF97316)),
                _EmptyIconRow(color: Color(0xFF3B82F6)),
                _EmptyIconRow(color: Color(0xFF22C55E)),
                _EmptyIconRow(color: Color(0xFFA855F7)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('All clear!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('No active reminders found.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onAdd, child: const Text('Add Task')),
        ],
      ),
    );
  }
}

class _EmptyIconRow extends StatelessWidget {
  final Color color;
  const _EmptyIconRow({required this.color});
  @override
  Widget build(BuildContext context) { return Row(children: [Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))), const SizedBox(width: 16), Expanded(child: Container(height: 3, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(2))))]); }
}
