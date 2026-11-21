import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../remainder/reminder_model.dart';

class UpliftFullAddScreen extends StatefulWidget {
  const UpliftFullAddScreen({
    super.key,
    required this.onAdd,
    this.initialReminder,
  });

  final Future<void> Function(Reminder) onAdd;
  final Reminder? initialReminder;

  @override
  State<UpliftFullAddScreen> createState() => _UpliftFullAddScreenState();
}

class _UpliftFullAddScreenState extends State<UpliftFullAddScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _stepCtrl = TextEditingController();
  final List<String> _steps = [];
  DateTime? _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  RepeatFrequency _repeat = RepeatFrequency.none;
  ReminderPriority _priority = ReminderPriority.medium;
  String _category = 'Personal';
  bool _submitting = false;

  Color get _accentColor {
    final val = SettingsService.instance.fontColorValue;
    return val != 0 ? Color(val) : Theme.of(context).colorScheme.primary;
  }

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
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _stepCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.initialReminder == null ? 'New reminder' : 'Edit reminder', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Stored in this phone\'s memory — never uploaded', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // What should we remind you?
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'What should we remind you?',
              suffixIcon: IconButton(icon: const Icon(Icons.mic_none_rounded), onPressed: () {}),
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          // Notes
          TextField(
            controller: _bodyCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Notes (optional)',
              suffixIcon: IconButton(icon: const Icon(Icons.mic_none_rounded), onPressed: () {}),
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          // Checklist
          Text('CHECKLIST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text('Optional steps for this remainder. Up to 20.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withOpacity(0.7))),
          const SizedBox(height: 8),
          ..._steps.map((step) => ListTile(
            dense: true,
            leading: const Icon(Icons.drag_indicator_rounded, size: 18),
            title: Text(step),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => setState(() => _steps.remove(step)),
            ),
          )),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _stepCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add a step',
                    suffixIcon: IconButton(icon: const Icon(Icons.mic_none_rounded), onPressed: () {}),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.add_rounded),
                onPressed: () {
                  if (_stepCtrl.text.trim().isNotEmpty) {
                    setState(() {
                      _steps.add(_stepCtrl.text.trim());
                      _stepCtrl.clear();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Contact
          Text('CONTACT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text('Attach a number from Contacts or type it. It stays on this phone.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withOpacity(0.7))),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: cardBg,
              side: BorderSide.none,
            ),
            icon: const Icon(Icons.perm_contact_calendar_outlined),
            label: const Text('Attach number', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 20),
          // Photos and Videos
          Text('PHOTOS AND VIDEOS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text('Saved on this phone only. Up to 8.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withOpacity(0.7))),
          const SizedBox(height: 8),
          SizedBox(
            width: 90,
            height: 90,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                backgroundColor: cardBg,
                side: BorderSide.none,
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded),
                  SizedBox(height: 4),
                  Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // When
          Text('WHEN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.calendar_month_rounded, color: cs.primary),
                        const SizedBox(height: 12),
                        const Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(_selectedDateTime ?? DateTime.now()),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.access_time_rounded, color: cs.primary),
                        const SizedBox(height: 12),
                        const Text('Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(_selectedDateTime ?? DateTime.now()),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Repeat
          Text('REPEAT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          DropdownButtonFormField<RepeatFrequency>(
            value: _repeat,
            decoration: InputDecoration(
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
            items: RepeatFrequency.values.map((f) {
              return DropdownMenuItem(
                value: f,
                child: Text(f == RepeatFrequency.none ? 'Does not repeat' : f.name.toUpperCase()),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _repeat = v);
            },
          ),
          const SizedBox(height: 24),
          // Category
          Text('CATEGORY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: InputDecoration(
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
            items: const [
              DropdownMenuItem(value: 'Personal', child: Text('Personal')),
              DropdownMenuItem(value: 'Home', child: Text('Home')),
              DropdownMenuItem(value: 'My Family', child: Text('My Family')),
              DropdownMenuItem(value: 'Work', child: Text('Work')),

            ],
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: 24),
          // Priority
          Text('PRIORITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          SegmentedButton<ReminderPriority>(
            segments: const [
              ButtonSegment(value: ReminderPriority.low, label: Text('Low')),
              ButtonSegment(value: ReminderPriority.medium, label: Text('Medium')),
              ButtonSegment(value: ReminderPriority.high, label: Text('High')),
            ],
            selected: {_priority},
            onSelectionChanged: (val) => setState(() => _priority = val.first),
          ),
          const SizedBox(height: 40),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.3))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reminds you on ${_formatDate(_selectedDateTime ?? DateTime.now())} at ${_formatTime(_selectedDateTime ?? DateTime.now())}.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submitting ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                backgroundColor: _accentColor,
              ),
              child: Text(_submitting ? 'Saving...' : 'Save remainder', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
        ),
        if (_submitting)
          Container(
            color: Colors.black.withOpacity(0.4),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
  }

  String _formatTime(DateTime dt) {
    return SettingsService.instance.formatDateTime(dt).split('·').last.trim();
  }

  Future<void> _pickDate() async {
    final cur = _selectedDateTime ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      _selectedDateTime = DateTime(d.year, d.month, d.day, cur.hour, cur.minute);
    });
  }

  Future<void> _pickTime() async {
    final cur = _selectedDateTime ?? DateTime.now();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(cur),
    );
    if (t == null) return;
    setState(() {
      _selectedDateTime = DateTime(cur.year, cur.month, cur.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter what to remind you')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final reminder = Reminder(
        id: widget.initialReminder?.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        scheduledTime: _selectedDateTime ?? DateTime.now(),
        repeatFrequency: _repeat,
        isActive: true,
        priority: _priority,
        uiType: SettingsService.instance.uiStyle.name,
      );
      await widget.onAdd(reminder);
      if (mounted) {
        Navigator.pop(context); // Close full screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
