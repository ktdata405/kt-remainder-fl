import 'package:flutter/material.dart';

import '../remainder/reminder_model.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.onSettingsChanged});

  /// Called when settings that affect the root app (URL, theme) change.
  final VoidCallback onSettingsChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final sectionBg = isDark ? const Color(0xFF163B38) : Colors.white;
    final pageBg = isDark ? const Color(0xFF0D2A28) : const Color(0xFFF2FBFA);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 26)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          _SectionHeader(label: 'Appearance', icon: Icons.palette_rounded, color: const Color(0xFF8B5CF6)),
          _SettingsGroup(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('System')),
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                    ],
                    selected: {_settings.themeMode},
                    onSelectionChanged: (selection) async {
                      await _settings.setThemeMode(selection.first);
                      setState(() {});
                      widget.onSettingsChanged();
                    },
                  ),
                ],
              ),
            ),
            backgroundColor: sectionBg,
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            backgroundColor: sectionBg,
            child: _SwitchTile(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFFE58D2B),
              title: '24-hour time format',
              subtitle: _settings.use24hFormat ? 'Showing 14:30' : 'Showing 2:30 PM',
              value: _settings.use24hFormat,
              onChanged: (v) async {
                await _settings.setUse24hFormat(v);
                setState(() {});
              },
            ),
          ),

          const SizedBox(height: 16),
          _SectionHeader(label: 'Reminders', icon: Icons.notifications_rounded, color: const Color(0xFF3B82F6)),
          _SettingsGroup(
            backgroundColor: sectionBg,
            child: _SwitchTile(
              icon: Icons.visibility_rounded,
              iconColor: const Color(0xFF64748B),
              title: 'Show cancelled reminders',
              subtitle: 'Display cancelled items in the list',
              value: _settings.showCancelledReminders,
              onChanged: (v) async {
                await _settings.setShowCancelledReminders(v);
                setState(() {});
                widget.onSettingsChanged();
              },
            ),
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            backgroundColor: sectionBg,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormHead(
                    icon: Icons.repeat_rounded,
                    iconColor: const Color(0xFF4F46E5),
                    title: 'Default repeat frequency',
                    subtitle: 'Pre-selected when adding reminders',
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<RepeatFrequency>(
                    value: _settings.defaultRepeat,
                    borderRadius: BorderRadius.circular(14),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: RepeatFrequency.none, child: Text('No repeat')),
                      DropdownMenuItem(value: RepeatFrequency.daily, child: Text('Daily')),
                      DropdownMenuItem(value: RepeatFrequency.weekly, child: Text('Weekly')),
                      DropdownMenuItem(value: RepeatFrequency.monthly, child: Text('Monthly')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await _settings.setDefaultRepeat(v);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            backgroundColor: sectionBg,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormHead(
                    icon: Icons.alarm_rounded,
                    iconColor: const Color(0xFF19A796),
                    title: 'Advance alert',
                    subtitle: _settings.defaultLeadMinutes == 0
                        ? 'Notify exactly at scheduled time'
                        : 'Also notify ${_settings.defaultLeadMinutes} min before',
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: _settings.defaultLeadMinutes,
                    borderRadius: BorderRadius.circular(14),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('At scheduled time')),
                      DropdownMenuItem(value: 5, child: Text('5 minutes before')),
                      DropdownMenuItem(value: 10, child: Text('10 minutes before')),
                      DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                      DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                      DropdownMenuItem(value: 60, child: Text('1 hour before')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await _settings.setDefaultLeadMinutes(v);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          _SectionHeader(label: 'About', icon: Icons.info_rounded, color: const Color(0xFF64748B)),
          _SettingsGroup(
            backgroundColor: sectionBg,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.apps_rounded,
                  iconColor: const Color(0xFF19A796),
                  title: 'Reminders',
                  subtitle: 'Version 1.0.0  •  Flutter + Google Apps Script',
                  onTap: null,
                ),
                Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.35)),
                _SettingsTile(
                  icon: Icons.description_rounded,
                  iconColor: const Color(0xFF0EA5E9),
                  title: 'How to set up',
                  subtitle: 'Deploy scripts/apps_script.gs as a Web App, then keep URL in app_config.dart',
                  onTap: null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.child, required this.backgroundColor});
  final Widget child;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FormHead extends StatelessWidget {
  const _FormHead({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.58),
                      )),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(title,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: subtitleColor ?? cs.onSurface.withValues(alpha: 0.55)),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(title,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurface.withValues(alpha: 0.55))),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}



