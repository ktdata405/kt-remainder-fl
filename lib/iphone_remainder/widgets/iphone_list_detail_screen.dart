import 'package:flutter/material.dart';
import '../../remainder/reminder_model.dart';
import '../../remainder/reminder_service.dart';
import 'iphone_add_reminder_sheet.dart';

class IphoneListDetailScreen extends StatefulWidget {
  const IphoneListDetailScreen({
    super.key,
    required this.title,
    required this.accentColor,
    required this.reminders,
    required this.onChanged,
  });

  final String title;
  final Color accentColor;
  final List<Reminder> reminders;
  final VoidCallback onChanged;

  @override
  State<IphoneListDetailScreen> createState() => _IphoneListDetailScreenState();
}

class _IphoneListDetailScreenState extends State<IphoneListDetailScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = widget.reminders.where((r) {
      if (_searchQuery.isEmpty) return true;
      return r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.body.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_ios_new, color: widget.accentColor, size: 20),
                        const SizedBox(width: 4),
                        Text('Lists', style: TextStyle(color: widget.accentColor, fontSize: 17, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_horiz, color: widget.accentColor),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                widget.title,
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: widget.accentColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No Reminders',
                        style: TextStyle(fontSize: 18, color: isDark ? Colors.grey[600] : Colors.grey[400], fontWeight: FontWeight.w500),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 48),
                      itemBuilder: (context, index) {
                        final r = filtered[index];
                        return Dismissible(
                          key: Key('reminder_${r.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) async {
                            await ReminderService.instance.cancelReminder(r.id);
                            widget.onChanged();
                          },
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: GestureDetector(
                              onTap: () async {
                                final advanced = r.advancedForCompletion();
                                await ReminderService.instance.scheduleReminder(advanced);
                                widget.onChanged();
                              },
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: widget.accentColor, width: 2),
                                ),
                              ),
                            ),
                            title: Text(r.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            subtitle: r.body.isNotEmpty
                                ? Text(r.body, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]))
                                : null,
                            trailing: r.priority == ReminderPriority.high
                                ? const Icon(Icons.flag, color: Colors.orange, size: 18)
                                : null,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => IphoneAddReminderSheet(
                                  initialList: widget.title,
                                  reminderToEdit: r,
                                  onReminderAdded: widget.onChanged,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => IphoneAddReminderSheet(
                          initialList: widget.title,
                          onReminderAdded: widget.onChanged,
                        ),
                      );
                    },
                    icon: Icon(Icons.add_circle, color: widget.accentColor),
                    label: Text('New Reminder', style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
