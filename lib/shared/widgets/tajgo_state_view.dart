import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';

/// Scrollable feedback also works above a keyboard and with large text.
class TajGoStateView extends StatelessWidget {
  const TajGoStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
    this.actionLabel = 'Попробовать снова',
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.hasBoundedHeight
              ? (constraints.maxHeight - 48).clamp(0, double.infinity)
              : 0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: TajGoColors.mint,
                  child: Icon(icon, size: 34, color: TajGoColors.darkGreen),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: TajGoColors.muted),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 20),
                  FilledButton(onPressed: onRetry, child: Text(actionLabel)),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
