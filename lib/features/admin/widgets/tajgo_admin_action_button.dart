import 'package:flutter/material.dart';

import '../../../core/constants/tajgo_colors.dart';

class TajGoAdminActionButton extends StatelessWidget {
  const TajGoAdminActionButton({
    super.key,
    required this.label,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.dangerous = false,
  });

  final String label;
  final String title;
  final String message;
  final Future<void> Function() onConfirm;
  final bool dangerous;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      foregroundColor: dangerous ? TajGoColors.error : TajGoColors.darkGreen,
    ),
    onPressed: () async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Продолжить'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      try {
        await onConfirm();
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Готово')));
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$error')));
        }
      }
    },
    child: Text(label),
  );
}
