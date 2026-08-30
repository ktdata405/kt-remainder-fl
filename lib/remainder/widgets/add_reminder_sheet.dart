import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../reminder_model.dart';

class AddReminderSheet extends StatefulWidget {
  const AddReminderSheet({
    super.key,
    required this.onAdd,
    this.initialReminder,
  });

  final Future<void> Function(Reminder) onAdd;
  final Reminder? initialReminder;

  @override
  State<AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<AddReminderSheet> {
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
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, 
                  height: 4, 
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.1), 
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.initialReminder == null ? 'New Task' : 'Edit Task', 
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleCtrl, 
                decoration: const InputDecoration(labelText: 'What needs to be done?'), 
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyCtrl, 
                decoration: const InputDecoration(labelText: 'Notes (Optional)'), 
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              _pickBtn(
                'Scheduled Time', 
                _selectedDateTime == null 
                    ? 'Not Set' 
                    : SettingsService.instance.formatDateTime(_selectedDateTime!), 
                Icons.access_time_filled_rounded, 
                () async {
                  final d = await showDatePicker(
                    context: context, 
                    initialDate: _selectedDateTime ?? DateTime.now(), 
                    firstDate: DateTime.now(), 
                    lastDate: DateTime(2100),
                  );
                  if (d == null || !mounted) return;
                  final t = await showTimePicker(
                    context: context, 
                    initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
                  );
                  if (t != null) {
                    setState(() => _selectedDateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                  }
                },
              ),
              const SizedBox(height: 16),
              _dropdown<RepeatFrequency>(
                'Repeat Frequency', 
                _repeat, 
                RepeatFrequency.values, 
                (v) => setState(() => _repeat = v!),
              ),
              if (_repeat == RepeatFrequency.custom) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _customInterval.toString(), 
                        decoration: const InputDecoration(labelText: 'Interval'), 
                        keyboardType: TextInputType.number, 
                        onChanged: (v) => _customInterval = int.tryParse(v) ?? 1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dropdown<String>(
                        'Unit', 
                        _customUnit, 
                        const ['days', 'weeks', 'months'], 
                        (v) => setState(() => _customUnit = v!),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              const Text('Task Priority', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                children: ReminderPriority.values.map((p) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          p.name.toUpperCase(), 
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                      selected: _priority == p,
                      onSelected: (s) => setState(() => _priority = p),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _submitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                    : const Text('Save Reminder', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickBtn(String label, String value, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap, 
      child: Container(
        padding: const EdgeInsets.all(16), 
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.05), 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: cs.primary.withValues(alpha: 0.1)),
        ), 
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.primary), 
            const SizedBox(width: 12), 
            Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(
                  label, 
                  style: TextStyle(
                    fontSize: 10, 
                    color: cs.primary.withValues(alpha: 0.7), 
                    fontWeight: FontWeight.w800,
                  ),
                ), 
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>(String label, T value, List<T> items, ValueChanged<T?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), 
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05), 
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)), 
        borderRadius: BorderRadius.circular(16),
      ), 
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value, 
          isExpanded: true, 
          items: items.map((i) {
            String text = '';
            if (i is RepeatFrequency) {
              text = _getRepeatFrequencyText(i);
            } else {
              text = i.toString().toUpperCase();
            }
            return DropdownMenuItem(
              value: i, 
              child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            );
          }).toList(), 
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _getRepeatFrequencyText(RepeatFrequency frequency) {
    return switch (frequency) {
      RepeatFrequency.none => 'None',
      RepeatFrequency.daily => 'Daily',
      RepeatFrequency.weekly => 'Weekly',
      RepeatFrequency.monthly => 'Monthly',
      RepeatFrequency.weekdays => 'Weekdays (Mon-Fri)',
      RepeatFrequency.weekends => 'Weekends (Sat-Sun)',
      RepeatFrequency.yearly => 'Yearly',
      RepeatFrequency.monday => 'Every Monday',
      RepeatFrequency.tuesday => 'Every Tuesday',
      RepeatFrequency.wednesday => 'Every Wednesday',
      RepeatFrequency.thursday => 'Every Thursday',
      RepeatFrequency.friday => 'Every Friday',
      RepeatFrequency.saturday => 'Every Saturday',
      RepeatFrequency.sunday => 'Every Sunday',
      RepeatFrequency.custom => 'Custom...',
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedDateTime == null) return;
    setState(() => _submitting = true);
    final r = Reminder(
      id: widget.initialReminder?.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000, 
      title: _titleCtrl.text, 
      body: _bodyCtrl.text, 
      scheduledTime: _selectedDateTime!, 
      repeatFrequency: _repeat, 
      priority: _priority, 
      customInterval: _customInterval, 
      customUnit: _customUnit,
    );
    await widget.onAdd(r);
    if (mounted) Navigator.pop(context);
  }
}
