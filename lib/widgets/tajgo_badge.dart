import 'package:flutter/material.dart';

import '../core/theme/tajgo_colors.dart';

class TajGoBadge extends StatelessWidget {
  const TajGoBadge({super.key, this.size = 92});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'T+',
          style: TextStyle(
            color: TajGoColors.green,
            fontSize: size * 0.38,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
          ),
        ),
      ),
    );
  }
}
