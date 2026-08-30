import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.onAdd});
  
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.all(20),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _EmptyIconRow(color: Color(0xFFF97316)),
                _EmptyIconRow(color: Color(0xFF3B82F6)),
                _EmptyIconRow(color: Color(0xFF22C55E)),
                _EmptyIconRow(color: Color(0xFFA855F7)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('All clear!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('No active reminders found.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onAdd, child: const Text('Add Task')),
        ],
      ),
    );
  }
}

class _EmptyIconRow extends StatelessWidget {
  const _EmptyIconRow({required this.color});
  
  final Color color;
  
  @override
  Widget build(BuildContext context) { 
    return Row(
      children: [
        Container(
          width: 16, 
          height: 16, 
          decoration: BoxDecoration(
            color: color, 
            shape: BoxShape.circle, 
            border: Border.all(color: Colors.white, width: 2),
          ),
        ), 
        const SizedBox(width: 16), 
        Expanded(
          child: Container(
            height: 3, 
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.25), 
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    ); 
  }
}
