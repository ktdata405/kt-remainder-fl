import 'package:flutter/material.dart';
import '../iphone_reminder_model.dart';
import '../iphone_reminder_service.dart';

class IphoneAddListSheet extends StatefulWidget {
  const IphoneAddListSheet({super.key, required this.onListAdded});
  final VoidCallback onListAdded;

  @override
  State<IphoneAddListSheet> createState() => _IphoneAddListSheetState();
}

class _IphoneAddListSheetState extends State<IphoneAddListSheet> {
  final TextEditingController _nameController = TextEditingController();
  Color _selectedColor = const Color(0xFF007AFF);
  IconData _selectedIcon = Icons.list_rounded;

  final List<Color> _colors = [
    const Color(0xFFFF3B30),
    const Color(0xFFFF9500),
    const Color(0xFFFFCC00),
    const Color(0xFF34C759),
    const Color(0xFF5AC8FA),
    const Color(0xFF007AFF),
    const Color(0xFF5856D6),
    const Color(0xFFFF2D55),
    const Color(0xFFA2845E),
    const Color(0xFF8E8E93),
  ];

  final List<IconData> _icons = [
    Icons.list_rounded,
    Icons.star_rounded,
    Icons.bookmark_rounded,
    Icons.work_rounded,
    Icons.home_rounded,
    Icons.person_rounded,
    Icons.shopping_bag_rounded,
    Icons.favorite_rounded,
    Icons.flag_rounded,
    Icons.flight_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF007AFF), fontSize: 16)),
              ),
              const Text('New List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              TextButton(
                onPressed: () async {
                  final name = _nameController.text.trim();
                  if (name.isNotEmpty) {
                    await IphoneReminderService.instance.addCustomList(
                      ReminderListInfo(name: name, color: _selectedColor, icon: _selectedIcon),
                    );
                    widget.onListAdded();
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Done', style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(_selectedIcon, size: 48, color: _selectedColor),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _nameController,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'List Name',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: _colors.map((c) {
              final isSel = _selectedColor == c;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = c),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                    boxShadow: isSel ? [const BoxShadow(color: Colors.black26, blurRadius: 4)] : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _icons.map((ic) {
              final isSel = _selectedIcon == ic;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = ic),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSel ? _selectedColor.withValues(alpha: 0.2) : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: isSel ? Border.all(color: _selectedColor, width: 2) : null,
                  ),
                  child: Icon(ic, color: isSel ? _selectedColor : (isDark ? Colors.white70 : Colors.black87), size: 24),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
