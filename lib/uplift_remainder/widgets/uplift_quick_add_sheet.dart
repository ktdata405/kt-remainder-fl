import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../remainder/reminder_model.dart';
import 'uplift_full_add_screen.dart';

class UpliftQuickAddSheet extends StatefulWidget {
  const UpliftQuickAddSheet({
    super.key,
    required this.onAdd,
    this.initialReminder,
  });

  final Future<void> Function(Reminder) onAdd;
  final Reminder? initialReminder;

  @override
  State<UpliftQuickAddSheet> createState() => _UpliftQuickAddSheetState();
}

class _UpliftQuickAddSheetState extends State<UpliftQuickAddSheet> {
  final _titleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialReminder != null) {
      _titleCtrl.text = widget.initialReminder!.title;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
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
          const SizedBox(height: 16),
          const Text(
            'Quick add',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            '1. Type what to remember\n2. Tap when to alert you',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'e.g. Call mom, take medicine',
              prefixText: 'Reminder  ',
              prefixStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
              suffixIcon: IconButton(
                icon: const Icon(Icons.mic_none_rounded),
                onPressed: () {},
              ),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: cs.primary, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: cs.primary.withOpacity(0.5), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Type a reminder first, then choose a time',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _quickSave(const Duration(hours: 1)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('In 1 hour', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _quickSaveTonight(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Tonight', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _quickSaveTomorrow(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Tomorrow', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UpliftFullAddScreen(
                    onAdd: widget.onAdd,
                    initialReminder: widget.initialReminder,
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              side: BorderSide(color: cs.outline.withOpacity(0.5)),
            ),
            child: const Text('Need notes, repeat, or a photo?', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Opens the full editor — still saved only on this phone.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }

  void _quickSave(Duration duration) async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter what to remember')));
      return;
    }
    final reminder = Reminder(
      id: widget.initialReminder?.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: '',
      scheduledTime: DateTime.now().add(duration),
      repeatFrequency: RepeatFrequency.none,
      isActive: true,
      priority: ReminderPriority.medium,
      uiType: SettingsService.instance.uiStyle.name,
    );
    await widget.onAdd(reminder);
    if (mounted) Navigator.pop(context);
  }

  void _quickSaveTonight() async {
    final now = DateTime.now();
    final tonight = DateTime(now.year, now.month, now.day, 20, 0);
    final target = tonight.isAfter(now) ? tonight : now.add(const Duration(hours: 3));
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter what to remember')));
      return;
    }
    final reminder = Reminder(
      id: widget.initialReminder?.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: '',
      scheduledTime: target,
      repeatFrequency: RepeatFrequency.none,
      isActive: true,
      priority: ReminderPriority.medium,
      uiType: SettingsService.instance.uiStyle.name,
    );
    await widget.onAdd(reminder);
    if (mounted) Navigator.pop(context);
  }

  void _quickSaveTomorrow() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 9, 0);
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter what to remember')));
      return;
    }
    final reminder = Reminder(
      id: widget.initialReminder?.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: '',
      scheduledTime: tomorrow,
      repeatFrequency: RepeatFrequency.none,
      isActive: true,
      priority: ReminderPriority.medium,
      uiType: SettingsService.instance.uiStyle.name,
    );
    await widget.onAdd(reminder);
    if (mounted) Navigator.pop(context);
  }
}
