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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF087044), Color(0xFF064B2D)],
        ),
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.16),
      child: CustomPaint(painter: const _TajGoFallbackMarkPainter()),
    );
  }
}

class _TajGoFallbackMarkPainter extends CustomPainter {
  const _TajGoFallbackMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.095
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final lime = Paint()
      ..color = TajGoColors.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final mountain = Path()
      ..moveTo(size.width * 0.10, size.height * 0.34)
      ..lineTo(size.width * 0.36, size.height * 0.08)
      ..lineTo(size.width * 0.58, size.height * 0.30)
      ..lineTo(size.width * 0.72, size.height * 0.17)
      ..lineTo(size.width * 0.90, size.height * 0.36);
    canvas.drawPath(mountain, white);

    final route = Path()
      ..moveTo(size.width * 0.22, size.height * 0.84)
      ..cubicTo(
        size.width * 0.37,
        size.height * 0.77,
        size.width * 0.30,
        size.height * 0.56,
        size.width * 0.47,
        size.height * 0.51,
      )
      ..cubicTo(
        size.width * 0.60,
        size.height * 0.47,
        size.width * 0.70,
        size.height * 0.49,
        size.width * 0.84,
        size.height * 0.45,
      );
    canvas.drawPath(route, lime);

    final arrow = Path()
      ..moveTo(size.width * 0.73, size.height * 0.36)
      ..lineTo(size.width * 0.90, size.height * 0.44)
      ..lineTo(size.width * 0.76, size.height * 0.57);
    canvas.drawPath(arrow, lime);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
