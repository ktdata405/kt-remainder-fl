import 'package:flutter/material.dart';

class FetchErrorState extends StatelessWidget {
  const FetchErrorState({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Failed to load tasks'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
