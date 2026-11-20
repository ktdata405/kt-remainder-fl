import 'dart:async';
import 'package:flutter/material.dart';
import '../remainder/reminder_model.dart';
import '../remainder/reminder_service.dart';
import '../services/settings_service.dart';
import '../settings/settings_screen.dart';
import 'iphone_reminder_service.dart';
import 'widgets/iphone_add_list_sheet.dart';
import 'widgets/iphone_add_reminder_sheet.dart';
import 'widgets/iphone_list_detail_screen.dart';

class IphoneReminderScreen extends StatefulWidget {
  const IphoneReminderScreen({
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
  State<IphoneReminderScreen> createState() => _IphoneReminderScreenState();
}

class _IphoneReminderScreenState extends State<IphoneReminderScreen> {
  final ReminderService _service = ReminderService.instance;
  final IphoneReminderService _iphoneService = IphoneReminderService.instance;
  List<Reminder> _reminders = [];
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _iphoneService.init();
    await _service.initialize(webAppUrl: widget.webAppUrl);
    await _loadReminders();
  }

  Future<void> _loadReminders() async {
    try {
      if (SettingsService.instance.useLocalStorage) {
        final local = await _service.getLocalReminders();
        setState(() => _reminders = local);
      } else {
        await _service.rescheduleActiveRemindersFromSheet();
        final remote = await _service.getLocalReminders();
        setState(() => _reminders = remote);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    final todayList = _iphoneService.getTodayReminders(_reminders);
    final scheduledList = _iphoneService.getScheduledReminders(_reminders);
    final allList = _iphoneService.getAllReminders(_reminders);
    final flaggedList = _iphoneService.getFlaggedReminders(_reminders);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar / Settings & Edit Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings_rounded, color: Color(0xFF007AFF), size: 24),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                            onSettingsChanged: widget.onSettingsChanged,
                          ),
                        ),
                      );
                    },
                    tooltip: 'Settings',
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isEditing = !_isEditing),
                    child: Text(
                      _isEditing ? 'Done' : 'Edit',
                      style: const TextStyle(color: Color(0xFF007AFF), fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
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
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Summary Cards Grid (2x2)
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Today',
                          count: todayList.length,
                          icon: Icons.calendar_today_rounded,
                          color: Colors.blue,
                          cardBg: cardBg,
                          onTap: () => _navigateToList('Today', Colors.blue, todayList),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Scheduled',
                          count: scheduledList.length,
                          icon: Icons.event_rounded,
                          color: Colors.red,
                          cardBg: cardBg,
                          onTap: () => _navigateToList('Scheduled', Colors.red, scheduledList),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'All',
                          count: allList.length,
                          icon: Icons.inbox_rounded,
                          color: Colors.grey,
                          cardBg: cardBg,
                          onTap: () => _navigateToList('All', Colors.grey.shade700, allList),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Flagged',
                          count: flaggedList.length,
                          icon: Icons.flag_rounded,
                          color: Colors.orange,
                          cardBg: cardBg,
                          onTap: () => _navigateToList('Flagged', Colors.orange, flaggedList),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('My Lists', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  // My Lists Container
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: _iphoneService.customLists.map((listInfo) {
                        final listReminders = _iphoneService.getRemindersForList(listInfo.name, _reminders);
                        final isLast = listInfo == _iphoneService.customLists.last;
                        return Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: listInfo.color, shape: BoxShape.circle),
                                child: Icon(listInfo.icon, color: Colors.white, size: 18),
                              ),
                              title: Text(listInfo.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${listReminders.length}', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                                  const SizedBox(width: 8),
                                  if (_isEditing && listInfo.name.toLowerCase() != 'reminders')
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                                      onPressed: () async {
                                        await _iphoneService.deleteCustomList(listInfo.name);
                                        setState(() {});
                                      },
                                    )
                                  else
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                              onTap: () => _navigateToList(listInfo.name, listInfo.color, listReminders),
                            ),
                            if (!isLast) const Divider(height: 1, indent: 56),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: cardBg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => IphoneAddReminderSheet(
                          initialList: 'Reminders',
                          onReminderAdded: _loadReminders,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_circle, color: Color(0xFF007AFF)),
                    label: const Text('New Reminder', style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  TextButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => IphoneAddListSheet(
                          onListAdded: () => setState(() {}),
                        ),
                      );
                    },
                    child: const Text('Add List', style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToList(String title, Color color, List<Reminder> reminders) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IphoneListDetailScreen(
          title: title,
          accentColor: color,
          reminders: reminders,
          onChanged: _loadReminders,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.cardBg,
    required this.onTap,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final Color cardBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                Text('$count', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
