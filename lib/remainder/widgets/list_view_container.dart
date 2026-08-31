import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../settings/settings_screen.dart';
import '../reminder_model.dart';
import 'reminder_card.dart';
import 'add_reminder_sheet.dart';
import 'empty_state.dart';
import 'fetch_error_state.dart';

enum TaskFilter { all, pending, ongoing, completed }

class ListViewContainer extends StatefulWidget {
  const ListViewContainer({
    super.key,
    required this.reminders,
    required this.isReloading,
    required this.busyReminderIds,
    this.fetchError,
    required this.onRefresh,
    required this.onCancel,
    required this.onComplete,
    required this.onSnooze,
    required this.onAdd,
    required this.onEdit,
    required this.onToggleTheme,
    required this.onOpenSettings,
    required this.isDark,
    required this.onSettingsChanged,
  });

  final List<Reminder> reminders;
  final bool isReloading;
  final Set<int> busyReminderIds;
  final String? fetchError;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int) onCancel;
  final Future<void> Function(int) onComplete;
  final Future<void> Function(Reminder) onSnooze;
  final Future<void> Function(Reminder) onAdd;
  final Future<void> Function(Reminder) onEdit;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenSettings;
  final bool isDark;
  final VoidCallback onSettingsChanged;

  @override
  State<ListViewContainer> createState() => _ListViewContainerState();
}

class _ListViewContainerState extends State<ListViewContainer> {
  TaskFilter _filter = TaskFilter.pending;
  int _currentIndex = 0;

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddReminderSheet(onAdd: widget.onAdd),
    );
  }

  void _openEditSheet(BuildContext context, Reminder r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddReminderSheet(onAdd: widget.onEdit, initialReminder: r),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showAll = SettingsService.instance.showCancelledReminders;
    
    // Optimization: Filter logic outside of build if possible, but for small lists it's okay.
    // However, we can use memoization or move it to a method to keep build clean.
    final visible = _getVisibleReminders(showAll);
    final today = DateTime.now();
    final todayTasks = visible.where((r) => r.isActive && _isSameDay(r.scheduledTime, today)).toList();
    final upcomingTasks = visible.where((r) => r.isActive && r.scheduledTime.isAfter(DateTime(today.year, today.month, today.day, 23, 59))).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, cs, visible.length),
            Expanded(
              child: RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: widget.fetchError != null 
                  ? FetchErrorState(error: widget.fetchError!, onRetry: widget.onRefresh)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      children: [
                        if (_filter == TaskFilter.pending) ...[
                          if (todayTasks.isNotEmpty) ...[
                            const _SectionHeader(title: 'Today Remainders'),
                            ...todayTasks.map(_reminderItem),
                            const SizedBox(height: 24),
                          ],
                          if (upcomingTasks.isNotEmpty) ...[
                            const _SectionHeader(title: 'Upcoming Remainders'),
                            ...upcomingTasks.map(_reminderItem),
                          ],
                          if (todayTasks.isEmpty && upcomingTasks.isEmpty) 
                            EmptyState(onAdd: () => _openAddSheet(context)),
                        ] else ...[
                          if (visible.isEmpty) EmptyState(onAdd: () => _openAddSheet(context)),
                          ...visible.map(_reminderItem),
                        ],
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  List<Reminder> _getVisibleReminders(bool showAll) {
    var visible = widget.reminders;
    if (!showAll) {
      visible = visible.where((r) => r.isActive).toList();
    }
    
    if (_filter == TaskFilter.ongoing) {
      final now = DateTime.now();
      visible = visible.where((r) => r.isActive && r.scheduledTime.isBefore(now)).toList();
    } else if (_filter == TaskFilter.completed) {
      visible = visible.where((r) => !r.isActive).toList();
    }
    return visible;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remainder', 
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900, 
                  letterSpacing: -1,
                ),
              ),
              Text(
                '$count tasks', 
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton.filledTonal(
            onPressed: widget.isReloading ? null : widget.onRefresh,
            icon: widget.isReloading 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: widget.onToggleTheme, 
            icon: Icon(widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          ),
        ],
      ),
    );
  }

  Widget _reminderItem(Reminder r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ReminderCard(
        reminder: r,
        isBusy: widget.busyReminderIds.contains(r.id),
        onTap: () => _openEditSheet(context, r),
        onComplete: () => widget.onComplete(r.id),
        onSnooze: () => widget.onSnooze(r),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface, 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), 
            blurRadius: 20, 
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white, 
          borderRadius: BorderRadius.circular(36), 
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navItem(Icons.calendar_today_rounded, 0, TaskFilter.pending),
            _navItem(Icons.grid_view_rounded, 1, TaskFilter.all),
            _navItem(Icons.add_rounded, 2, null, isFab: true),
            _navItem(Icons.alarm_on_rounded, 3, TaskFilter.ongoing),
            _navItem(Icons.settings_outlined, 4, null),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index, TaskFilter? filter, {bool isFab = false}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSelected = _currentIndex == index;
    if (isFab) {
      return GestureDetector(
        onTap: () => _openAddSheet(context),
        child: Container(
          width: 52, 
          height: 52, 
          decoration: BoxDecoration(
            color: cs.primary, 
            shape: BoxShape.circle, 
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.3), 
                blurRadius: 12, 
                offset: const Offset(0, 4),
              ),
            ],
          ), 
          child: Icon(icon, color: cs.onPrimary, size: 28),
        ),
      );
    }
    return InkWell(
      onTap: () {
        if (index == 4) { 
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (_) => SettingsScreen(onSettingsChanged: widget.onSettingsChanged)),
          ).then((_) => widget.onRefresh());
        }
        else if (filter != null) { 
          setState(() { 
            _currentIndex = index; 
            _filter = filter; 
          }); 
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), 
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
        child: Icon(
          icon, 
          color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.35), 
          size: 26,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title, 
        style: TextStyle(
          fontWeight: FontWeight.w900, 
          fontSize: 12, 
          color: Theme.of(context).colorScheme.primary, 
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
