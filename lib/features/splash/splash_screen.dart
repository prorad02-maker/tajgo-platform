import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../features/role/role_screen.dart';
import '../../shared/widgets/tajgo_logo.dart';
import '../../shared/widgets/tajgo_scope.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AnimationController _pulseController;
  late final Future<void> _approachNinetyPercent;

  String _status = 'Подключаем TajGo...';
  bool _bootstrapReady = false;
  bool _waiting = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseController = AnimationController(
      vsync: this,
      lowerBound: 0.7,
      upperBound: 1,
      value: 1,
      duration: const Duration(seconds: 1),
    );
    _approachNinetyPercent = _progressController
        .animateTo(0.9, curve: Curves.easeOutCubic)
        .then((_) {
          if (mounted && !_bootstrapReady && !_failed) {
            setState(() => _waiting = true);
            _pulseController.repeat(reverse: true);
          }
        });
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final scope = TajGoScope.of(context);
    final minimumSplashTime = Future<void>.delayed(
      const Duration(milliseconds: 700),
    );
    try {
      setState(() => _status = 'Входим в TajGo...');
      final user = await scope.authService.signInAnonymouslyIfNeeded().timeout(
        const Duration(seconds: 10),
      );
      setState(() => _status = 'Готовим профиль...');
      await scope.userRepository
          .ensureUser(uid: user.uid)
          .timeout(const Duration(seconds: 10));
      _bootstrapReady = true;
      await minimumSplashTime;
      await _approachNinetyPercent;
      if (!mounted) {
        return;
      }
      _pulseController.stop();
      setState(() => _waiting = false);
      await _progressController.animateTo(
        1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const RoleScreen()),
      );
    } catch (_) {
      _failed = true;
      _progressController.stop();
      _pulseController.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _waiting = false;
        _status =
            'Не удалось подключиться. Проверьте интернет и попробуйте снова.';
      });
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final palette = dark ? _SplashPalette.dark : _SplashPalette.light;
    return Scaffold(
      backgroundColor: palette.backgroundStart,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final landscapeHeight = constraints.maxHeight * 0.34;
          final logoSize = (constraints.maxWidth * 0.29)
              .clamp(96.0, 128.0)
              .toDouble();
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [palette.backgroundStart, palette.backgroundEnd],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: landscapeHeight,
                child: CustomPaint(painter: _KhujandLandscapePainter(palette)),
              ),
              Positioned.fill(
                child: Image.asset(
                  dark
                      ? 'assets/brand/splash_dark.png'
                      : 'assets/brand/splash_light.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.46, 0.76, 1],
                      colors: dark
                          ? const [
                              Color(0x26000000),
                              Color(0x10000000),
                              Color(0x05000000),
                              Color(0x24000000),
                            ]
                          : const [
                              Color(0x38FFFFFF),
                              Color(0x18FFFFFF),
                              Color(0x00FFFFFF),
                              Color(0x080B6B3A),
                            ],
                    ),
                  ),
                ),
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
                              Container(
                                width: logoSize,
                                height: logoSize,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: dark
                                      ? const Color(0x3316A34A)
                                      : Colors.white.withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(
                                    logoSize * 0.27,
                                  ),
                                  border: Border.all(
                                    color: dark
                                        ? const Color(0x55A3E635)
                                        : Colors.white,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF06130D,
                                      ).withValues(alpha: dark ? 0.34 : 0.18),
                                      blurRadius: 34,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset(
                                  'assets/brand/tajgo_logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Center(
                                    child: TajGoLogo(size: logoSize - 6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Taj',
                                      style: TextStyle(color: palette.taj),
                                    ),
                                    TextSpan(
                                      text: 'Go',
                                      style: TextStyle(color: palette.accent),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(
                                  fontSize: 46,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: 'Проще. Быстрее. Честнее. ',
                                      ),
                                      TextSpan(
                                        text: 'Для своих.',
                                        style: TextStyle(
                                          color: palette.accent,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: TextStyle(
                                    color: palette.slogan,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: dark
                                      ? const Color(0xB312241A)
                                      : Colors.white.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: palette.accent.withValues(
                                      alpha: 0.22,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Худжанд  •  доставка рядом',
                                  style: TextStyle(
                                    color: palette.slogan,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.15,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              AnimatedBuilder(
                                animation: Listenable.merge([
                                  _progressController,
                                  _pulseController,
                                ]),
                                builder: (context, _) => TajGoProgressBar(
                                  progress: _progressController.value,
                                  opacity: _waiting
                                      ? _pulseController.value
                                      : 1,
                                  backgroundColor: palette.progressBackground,
                                  failed: _failed,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _status,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _failed
                                      ? TajGoColors.error
                                      : palette.status,
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

class TajGoProgressBar extends StatelessWidget {
  const TajGoProgressBar({
    super.key,
    required this.progress,
    required this.opacity,
    required this.backgroundColor,
    required this.failed,
  });

  final double progress;
  final double opacity;
  final Color backgroundColor;
  final bool failed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: Container(
      width: 132,
      height: 5,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress.clamp(0, 1),
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: failed ? TajGoColors.error : null,
            gradient: failed
                ? null
                : const LinearGradient(
                    colors: [TajGoColors.green, TajGoColors.lime],
                  ),
          ),
        ),
      ),
    ),
  );
}

class _SplashPalette {
  const _SplashPalette({
    required this.isDark,
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.taj,
    required this.accent,
    required this.slogan,
    required this.mountain,
    required this.sun,
    required this.cityBack,
    required this.cityFront,
    required this.hillBack,
    required this.hillFront,
    required this.road,
    required this.progressBackground,
    required this.status,
  });

  static const light = _SplashPalette(
    isDark: false,
    backgroundStart: Color(0xFFFFFFFF),
    backgroundEnd: Color(0xFFFAFCF7),
    taj: Color(0xFF272B2E),
    accent: TajGoColors.green,
    slogan: Color(0xFF3A4440),
    mountain: Color(0xFFE3EEDC),
    sun: Color(0xFFF5D97E),
    cityBack: Color(0xFF4E9455),
    cityFront: Color(0xFF3E8447),
    hillBack: Color(0xFF2E7C46),
    hillFront: Color(0xFF1E5C33),
    road: Color(0xFFF4F9F1),
    progressBackground: Color(0xFFDFEDD8),
    status: Color(0xFF7C8A80),
  );

  static const dark = _SplashPalette(
    isDark: true,
    backgroundStart: Color(0xFF0B1512),
    backgroundEnd: Color(0xFF071009),
    taj: Color(0xFFFFFFFF),
    accent: Color(0xFF4ADE80),
    slogan: Color(0xFFC7D2CC),
    mountain: Color(0xFF12241A),
    sun: Color(0xFFE8E4C9),
    cityBack: Color(0xFF173822),
    cityFront: Color(0xFF102A18),
    hillBack: Color(0xFF0E2415),
    hillFront: Color(0xFF081A0E),
    road: Color(0xFF243B2C),
    progressBackground: Color(0x1FFFFFFF),
    status: Color(0xFF7E8D84),
  );

  final bool isDark;
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color taj;
  final Color accent;
  final Color slogan;
  final Color mountain;
  final Color sun;
  final Color cityBack;
  final Color cityFront;
  final Color hillBack;
  final Color hillFront;
  final Color road;
  final Color progressBackground;
  final Color status;
}

class _KhujandLandscapePainter extends CustomPainter {
  const _KhujandLandscapePainter(this.palette);

  final _SplashPalette palette;

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
    canvas.drawPath(mountain, Paint()..color = palette.mountain);

    final sunCenter = Offset(size.width * 0.67, size.height * 0.22);
    final sunRadius = size.shortestSide * 0.085;
    if (palette.isDark) {
      canvas.drawCircle(
        sunCenter,
        sunRadius * 2.2,
        Paint()..color = palette.sun.withValues(alpha: 0.12),
      );
    }
    canvas.drawCircle(sunCenter, sunRadius, Paint()..color = palette.sun);

    _paintCity(canvas, size, palette.cityBack, size.height * 0.42, 0.82);
    _paintCity(canvas, size, palette.cityFront, size.height * 0.52, 1);
    if (palette.isDark) {
      _paintWindowLights(canvas, size);
    }

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
    canvas.drawPath(backHill, Paint()..color = palette.hillBack);

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
    canvas.drawPath(frontHill, Paint()..color = palette.hillFront);

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
        ..color = palette.road
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

  void _paintWindowLights(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xCCA3E635);
    const points = <(double, double)>[
      (0.09, 0.38),
      (0.18, 0.42),
      (0.31, 0.43),
      (0.46, 0.39),
      (0.60, 0.45),
      (0.74, 0.40),
      (0.89, 0.45),
    ];
    for (final point in points) {
      canvas.drawCircle(
        Offset(size.width * point.$1, size.height * point.$2),
        1.2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KhujandLandscapePainter oldDelegate) =>
      oldDelegate.palette != palette;
}
