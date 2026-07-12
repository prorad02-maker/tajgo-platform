import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../features/customer/customer_home_screen.dart';
import '../../shared/widgets/tajgo_logo.dart';
import '../../shared/widgets/tajgo_scope.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Подключаем TajGo...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final scope = TajGoScope.of(context);
    try {
      setState(() => _status = 'Входим в TajGo...');
      final user = await scope.authService.signInAnonymouslyIfNeeded().timeout(
        const Duration(seconds: 10),
      );
      setState(() => _status = 'Готовим профиль...');
      await scope.userRepository
          .ensureUser(uid: user.uid)
          .timeout(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _status = 'Не получилось подключиться: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final landscapeHeight = constraints.maxHeight * 0.34;
          return Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Color(0xFFFAFCF7)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: landscapeHeight,
                child: CustomPaint(painter: _KhujandLandscapePainter()),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      flex: 66,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const TajGoLogo(size: 116),
                              const SizedBox(height: 20),
                              const Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Taj',
                                      style: TextStyle(
                                        color: Color(0xFF272B2E),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Go',
                                      style: TextStyle(
                                        color: TajGoColors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Проще. Быстрее. Честнее. ',
                                      ),
                                      TextSpan(
                                        text: 'Для своих.',
                                        style: TextStyle(
                                          color: TajGoColors.green,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: TextStyle(
                                    color: Color(0xFF3A4440),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: const SizedBox(
                                  width: 130,
                                  height: 5,
                                  child: LinearProgressIndicator(
                                    color: TajGoColors.green,
                                    backgroundColor: Color(0xFFDFEDD8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _status,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF7C8A80),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Expanded(flex: 34, child: SizedBox()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KhujandLandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mountain = Path()
      ..moveTo(0, size.height * 0.38)
      ..cubicTo(
        size.width * 0.14,
        size.height * 0.08,
        size.width * 0.25,
        size.height * 0.48,
        size.width * 0.40,
        size.height * 0.25,
      )
      ..cubicTo(
        size.width * 0.55,
        size.height * 0.02,
        size.width * 0.70,
        size.height * 0.42,
        size.width,
        size.height * 0.15,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(mountain, Paint()..color = const Color(0xFFE3EEDC));

    canvas.drawCircle(
      Offset(size.width * 0.67, size.height * 0.22),
      size.shortestSide * 0.085,
      Paint()..color = const Color(0xFFF5D97E),
    );

    _paintCity(canvas, size, const Color(0xFF4E9455), size.height * 0.42, 0.82);
    _paintCity(canvas, size, const Color(0xFF3E8447), size.height * 0.52, 1);

    final backHill = Path()
      ..moveTo(0, size.height * 0.62)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.43,
        size.width * 0.48,
        size.height * 0.86,
        size.width,
        size.height * 0.48,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(backHill, Paint()..color = const Color(0xFF2E7C46));

    final frontHill = Path()
      ..moveTo(0, size.height * 0.72)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.58,
        size.width * 0.58,
        size.height * 1.02,
        size.width,
        size.height * 0.66,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(frontHill, Paint()..color = const Color(0xFF1E5C33));

    final road = Path()
      ..moveTo(size.width * 0.52, size.height * 1.04)
      ..cubicTo(
        size.width * 0.31,
        size.height * 0.87,
        size.width * 0.72,
        size.height * 0.75,
        size.width * 0.48,
        size.height * 0.56,
      );
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFF4F9F1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintCity(
    Canvas canvas,
    Size size,
    Color color,
    double baseline,
    double scale,
  ) {
    final paint = Paint()..color = color;
    final buildings = <(double, double, double)>[
      (0.05, 0.10, 0.07),
      (0.16, 0.16, 0.055),
      (0.27, 0.12, 0.10),
      (0.43, 0.20, 0.05),
      (0.57, 0.11, 0.09),
      (0.72, 0.18, 0.055),
      (0.86, 0.13, 0.09),
    ];
    for (final building in buildings) {
      final x = size.width * building.$1;
      final width = size.width * building.$3 * scale;
      final height = size.height * building.$2 * scale;
      canvas.drawRect(
        Rect.fromLTWH(x, baseline - height, width, height),
        paint,
      );
      if (building.$3 < 0.07) {
        canvas.drawRect(
          Rect.fromLTWH(
            x + width * 0.35,
            baseline - height - height * 0.48,
            width * 0.30,
            height * 0.48,
          ),
          paint,
        );
        canvas.drawCircle(
          Offset(x + width * 0.50, baseline - height - height * 0.48),
          width * 0.15,
          paint,
        );
      } else {
        canvas.drawArc(
          Rect.fromLTWH(
            x,
            baseline - height - width * 0.45,
            width,
            width * 0.9,
          ),
          3.14,
          3.14,
          true,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
