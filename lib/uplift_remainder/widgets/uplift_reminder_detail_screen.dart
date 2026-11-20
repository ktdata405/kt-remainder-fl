import 'package:flutter/material.dart';
import '../../remainder/reminder_model.dart';
import '../../remainder/reminder_service.dart';
import '../../services/settings_service.dart';
import 'uplift_full_add_screen.dart';

class UpliftReminderDetailScreen extends StatefulWidget {
  const UpliftReminderDetailScreen({
    super.key,
    required this.reminder,
    required this.onChanged,
  });

  final Reminder reminder;
  final VoidCallback onChanged;

  @override
  State<UpliftReminderDetailScreen> createState() => _UpliftReminderDetailScreenState();
}

class _UpliftReminderDetailScreenState extends State<UpliftReminderDetailScreen> {
  late Reminder _reminder;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _reminder = widget.reminder;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final customColorVal = SettingsService.instance.fontColorValue;
    final cardBg = customColorVal != 0
        ? Color(customColorVal).withOpacity(0.12)
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_reminder.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder shared')));
            },
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UpliftFullAddScreen(
                    initialReminder: _reminder,
                    onAdd: (updated) async {
                      await ReminderService.instance.scheduleReminder(updated);
                      setState(() => _reminder = updated);
                      widget.onChanged();
                    },
                  ),
                ),
              );
            },
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Reminder'),
                  content: const Text('Are you sure you want to delete this reminder?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm == true) {
                await ReminderService.instance.cancelReminder(_reminder.id);
                widget.onChanged();
                if (context.mounted) Navigator.pop(context);
              }
            },
            tooltip: 'Delete',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // When Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.notifications_active_rounded, color: cs.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('When', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Text(
                              SettingsService.instance.formatDateTime(_reminder.scheduledTime),
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Repeat & Priority Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Repeat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          Text(
                            _reminder.repeatFrequency == RepeatFrequency.none ? 'Does not repeat' : _reminder.repeatFrequency.name.toUpperCase(),
                            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _reminder.priority.name.toUpperCase(),
                              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Mark as done / active button
                FilledButton(
                  onPressed: () async {
                    setState(() => _loading = true);
                    if (_reminder.isActive) {
                      await ReminderService.instance.completeReminder(_reminder.id, fallbackReminder: _reminder);
                      setState(() {
                        _reminder = Reminder(
                          id: _reminder.id,
                          title: _reminder.title,
                          body: _reminder.body,
                          scheduledTime: _reminder.scheduledTime,
                          repeatFrequency: _reminder.repeatFrequency,
                          isActive: false,
                          priority: _reminder.priority,
                          uiType: _reminder.uiType,
                        );
                      });
                    } else {
                      final updated = Reminder(
                        id: _reminder.id,
                        title: _reminder.title,
                        body: _reminder.body,
                        scheduledTime: _reminder.scheduledTime,
                        repeatFrequency: _reminder.repeatFrequency,
                        isActive: true,
                        priority: _reminder.priority,
                        uiType: _reminder.uiType,
                      );
                      await ReminderService.instance.scheduleReminder(updated);
                      setState(() => _reminder = updated);
                    }
                    widget.onChanged();
                    setState(() => _loading = false);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    backgroundColor: _reminder.isActive ? cs.primary : Colors.green,
                  ),
                  child: Text(
                    _reminder.isActive ? 'Mark as done' : 'Mark as active',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 32),
                Text('SNOOZE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _snoozeChip('10 min', const Duration(minutes: 10), cs, cardBg)),
                    const SizedBox(width: 8),
                    Expanded(child: _snoozeChip('1 hour', const Duration(hours: 1), cs, cardBg)),
                    const SizedBox(width: 8),
                    Expanded(child: _snoozeTomorrowChip('Tomorrow', cs, cardBg)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _snoozeChip(String label, Duration duration, ColorScheme cs, Color cardBg) {
    return OutlinedButton(
      onPressed: () async {
        setState(() => _loading = true);
        await ReminderService.instance.snoozeReminder(_reminder.id, by: duration, fallbackReminder: _reminder);
        widget.onChanged();
        if (mounted) Navigator.pop(context);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
    );
  }

  Widget _snoozeTomorrowChip(String label, ColorScheme cs, Color cardBg) {
    return OutlinedButton(
      onPressed: () async {
        setState(() => _loading = true);
        await ReminderService.instance.snoozeReminderTomorrow(_reminder.id);
        widget.onChanged();
        if (mounted) Navigator.pop(context);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
    );
  }
}
