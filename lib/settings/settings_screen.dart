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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
      ),
      body: ListView(
        children: [

          // ── Appearance ─────────────────────────────────────────────────────
          _SectionHeader(label: 'Appearance', icon: Icons.palette_rounded, color: Colors.purple),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {_settings.themeMode},
                  onSelectionChanged: (selection) async {
                    await _settings.setThemeMode(selection.first);
                    setState(() {});
                    widget.onSettingsChanged();
                  },
                  style: ButtonStyle(
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          _SwitchTile(
            icon: Icons.access_time_rounded,
            iconColor: Colors.orange,
            title: '24-hour time format',
            subtitle: _settings.use24hFormat ? 'Showing 14:30' : 'Showing 2:30 PM',
            value: _settings.use24hFormat,
            onChanged: (v) async {
              await _settings.setUse24hFormat(v);
              setState(() {});
            },
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // ── Reminders ──────────────────────────────────────────────────────
          _SectionHeader(label: 'Reminders', icon: Icons.notifications_rounded, color: Colors.indigo),

          _SwitchTile(
            icon: Icons.visibility_rounded,
            iconColor: Colors.blueGrey,
            title: 'Show cancelled reminders',
            subtitle: 'Display crossed-out cancelled items in the list',
            value: _settings.showCancelledReminders,
            onChanged: (v) async {
              await _settings.setShowCancelledReminders(v);
              setState(() {});
              widget.onSettingsChanged();
            },
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.repeat_rounded, size: 20, color: Colors.indigo),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Default repeat frequency',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600)),
                          Text('Pre-selected when adding a new reminder',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.55))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<RepeatFrequency>(
                  value: _settings.defaultRepeat,
                  borderRadius: BorderRadius.circular(14),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: RepeatFrequency.none,    child: Text('🔔  No repeat')),
                    DropdownMenuItem(value: RepeatFrequency.daily,   child: Text('📅  Daily')),
                    DropdownMenuItem(value: RepeatFrequency.weekly,  child: Text('📆  Weekly')),
                    DropdownMenuItem(value: RepeatFrequency.monthly, child: Text('🗓  Monthly')),
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

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.alarm_rounded, size: 20, color: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Advance alert',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600)),
                          Text(
                            _settings.defaultLeadMinutes == 0
                                ? 'Notify exactly at scheduled time'
                                : 'Also notify ${_settings.defaultLeadMinutes} min before',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.55)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: _settings.defaultLeadMinutes,
                  borderRadius: BorderRadius.circular(14),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0,  child: Text('At scheduled time')),
                    DropdownMenuItem(value: 5,  child: Text('5 minutes before')),
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

          const Divider(height: 1, indent: 16, endIndent: 16),


          // ── About ──────────────────────────────────────────────────────────
          _SectionHeader(label: 'About', icon: Icons.info_rounded, color: Colors.blueGrey),

          _SettingsTile(
            icon: Icons.apps_rounded,
            iconColor: cs.primary,
            title: 'Reminders',
            subtitle: 'Version 1.0.0  •  Flutter + Google Apps Script',
            onTap: null,
          ),

          _SettingsTile(
            icon: Icons.description_rounded,
            iconColor: Colors.teal,
            title: 'How to set up',
            subtitle: 'Deploy scripts/apps_script.gs as a Web App, then paste the URL in Connection above',
            onTap: null,
          ),

          const SizedBox(height: 40),
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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



