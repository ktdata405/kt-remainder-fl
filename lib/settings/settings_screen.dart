import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;

import '../config/app_config.dart';
import '../remainder/reminder_model.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.onSettingsChanged});
  final VoidCallback onSettingsChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService.instance;

  final List<int> _colors = [
    0, 0xFF000000, 0xFFFFFFFF, 0xFF4F46E5, 0xFF0D9488, 0xFFEF4444, 0xFFF59E0B, 
    0xFF10B981, 0xFF3B82F6, 0xFF6366F1, 0xFF8B5CF6, 0xFFEC4899, 0xFFF43F5E, 
    0xFFD946EF, 0xFF06B6D4, 0xFF84CC16, 0xFFEAB308, 0xFFF97316, 0xFF71717A, 
    0xFF64748B, 0xFF78350F, 0xFF1E3A8A, 0xFF064E3B, 0xFF7F1D1D, 0xFF4C1D95, 
    0xFF831843, 0xFF164E63, 0xFF365314, 0xFF713F12, 0xFF0F172A, 0xFF431407, 
    0xFF171717,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sectionBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const _SectionHeader(label: 'Appearance', icon: Icons.palette_outlined, color: Colors.indigo),
          _Group(
            backgroundColor: sectionBg,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Theme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 12),
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
                _SwitchTile(
                  icon: Icons.access_time,
                  title: '24-hour Format',
                  value: _settings.use24hFormat,
                  onChanged: (v) async {
                    await _settings.setUse24hFormat(v);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _Group(
            backgroundColor: sectionBg,
            child: ExpansionTile(
              initiallyExpanded: false,
              leading: const Icon(Icons.text_fields, color: Colors.blue),
              title: const Text('Typography', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              children: [
                _FontSettingRow(
                  label: 'Titles',
                  size: _settings.fontSizeTitle,
                  style: _settings.fontStyleTitle,
                  onSizeChanged: (v) async { await _settings.setFontSizeTitle(v); setState(() {}); widget.onSettingsChanged(); },
                  onStyleChanged: (v) async { if (v != null) await _settings.setFontStyleTitle(v); setState(() {}); widget.onSettingsChanged(); },
                ),
                const Divider(height: 1),
                _FontSettingRow(
                  label: 'Descriptions',
                  size: _settings.fontSizeBody,
                  style: _settings.fontStyleBody,
                  onSizeChanged: (v) async { await _settings.setFontSizeBody(v); setState(() {}); widget.onSettingsChanged(); },
                  onStyleChanged: (v) async { if (v != null) await _settings.setFontStyleBody(v); setState(() {}); widget.onSettingsChanged(); },
                ),
                const Divider(height: 1),
                _FontSettingRow(
                  label: 'Labels',
                  size: _settings.fontSizeLabel,
                  style: _settings.fontStyleLabel,
                  onSizeChanged: (v) async { await _settings.setFontSizeLabel(v); setState(() {}); widget.onSettingsChanged(); },
                  onStyleChanged: (v) async { if (v != null) await _settings.setFontStyleLabel(v); setState(() {}); widget.onSettingsChanged(); },
                ),
                const Divider(height: 1),
                _ColorPicker(
                  label: 'Title Font Color',
                  selectedColor: _settings.fontColorTitle,
                  colors: _colors,
                  onColorSelected: (c) async {
                    await _settings.setFontColorTitle(c);
                    setState(() {});
                    widget.onSettingsChanged();
                  },
                ),
                const Divider(height: 1),
                _ColorPicker(
                  label: 'Other Text Color',
                  selectedColor: _settings.fontColorValue,
                  colors: _colors,
                  onColorSelected: (c) async {
                    await _settings.setFontColor(c);
                    setState(() {});
                    widget.onSettingsChanged();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const _SectionHeader(label: 'Reminders', icon: Icons.notifications_active_outlined, color: Colors.teal),
          _Group(
            backgroundColor: sectionBg,
            child: Column(
              children: [
                _SwitchTile(
                  icon: Icons.visibility_off_outlined,
                  title: 'Show Completed',
                  value: _settings.showCancelledReminders,
                  onChanged: (v) async {
                    await _settings.setShowCancelledReminders(v);
                    setState(() {});
                    widget.onSettingsChanged();
                  },
                ),
                _SwitchTile(
                  icon: Icons.storage_rounded,
                  title: 'Save & Sync Data',
                  value: _settings.useLocalStorage,
                  onChanged: (v) async {
                    await _settings.setUseLocalStorage(v);
                    setState(() {});
                    widget.onSettingsChanged();
                  },
                ),
                _DropdownTile<RepeatFrequency>(
                  label: 'Default Repeat',
                  value: _settings.defaultRepeat,
                  items: RepeatFrequency.values.map((f) => DropdownMenuItem(value: f, child: Text(f.name.capitalize()))).toList(),
                  onChanged: (v) async {
                    if (v != null) await _settings.setDefaultRepeat(v);
                    setState(() {});
                  },
                ),
                _DropdownTile<int>(
                  label: 'Advance Alert',
                  value: _settings.defaultLeadMinutes,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('At scheduled time')),
                    DropdownMenuItem(value: 5, child: Text('5 minutes before')),
                    DropdownMenuItem(value: 10, child: Text('10 minutes before')),
                    DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                    DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                    DropdownMenuItem(value: 60, child: Text('1 hour before')),
                  ],
                  onChanged: (v) async {
                    if (v != null) await _settings.setDefaultLeadMinutes(v);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const _SectionHeader(label: 'About', icon: Icons.info_outline, color: Colors.grey),
          _Group(
            backgroundColor: sectionBg,
            child: Column(
              children: [
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.hasData 
                        ? "${snapshot.data!.version}+${snapshot.data!.buildNumber}" 
                        : "Loading...";
                    return ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('App Version', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      trailing: Text(version, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    );
                  }
                ),
                const Divider(height: 1),
                _LinkTile(
                  title: 'Google Sheet Sync',
                  subtitle: 'Open the source Google Sheet',
                  icon: Icons.table_chart_outlined,
                  url: _settings.webAppUrl,
                ),
                const Divider(height: 1),
                const _LinkTile(
                  title: 'Project Repository',
                  subtitle: 'View source code on GitHub',
                  icon: Icons.code_rounded,
                  url: kRepoUrl,
                ),
                const Divider(height: 1),
                const _LinkTile(
                  title: 'Download Debug APK',
                  subtitle: 'Latest nightly debug build (ZIP)',
                  icon: Icons.bug_report_outlined,
                  url: kNightlyDebug,
                ),
                const Divider(height: 1),
                const _LinkTile(
                  title: 'Download Release APK',
                  subtitle: 'Latest nightly release build (ZIP)',
                  icon: Icons.rocket_launch_outlined,
                  url: kNightlyRelease,
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Version updates automatically with each production build.',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FontSettingRow extends StatelessWidget {
  final String label;
  final double size;
  final String style;
  final ValueChanged<double> onSizeChanged;
  final ValueChanged<String?> onStyleChanged;

  const _FontSettingRow({
    required this.label,
    required this.size,
    required this.style,
    required this.onSizeChanged,
    required this.onStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: style,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'bold', child: Text('Bold')),
                  DropdownMenuItem(value: 'italic', child: Text('Italic')),
                ],
                onChanged: onStyleChanged,
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.format_size, size: 16, color: Colors.grey),
              Expanded(
                child: Slider(
                  value: size,
                  min: 10, max: 24,
                  divisions: 14,
                  onChanged: onSizeChanged,
                ),
              ),
              Text('${size.toInt()} px', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final String label;
  final int selectedColor;
  final List<int> colors;
  final ValueChanged<int> onColorSelected;

  const _ColorPicker({
    required this.label,
    required this.selectedColor,
    required this.colors,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((c) {
              final isSel = selectedColor == c;
              if (c == 0) {
                return InkWell(
                  onTap: () => onColorSelected(0),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: isSel ? Colors.blue : Colors.black12, width: 2),
                    ),
                    child: Center(
                      child: Text('D', style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold, 
                        color: isSel ? Colors.blue : Colors.grey
                      )),
                    ),
                  ),
                );
              }
              return InkWell(
                onTap: () => onColorSelected(c),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? (c == 0xFFFFFFFF ? Colors.black26 : Colors.white) : Colors.black12, 
                      width: 2
                    ),
                    boxShadow: isSel ? const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))] : null,
                  ),
                  child: isSel ? Icon(Icons.check, color: c == 0xFFFFFFFF ? Colors.black : Colors.white, size: 14) : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final Widget child; final Color backgroundColor;
  const _Group({required this.child, required this.backgroundColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.grey.withOpacity(0.1))
      ), 
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child)
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label; final IconData icon; final Color color;
  const _SectionHeader({required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 12), 
      child: Row(
        children: [
          Icon(icon, size: 18, color: color), 
          const SizedBox(width: 8), 
          Text(label.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: color, letterSpacing: 1))
        ]
      )
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon; final String title; final bool value; final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.icon, required this.title, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20), 
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), 
      trailing: Switch(value: value, onChanged: onChanged)
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  final String label; final T value; final List<DropdownMenuItem<T>> items; final ValueChanged<T?> onChanged;
  const _DropdownTile({required this.label, required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), 
      trailing: DropdownButtonHideUnderline(child: DropdownButton<T>(value: value, items: items, onChanged: onChanged))
    );
  }
}

extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
}

class _LinkTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String url;

  const _LinkTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.url,
  });

  Future<void> _launch(BuildContext context, {bool forceChrome = false}) async {
    if (url.isEmpty) return;
    
    try {
      Uri uri = Uri.parse(url);
      
      // If forcing Chrome on Android
      if (forceChrome && !kIsWeb && Platform.isAndroid) {
        // Option 1: Using intent scheme directly
        // intent://...#Intent;scheme=https;package=com.android.chrome;end
        final intentUrl = 'intent://${uri.host}${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}#Intent;scheme=${uri.scheme};package=com.android.chrome;end';
        uri = Uri.parse(intentUrl);
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch browser')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.grey),
      onTap: () => _launch(context),
      onLongPress: () => _launch(context, forceChrome: true),
    );
  }
}
