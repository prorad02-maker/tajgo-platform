import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';

class TajGoLogo extends StatelessWidget {
  const TajGoLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'T+',
          style: TextStyle(
            color: TajGoColors.green,
            fontSize: 42,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
