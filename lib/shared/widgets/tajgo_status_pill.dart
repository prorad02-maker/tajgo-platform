import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';

class TajGoStatusPill extends StatelessWidget {
  const TajGoStatusPill({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: online ? TajGoColors.mint : TajGoColors.soonBg,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: online ? TajGoColors.success : TajGoColors.soonText,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          online ? 'На линии' : 'Не на линии',
          style: TextStyle(
            color: online ? TajGoColors.darkGreen : TajGoColors.soonText,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
