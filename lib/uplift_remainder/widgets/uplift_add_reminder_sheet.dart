import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../remainder/reminder_model.dart';

class UpliftAddReminderSheet extends StatefulWidget {
  const UpliftAddReminderSheet({
    super.key,
    required this.onAdd,
    this.initialReminder,
  });

  final Future<void> Function(Reminder) onAdd;
  final Reminder? initialReminder;

  @override
  State<UpliftAddReminderSheet> createState() => _UpliftAddReminderSheetState();
}

class _UpliftAddReminderSheetState extends State<UpliftAddReminderSheet> {
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
      _titleCtrl.text = r.title;
      _bodyCtrl.text = r.body;
      _selectedDateTime = r.scheduledTime;
      _repeat = r.repeatFrequency;
      _priority = r.priority;
      _customInterval = r.customInterval ?? 1;
      _customUnit = r.customUnit ?? 'days';
    } else {
      _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.initialReminder == null ? Icons.add_task_rounded : Icons.edit_rounded,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    widget.initialReminder == null ? 'Create New Task' : 'Edit Task',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleCtrl,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Task Title',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description or Notes (Optional)',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 20),
              // Date & Time Picker Tile
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, color: cs.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Scheduled Time', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              _selectedDateTime == null ? 'Tap to select date & time' : SettingsService.instance.formatDateTime(_selectedDateTime!),
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cs.onSurface),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Priority Selector
              Text('Priority', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              SegmentedButton<ReminderPriority>(
                segments: const [
                  ButtonSegment(value: ReminderPriority.low, label: Text('Low'), icon: Icon(Icons.arrow_downward_rounded, size: 16)),
                  ButtonSegment(value: ReminderPriority.medium, label: Text('Medium'), icon: Icon(Icons.remove_rounded, size: 16)),
                  ButtonSegment(value: ReminderPriority.high, label: Text('High'), icon: Icon(Icons.priority_high_rounded, size: 16)),
                ],
                selected: {_priority},
                onSelectionChanged: (val) => setState(() => _priority = val.first),
              ),
              const SizedBox(height: 20),
              // Repeat Frequency Dropdown
              DropdownButtonFormField<RepeatFrequency>(
                value: _repeat,
                decoration: InputDecoration(
                  labelText: 'Repeat Frequency',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.repeat_rounded),
                ),
                items: RepeatFrequency.values.map((f) {
                  return DropdownMenuItem(value: f, child: Text(f.name.toUpperCase()));
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _repeat = v);
                },
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _submitting ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(_submitting ? 'Saving...' : (widget.initialReminder == null ? 'Create Reminder' : 'Update Reminder'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
    );
    if (t == null) return;
    if (!mounted) return;
    setState(() {
      _selectedDateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a scheduled time')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final id = widget.initialReminder?.id ?? DateTime.now().millisecondsSinceEpoch.remainder(1000000);
      final reminder = Reminder(
        id: id,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        scheduledTime: _selectedDateTime!,
        repeatFrequency: _repeat,
        isActive: true,
        priority: _priority,
        customInterval: _customInterval,
        customUnit: _customUnit,
      );
      await widget.onAdd(reminder);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
