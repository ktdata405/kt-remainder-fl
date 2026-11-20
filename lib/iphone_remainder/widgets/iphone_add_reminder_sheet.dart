import 'package:flutter/material.dart';
import '../../remainder/reminder_model.dart';
import '../../remainder/reminder_service.dart';
import '../iphone_reminder_service.dart';

class IphoneAddReminderSheet extends StatefulWidget {
  const IphoneAddReminderSheet({
    super.key,
    required this.initialList,
    required this.onReminderAdded,
    this.reminderToEdit,
  });

  final String initialList;
  final VoidCallback onReminderAdded;
  final Reminder? reminderToEdit;

  @override
  State<IphoneAddReminderSheet> createState() => _IphoneAddReminderSheetState();
}

class _IphoneAddReminderSheetState extends State<IphoneAddReminderSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _scheduledTime;
  late ReminderPriority _priority;
  late String _selectedList;
  bool _hasDate = true;
  bool _hasTime = false;
  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.reminderToEdit;
    _titleController = TextEditingController(text: edit?.title ?? '');
    _notesController = TextEditingController(text: edit?.body ?? '');
    _scheduledTime = edit?.scheduledTime ?? DateTime.now().add(const Duration(hours: 1));
    _priority = edit?.priority ?? ReminderPriority.medium;
    final rawList = edit != null && edit.customUnit != null && edit.customUnit!.startsWith('list:')
        ? edit.customUnit!.substring(5)
        : widget.initialList;

    final customListNames = IphoneReminderService.instance.customLists.map((l) => l.name).toList();
    if (customListNames.any((name) => name.toLowerCase() == rawList.toLowerCase())) {
      _selectedList = customListNames.firstWhere((name) => name.toLowerCase() == rawList.toLowerCase());
    } else {
      _selectedList = customListNames.isNotEmpty ? customListNames.first : 'Reminders';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF007AFF), fontSize: 16)),
                ),
                Text(widget.reminderToEdit == null ? 'New Reminder' : 'Edit Reminder',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                TextButton(
                  onPressed: () async {
                    final title = _titleController.text.trim();
                    if (title.isEmpty) return;

                    final reminder = Reminder(
                      id: widget.reminderToEdit?.id ?? DateTime.now().millisecondsSinceEpoch,
                      title: title,
                      body: _notesController.text.trim(),
                      scheduledTime: _scheduledTime,
                      priority: _priority,
                      customUnit: 'list:$_selectedList',
                    );

                    await ReminderService.instance.scheduleReminder(reminder);
                    widget.onReminderAdded();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Add', style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    autofocus: widget.reminderToEdit == null,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                  const Divider(height: 1, indent: 16),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Notes',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Date', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    value: _hasDate,
                    onChanged: (v) => setState(() => _hasDate = v),
                  ),
                  const Divider(height: 1, indent: 16),
                  SwitchListTile(
                    title: const Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Time', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    value: _hasTime,
                    onChanged: (v) => setState(() => _hasTime = v),
                  ),
                  const Divider(height: 1, indent: 16),
                  SwitchListTile(
                    title: const Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.blue, size: 20),
                        SizedBox(width: 12),
                        Text('Location', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    value: _hasLocation,
                    onChanged: (v) => setState(() => _hasLocation = v),
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    leading: const Icon(Icons.list, color: Colors.orange, size: 20),
                    title: const Text('List', style: TextStyle(fontWeight: FontWeight.w500)),
                    trailing: DropdownButton<String>(
                      value: _selectedList,
                      underline: const SizedBox(),
                      items: IphoneReminderService.instance.customLists
                          .map((l) => DropdownMenuItem(value: l.name, child: Text(l.name)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedList = v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Quick chips bar matching iOS screenshot
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickChip(
                    label: 'Today',
                    icon: Icons.today,
                    color: Colors.blue,
                    onTap: () => setState(() => _scheduledTime = DateTime.now()),
                  ),
                  const SizedBox(width: 8),
                  _QuickChip(
                    label: 'Tomorrow',
                    icon: Icons.event,
                    color: Colors.orange,
                    onTap: () => setState(() => _scheduledTime = DateTime.now().add(const Duration(days: 1))),
                  ),
                  const SizedBox(width: 8),
                  _QuickChip(
                    label: 'This Weekend',
                    icon: Icons.weekend,
                    color: Colors.purple,
                    onTap: () => setState(() => _scheduledTime = DateTime.now().add(const Duration(days: 2))),
                  ),
                  const SizedBox(width: 8),
                  _QuickChip(
                    label: 'Date & Time',
                    icon: Icons.calendar_month,
                    color: Colors.red,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _scheduledTime,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) {
                        setState(() {
                          _scheduledTime = DateTime(picked.year, picked.month, picked.day, _scheduledTime.hour, _scheduledTime.minute);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Keyboard accessory toolbar matching screenshot
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(icon: const Icon(Icons.document_scanner_outlined, size: 22), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.location_searching, size: 22), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.flag_outlined, size: 22), onPressed: () {
                    setState(() {
                      _priority = _priority == ReminderPriority.high ? ReminderPriority.medium : ReminderPriority.high;
                    });
                  }),
                  IconButton(icon: const Icon(Icons.camera_alt_outlined, size: 22), onPressed: () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.icon, required this.color, required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
