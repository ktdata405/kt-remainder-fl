import 'dart:async';
import 'package:flutter/material.dart';
import '../remainder/reminder_model.dart';
import '../remainder/reminder_service.dart';
import '../services/settings_service.dart';
import '../settings/settings_screen.dart';
import 'widgets/uplift_quick_add_sheet.dart';
import 'widgets/uplift_full_add_screen.dart';
import 'widgets/uplift_reminder_detail_screen.dart';

class UpliftReminderScreen extends StatefulWidget {
  const UpliftReminderScreen({
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
  State<UpliftReminderScreen> createState() => _UpliftReminderScreenState();
}

class _UpliftReminderScreenState extends State<UpliftReminderScreen> {
  final ReminderService _service = ReminderService.instance;
  List<Reminder> _reminders = [];
  bool _isLoading = true;
  int _mainTab = 0; // 0: Remainders, 1: Calendar
  String _subTab = 'today'; // all, today, done
  DateTime _calendarFocusDate = DateTime.now();
  DateTime? _selectedCalendarDate;

  Color get _accentColor {
    final val = SettingsService.instance.fontColorValue;
    return val != 0 ? Color(val) : Theme.of(context).colorScheme.primary;
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      await _service.initialize(webAppUrl: widget.webAppUrl);
      await _loadReminders();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      if (SettingsService.instance.useLocalStorage) {
        final local = await _service.getLocalReminders();
        setState(() => _reminders = local);
      } else {
        await _service.rescheduleActiveRemindersFromSheet();
        final remote = await _service.getLocalReminders();
        setState(() => _reminders = remote);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning, KT';
    if (hour < 17) return 'Good afternoon, KT';
    return 'Good evening, KT';
  }

  String _formatHeaderDate(DateTime dt) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
  }

  String _getDateKey(DateTime dt) {
    final localDt = dt.isUtc ? dt.toLocal() : dt;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(localDt.year, localDt.month, localDt.day);
    
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${localDt.day} ${months[localDt.month - 1]} ${localDt.year}';
  }

  List<dynamic> _buildListItems() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    var list = _reminders.where((r) {
      final localDt = r.scheduledTime.isUtc ? r.scheduledTime.toLocal() : r.scheduledTime;
      if (_selectedCalendarDate != null && _mainTab == 1) {
        final sel = _selectedCalendarDate!;
        if (localDt.year != sel.year || localDt.month != sel.month || localDt.day != sel.day) {
          return false;
        }
      }
      if (_subTab == 'today') {
        return localDt.year == todayStart.year && localDt.month == todayStart.month && localDt.day == todayStart.day;
      } else if (_subTab == 'done') {
        return !r.isActive;
      }
      return true;
    }).toList();

    if (_subTab == 'today') {
      final active = list.where((r) => r.isActive).toList()
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      final completed = list.where((r) => !r.isActive).toList()
        ..sort((a, b) => (b.lastCompleted ?? b.scheduledTime).compareTo(a.lastCompleted ?? a.scheduledTime));
      
      final List<dynamic> items = [];
      if (active.isNotEmpty) {
        items.add('In progress');
        items.addAll(active);
      }
      if (completed.isNotEmpty) {
        items.add('Completed');
        items.addAll(completed);
      }
      return items;
    } else if (_subTab == 'done') {
      final completed = List<Reminder>.from(list.where((r) => !r.isActive))
        ..sort((a, b) => (b.lastCompleted ?? b.scheduledTime).compareTo(a.lastCompleted ?? a.scheduledTime));
      
      final Map<String, List<Reminder>> groups = {};
      for (var r in completed) {
        final key = _getDateKey(r.lastCompleted ?? r.scheduledTime);
        groups.putIfAbsent(key, () => []).add(r);
      }
      final List<dynamic> items = [];
      groups.forEach((dateKey, reminders) {
        items.add(dateKey);
        items.addAll(reminders);
      });
      return items;
    } else {
      final active = list.where((r) => r.isActive).toList()
        ..sort((a, b) {
          final diffA = a.scheduledTime.difference(now).abs();
          final diffB = b.scheduledTime.difference(now).abs();
          return diffA.compareTo(diffB);
        });
      final completed = list.where((r) => !r.isActive).toList()
        ..sort((a, b) => (b.lastCompleted ?? b.scheduledTime).compareTo(a.lastCompleted ?? a.scheduledTime));

      final List<dynamic> items = [];
      if (active.isNotEmpty) {
        items.add('To do');
        items.addAll(active);
      }
      if (completed.isNotEmpty) {
        items.add('Completed');
        items.addAll(completed);
      }
      return items;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final listItems = _buildListItems();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Area
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: cs.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatHeaderDate(DateTime.now()),
                        style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 24),
                        onPressed: _loadReminders,
                        tooltip: 'Refresh',
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 26),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettingsScreen(
                                onSettingsChanged: () {
                                  widget.onSettingsChanged();
                                  _loadReminders();
                                },
                              ),
                            ),
                          );
                        },
                        tooltip: 'Settings',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Tabs: Remainders & Calendar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(child: _mainTabButton('Remainders', 0, cs)),
                    Expanded(child: _mainTabButton('Calendar', 1, cs)),
                  ],
                ),
              ),
            ),

            // Sub-tabs for Remainders (All, Today, Done)
            if (_mainTab == 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    _subTabChip('Today', 'today', cs),
                    const SizedBox(width: 8),
                    _subTabChip('All', 'all', cs),
                    const SizedBox(width: 8),
                    _subTabChip('Done', 'done', cs),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 4),

            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _mainTab == 1
                      ? _buildCalendarView(cs)
                      : listItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.task_alt_rounded, size: 64, color: _accentColor.withOpacity(0.3)),
                                  const SizedBox(height: 12),
                                  Text('No reminders found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                              itemCount: listItems.length,
                              itemBuilder: (context, index) {
                                final item = listItems[index];
                                if (item is String) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                                    child: Text(
                                      item,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _accentColor),
                                    ),
                                  );
                                } else if (item is Reminder) {
                                  return _buildReminderCard(item, cs);
                                }
                                return const SizedBox.shrink();
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        backgroundColor: _accentColor,
        foregroundColor: cs.onPrimary,
        elevation: 4,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _mainTabButton(String label, int index, ColorScheme cs) {
    final selected = _mainTab == index;
    return InkWell(
      onTap: () => setState(() {
        _mainTab = index;
        if (index == 1) _selectedCalendarDate = DateTime.now();
      }),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: selected ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _subTabChip(String label, String value, ColorScheme cs) {
    final selected = _subTab == value;
    return InkWell(
      onTap: () => setState(() => _subTab = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _accentColor : cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderCard(Reminder r, ColorScheme cs) {
    final customColorVal = SettingsService.instance.fontColorValue;
    final cardBg = customColorVal != 0 
        ? Color(customColorVal).withOpacity(0.12) 
        : cs.surfaceContainerLow;
    final borderColor = customColorVal != 0 
        ? Color(customColorVal).withOpacity(0.35) 
        : cs.outlineVariant.withOpacity(0.4);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UpliftReminderDetailScreen(
                  reminder: r,
                  onChanged: () => _loadReminders(),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Left vertical indicator bar
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: r.priority == ReminderPriority.high ? Colors.redAccent : _accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                // Checkbox
                InkWell(
                  onTap: () async {
                    if (r.isActive) {
                      await _service.completeReminder(r.id, fallbackReminder: r);
                    } else {
                      final updated = Reminder(
                        id: r.id,
                        title: r.title,
                        body: r.body,
                        scheduledTime: r.scheduledTime,
                        repeatFrequency: r.repeatFrequency,
                        isActive: true,
                        priority: r.priority,
                        customInterval: r.customInterval,
                        customUnit: r.customUnit,
                        uiType: r.uiType,
                      );
                      await _service.scheduleReminder(updated);
                    }
                    await _loadReminders();
                  },
                  child: Icon(
                    r.isActive ? Icons.radio_button_unchecked_rounded : Icons.check_circle_rounded,
                    color: r.isActive ? Colors.grey : Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Title and time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          decoration: r.isActive ? null : TextDecoration.lineThrough,
                          color: r.isActive ? cs.onSurface : cs.onSurface.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        SettingsService.instance.formatDateTime(r.scheduledTime),
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: r.isActive ? _accentColor.withOpacity(0.15) : const Color(0xFF800000).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    r.isActive ? 'Active' : 'Done',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: r.isActive ? _accentColor : const Color(0xFF800000),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarView(ColorScheme cs) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final year = _calendarFocusDate.year;
    final month = _calendarFocusDate.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    int startingWeekday = firstDayOfMonth.weekday - 1; // 0 for Monday

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 8),
        // Month header & navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => setState(() => _calendarFocusDate = DateTime(year, month - 1, 1)),
            ),
            Text(
              '${months[month - 1]} $year',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => setState(() => _calendarFocusDate = DateTime(year, month + 1, 1)),
            ),
          ],
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _calendarFocusDate = DateTime.now();
              _selectedCalendarDate = DateTime.now();
            }),
            child: Text('Jump to today', style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        // Weekdays header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekdays.map((w) => Text(w, style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurfaceVariant))).toList(),
        ),
        const SizedBox(height: 12),
        // Days Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: startingWeekday + daysInMonth,
          itemBuilder: (context, index) {
            if (index < startingWeekday) {
              return const SizedBox.shrink();
            }
            final dayNum = index - startingWeekday + 1;
            final date = DateTime(year, month, dayNum);
            final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
            final isSelected = _selectedCalendarDate != null && date.year == _selectedCalendarDate!.year && date.month == _selectedCalendarDate!.month && date.day == _selectedCalendarDate!.day;
            final hasReminders = _reminders.any((r) {
              final dt = r.scheduledTime.isUtc ? r.scheduledTime.toLocal() : r.scheduledTime;
              return dt.year == date.year && dt.month == date.month && dt.day == date.day;
            });

            return InkWell(
              onTap: () => setState(() => _selectedCalendarDate = date),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? _accentColor : (isToday ? _accentColor.withOpacity(0.2) : Colors.transparent),
                  borderRadius: BorderRadius.circular(16),
                  border: isToday && !isSelected ? Border.all(color: _accentColor) : null,
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNum',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? cs.onPrimary : cs.onSurface,
                      ),
                    ),
                    if (hasReminders) ...[
                      const SizedBox(height: 2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected ? cs.onPrimary : _accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAddSheet(BuildContext context, {Reminder? initial}) {
    if (initial != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UpliftFullAddScreen(
            initialReminder: initial,
            onAdd: (reminder) async {
              await _service.scheduleReminder(reminder);
              await _loadReminders();
              setState(() {});
            },
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => UpliftQuickAddSheet(
          onAdd: (reminder) async {
            await _service.scheduleReminder(reminder);
            await _loadReminders();
            setState(() {});
          },
        ),
      );
    }
  }
}
