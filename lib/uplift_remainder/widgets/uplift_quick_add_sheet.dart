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
  bool _submitting = false;

  Color get _accentColor {
    final val = SettingsService.instance.fontColorValue;
    return val != 0 ? Color(val) : Theme.of(context).colorScheme.primary;
  }

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
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
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
                        color: _accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.bolt_rounded, color: _accentColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      widget.initialReminder == null ? 'Quick Reminder' : 'Edit Reminder',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: cs.onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Modern input container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
                  ),
                  child: TextField(
                    controller: _titleCtrl,
                    autofocus: true,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6), fontWeight: FontWeight.w500),
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: Icon(Icons.mic_none_rounded, color: _accentColor),
                        onPressed: () {},
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'SCHEDULE QUICKLY',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, letterSpacing: 1.0),
                ),
                const SizedBox(height: 12),
                // Quick options grid: 15 Min, 30 Min, 1 hr, 1.5 hr, 2 hr, Tonight, Tomorrow, Custom
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.3,
                  children: [
                    _quickTimeChip('15 Min', Icons.timer_outlined, _submitting ? null : () => _quickSave(const Duration(minutes: 15)), cs, cardBg),
                    _quickTimeChip('30 Min', Icons.hourglass_bottom_rounded, _submitting ? null : () => _quickSave(const Duration(minutes: 30)), cs, cardBg),
                    _quickTimeChip('1 hr', Icons.looks_one_rounded, _submitting ? null : () => _quickSave(const Duration(hours: 1)), cs, cardBg),
                    _quickTimeChip('1.5 hr', Icons.access_time_rounded, _submitting ? null : () => _quickSave(const Duration(minutes: 90)), cs, cardBg),
                    _quickTimeChip('2 hr', Icons.looks_two_rounded, _submitting ? null : () => _quickSave(const Duration(hours: 2)), cs, cardBg),
                    _quickTimeChip('Tonight', Icons.nights_stay_outlined, _submitting ? null : _quickSaveTonight, cs, cardBg),
                    _quickTimeChip('Tomorrow', Icons.wb_sunny_outlined, _submitting ? null : _quickSaveTomorrow, cs, cardBg),
                    _quickTimeChip('Custom', Icons.calendar_month_rounded, _submitting ? null : _openCustomEditor, cs, cardBg),
                  ],
                ),
                const SizedBox(height: 30),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _openCustomEditor,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(color: Colors.blueGrey.withOpacity(0.5)),
                    backgroundColor: Colors.lightBlue,
                  ),
                  label: Text('Go to Regular', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          if (_submitting)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _quickTimeChip(String label, IconData icon, VoidCallback? onTap, ColorScheme cs, Color cardBg) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _accentColor, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: cs.onSurface),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCustomEditor() {
    FocusScope.of(context).unfocus();
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
  }

  void _quickSave(Duration duration) async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter what to remember')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
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
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
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
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _quickSaveTomorrow() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 9, 0);
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter what to remember')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
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
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
