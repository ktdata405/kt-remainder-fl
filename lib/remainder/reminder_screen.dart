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
      if (mounted) setState(() => _isServiceReady = true);
      await _reload();
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

  Future<void> _cancelReminder(int id) async {
    if (!_isServiceReady) return;
    try {
      await _service.cancelReminder(id);
      await _reload();
    } catch (e) {
      _snack('Cancel failed: $e');
    }
  }

  Future<void> _addReminder(Reminder reminder) async {
    await _service.scheduleReminder(reminder);
    await _reload();
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
      fetchError: _fetchError,
      onRefresh: _reload,
      onCancel: _cancelReminder,
      onAdd: _addReminder,
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

class _ListScreen extends StatelessWidget {
  const _ListScreen({
    required this.reminders,
    required this.isReloading,
    this.fetchError,
    required this.onRefresh,
    required this.onCancel,
    required this.onAdd,
    required this.onToggleTheme,
    required this.onOpenSettings,
    required this.isDark,
  });

  final List<Reminder> reminders;
  final bool isReloading;
  final String? fetchError;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int) onCancel;
  final Future<void> Function(Reminder) onAdd;
  final VoidCallback onToggleTheme;
  final Future<void> Function() onOpenSettings;
  final bool isDark;

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AddReminderSheet(onAdd: onAdd),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showCancelled = SettingsService.instance.showCancelledReminders;
    final visibleReminders = showCancelled
        ? reminders
        : reminders.where((r) => r.isActive).toList();

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        title: const Text('Reminders',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
        centerTitle: false,
        bottom: isReloading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: cs.surfaceContainerLowest,
                ),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            onPressed: onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Refresh',
            onPressed: isReloading ? null : onRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: onOpenSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: fetchError != null
            ? _FetchErrorState(error: fetchError!, onRetry: onRefresh)
            : visibleReminders.isEmpty
                ? _EmptyState(onAdd: () => _openAddSheet(context))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    itemCount: visibleReminders.length,
                    itemBuilder: (context, i) => _ReminderCard(
                      reminder: visibleReminders[i],
                      onCancel: () => onCancel(visibleReminders[i].id),
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context),
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('Add Reminder',
            style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 4,
      ),
    );
  }
}

// ─── Reminder card ────────────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder, required this.onCancel});
  final Reminder reminder;
  final VoidCallback onCancel;

  Color _accent(BuildContext context) {
    if (!reminder.isActive) return Colors.grey;
    switch (reminder.repeatFrequency) {
      case RepeatFrequency.none:    return Theme.of(context).colorScheme.primary;
      case RepeatFrequency.daily:   return const Color(0xFF22C55E);
      case RepeatFrequency.weekly:  return const Color(0xFF8B5CF6);
      case RepeatFrequency.monthly: return const Color(0xFFF97316);
    }
  }

  String _fmt(DateTime dt) =>
      SettingsService.instance.formatDateTime(dt);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = _accent(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isDark ? 0 : 2,
        shadowColor: cs.shadow.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
        color: isDark ? cs.surfaceContainer : cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Accent bar
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              reminder.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: reminder.isActive ? null : TextDecoration.lineThrough,
                                color: reminder.isActive
                                    ? cs.onSurface
                                    : cs.onSurface.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          if (reminder.isActive)
                            IconButton(
                              onPressed: onCancel,
                              icon: const Icon(Icons.cancel_rounded),
                              iconSize: 20,
                              color: cs.error.withValues(alpha: 0.8),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Cancel reminder',
                            ),
                        ],
                      ),
                      if (reminder.body.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          reminder.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Chip(icon: Icons.access_time_rounded, label: _fmt(reminder.scheduledTime), color: accent),
                          if (reminder.repeatFrequency != RepeatFrequency.none)
                            _Chip(
                              icon: Icons.repeat_rounded,
                              label: _capitalize(reminder.repeatFrequency.name),
                              color: const Color(0xFF0EA5E9),
                            ),
                          if (!reminder.isActive)
                            const _Chip(icon: Icons.block_rounded, label: 'Cancelled', color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
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
  const _AddReminderSheet({required this.onAdd});
  final Future<void> Function(Reminder) onAdd;

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

  @override
  void initState() {
    super.initState();
    _repeat = SettingsService.instance.defaultRepeat;
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
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        scheduledTime: _selectedDateTime!,
        repeatFrequency: _repeat,
        isActive: true,
      ));
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Reminder scheduled!'),
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
                        Text('New Reminder',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        Text('Fill in the details below',
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
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.alarm_add_rounded),
                                  SizedBox(width: 10),
                                  Text('Schedule Reminder'),
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
