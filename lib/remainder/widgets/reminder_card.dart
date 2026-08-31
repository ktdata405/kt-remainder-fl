import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../reminder_model.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.isBusy,
    this.onTap,
    this.onComplete,
    this.onSnooze,
  });

  final Reminder reminder;
  final bool isBusy;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onSnooze;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final isOverdue = reminder.isActive && reminder.scheduledTime.isBefore(DateTime.now());
    final isCompleted = !reminder.isActive;
    final priorityColor = _getPriorityColor(reminder.priority);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: reminder.isActive 
                    ? Radio<bool>(
                        value: true, 
                        groupValue: false, 
                        onChanged: (_) => onComplete?.call(), 
                        activeColor: const Color(0xFF10B981),
                      )
                    : const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOverdue ? Colors.red.withOpacity(0.1) : cs.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isOverdue ? Colors.red.withOpacity(0.2) : cs.primary.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_filled_rounded, 
                              size: 12, 
                              color: isOverdue ? Colors.red : cs.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              SettingsService.instance.formatDateTime(reminder.scheduledTime),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: isOverdue ? Colors.red : cs.primary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (reminder.repeatFrequency != RepeatFrequency.none) ...[
                            Icon(_repeatIcon(reminder.repeatFrequency), size: 10, color: cs.primary.withOpacity(0.7)),
                            const SizedBox(width: 4),
                            Text(_repeatLabel(reminder), style: theme.textTheme.bodySmall?.copyWith(fontSize: 9, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.1), 
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              reminder.priority.name.toUpperCase(), 
                              style: TextStyle(
                                fontSize: 8, 
                                fontWeight: FontWeight.w900, 
                                color: priorityColor,
                              ),
                            ),
                          ),
                          if (isOverdue) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1), 
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'OVERDUE', 
                                style: TextStyle(
                                  fontSize: 8, 
                                  fontWeight: FontWeight.w900, 
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (reminder.isActive && !isBusy)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilledButton.tonal(
                      onPressed: onSnooze,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.snooze_rounded, size: 14),
                          SizedBox(width: 4),
                          Text('Snooze', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                        ],
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

  Color _getPriorityColor(ReminderPriority priority) {
    return switch (priority) {
      ReminderPriority.high => Colors.red,
      ReminderPriority.medium => Colors.orange,
      ReminderPriority.low => Colors.blue,
    };
  }

  IconData _repeatIcon(RepeatFrequency f) => switch (f) {
    RepeatFrequency.daily => Icons.today_rounded,
    RepeatFrequency.weekly => Icons.date_range_rounded,
    RepeatFrequency.monthly => Icons.calendar_month_rounded,
    RepeatFrequency.weekdays => Icons.work_outline_rounded,
    RepeatFrequency.yearly => Icons.event_available_rounded,
    RepeatFrequency.custom => Icons.tune_rounded,
    _ => Icons.notifications_none_rounded,
  };

  String _repeatLabel(Reminder r) {
    if (r.repeatFrequency == RepeatFrequency.custom) return 'Every ${r.customInterval} ${r.customUnit}';
    if (r.repeatFrequency == RepeatFrequency.weekdays) return 'Weekdays';
    if (r.repeatFrequency == RepeatFrequency.weekends) return 'Weekends';
    return r.repeatFrequency.name[0].toUpperCase() + r.repeatFrequency.name.substring(1);
  }
}
