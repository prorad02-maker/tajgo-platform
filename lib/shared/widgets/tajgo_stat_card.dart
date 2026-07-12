import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';

class TajGoStatCard extends StatelessWidget {
  const TajGoStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: TajGoColors.muted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}
