import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';

class TajGoStatCard extends StatelessWidget {
  const TajGoStatCard({
    super.key,
    this.icon = '',
    this.iconData,
    required this.value,
    required this.label,
  });

  final String icon;
  final IconData? iconData;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (iconData != null)
            Icon(iconData, size: 24, color: TajGoColors.darkGreen)
          else
            Text(icon, style: const TextStyle(fontSize: 19, height: 1)),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(color: TajGoColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );
}
