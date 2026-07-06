import 'package:flutter/material.dart';

import '../core/theme/tajgo_colors.dart';

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: TajGoColors.muted)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: TajGoColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
