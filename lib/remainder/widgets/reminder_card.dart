import 'package:flutter/material.dart';
import '../reminder_model.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.isBusy,
    this.onTap,
    this.onComplete,
    this.onNotifyNow,
    this.onSnooze,
    this.isReadOnly = false,
  });

  final Reminder reminder;
  final bool isBusy;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onNotifyNow;
  final VoidCallback? onSnooze;
  final bool isReadOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final isOverdue = reminder.isActive && reminder.scheduledTime.isBefore(DateTime.now());
    final isCompleted = !reminder.isActive;
    final priorityColor = _getPriorityColor(reminder.priority);
    final date = reminder.scheduledTime;
    final dateTop = '${_weekdayShort(date.weekday)} ${date.day}';
    final dateBottom = _monthShort(date.month);
    final timeText = TimeOfDay.fromDateTime(date).format(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isReadOnly ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? Colors.red.withValues(alpha: 0.08)
                        : cs.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOverdue
                          ? Colors.red.withValues(alpha: 0.22)
                          : cs.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dateTop,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isOverdue ? Colors.red : cs.primary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateBottom,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: (isOverdue ? Colors.red : cs.primary).withValues(alpha: 0.85),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          timeText,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              reminder.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                                color: isReadOnly ? cs.onSurface.withValues(alpha: 0.55) : null,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          reminder.isActive
                              ? IconButton(
                                  onPressed: isReadOnly ? null : onComplete,
                                  tooltip: 'Complete',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                                  icon: const Icon(Icons.radio_button_unchecked_rounded, size: 19),
                                )
                              : Icon(
                                  Icons.check_circle_rounded,
                                  color: const Color(0xFF10B981).withValues(alpha: isReadOnly ? 0.5 : 1),
                                  size: 20,
                                ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reminder.body.trim().isEmpty ? 'No description' : reminder.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: isReadOnly ? 0.45 : 0.72),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (reminder.repeatFrequency != RepeatFrequency.none)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _repeatLabel(reminder),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          if (reminder.repeatFrequency != RepeatFrequency.none) const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              reminder.priority.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: priorityColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (reminder.isActive && !isBusy && !isReadOnly) ...[
                            IconButton.filledTonal(
                              onPressed: onNotifyNow,
                              tooltip: 'Notify now',
                              style: IconButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                minimumSize: const Size(30, 30),
                                padding: const EdgeInsets.all(6),
                              ),
                              icon: const Icon(Icons.notifications_active_rounded, size: 14),
                            ),
                            const SizedBox(width: 6),
                            FilledButton.tonal(
                              onPressed: onSnooze,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                minimumSize: const Size(0, 30),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.snooze_rounded, size: 12),
                                  SizedBox(width: 3),
                                  Text('Snooze', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (isBusy)
                        Container(
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text('Updating...', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(ReminderPriority priority) {
    return switch (priority) {
      ReminderPriority.high => Colors.red,
      ReminderPriority.medium => Colors.orange,
      ReminderPriority.low => Colors.blue,
    };
  }

  String _repeatLabel(Reminder r) {
    if (r.repeatFrequency == RepeatFrequency.custom) return 'Every ${r.customInterval} ${r.customUnit}';
    if (r.repeatFrequency == RepeatFrequency.weekdays) return 'Weekdays';
    if (r.repeatFrequency == RepeatFrequency.weekends) return 'Weekends';
    return r.repeatFrequency.name[0].toUpperCase() + r.repeatFrequency.name.substring(1);
  }

  String _weekdayShort(int weekday) => switch (weekday) {
    DateTime.monday => 'Mon',
    DateTime.tuesday => 'Tue',
    DateTime.wednesday => 'Wed',
    DateTime.thursday => 'Thu',
    DateTime.friday => 'Fri',
    DateTime.saturday => 'Sat',
    DateTime.sunday => 'Sun',
    _ => 'Day',
  };

  String _monthShort(int month) => switch (month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    12 => 'Dec',
    _ => 'Mon',
  };
}
