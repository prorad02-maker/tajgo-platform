import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../features/role/role_screen.dart';
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

  String _status = 'Подключаем TajGo…';
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
      setState(() => _status = 'Входим в TajGo…');
      final user = await scope.authService.signInAnonymouslyIfNeeded().timeout(
        const Duration(seconds: 10),
      );
      if (!mounted) return;
      setState(() => _status = 'Готовим профиль…');
      await scope.userRepository
          .ensureUser(uid: user.uid)
          .timeout(const Duration(seconds: 10));
      _bootstrapReady = true;
      await minimumSplashTime;
      await _approachNinetyPercent;
      if (!mounted) return;
      _pulseController.stop();
      setState(() => _waiting = false);
      await _progressController.animateTo(
        1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const RoleScreen()),
      );
    } catch (_) {
      _failed = true;
      _progressController.stop();
      _pulseController.stop();
      if (!mounted) return;
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
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final splashAsset = isDark
        ? 'assets/brand/splash_dark.png'
        : 'assets/brand/splash_light.png';

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF071009)
          : const Color(0xFFF8FAF7),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            splashAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => ColoredBox(
              color: isDark ? const Color(0xFF071009) : const Color(0xFFF8FAF7),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.55, 1],
                colors: [
                  Color(0x10000000),
                  Color(0x00000000),
                  Color(0x70000000),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                children: [
                  Center(
                    child: Image.asset(
                      'assets/brand/tajgo_logo.png',
                      width: 128,
                      height: 128,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: 128, height: 128),
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _progressController,
                      _pulseController,
                    ]),
                    builder: (context, _) => _SplashProgressBar(
                      progress: _progressController.value,
                      opacity: _waiting ? _pulseController.value : 1,
                      failed: _failed,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _failed ? const Color(0xFFFFB4AB) : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 8,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashProgressBar extends StatelessWidget {
  const _SplashProgressBar({
    required this.progress,
    required this.opacity,
    required this.failed,
  });

  final double progress;
  final double opacity;
  final bool failed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: Container(
      width: 140,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.30),
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
