import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';

/// Заголовок статуса + необязательный подзаголовок.
/// Используется на экране отслеживания и в карточках статусов.
class TajGoStatusHeader extends StatelessWidget {
  const TajGoStatusHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle!, style: const TextStyle(color: TajGoColors.muted)),
      ],
    ],
  );
}
