import 'package:flutter/material.dart';

import '../../core/design/tajgo_design.dart';

/// Заголовок секции с опциональным действием справа («Все», «Смотреть»).
class TajGoSectionHeader extends StatelessWidget {
  const TajGoSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(
      TajGoSpacing.screenH,
      TajGoSpacing.xl,
      TajGoSpacing.screenH,
      TajGoSpacing.sm,
    ),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TajGoTypography.title),
                if (subtitle != null) ...[
                  const SizedBox(height: TajGoSpacing.xxs),
                  Text(subtitle!, style: TajGoTypography.caption),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: TajGoColors.darkGreen,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
