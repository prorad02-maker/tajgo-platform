import 'package:flutter/material.dart';

import '../core/config/feature_flags.dart';
import '../features/splash/splash_screen.dart';
import '../shared/widgets/tajgo_scope.dart';
import 'tajgo_theme.dart';

class TajGoApp extends StatefulWidget {
  const TajGoApp({super.key, this.featureFlags});

  final FeatureFlags? featureFlags;

  @override
  State<TajGoApp> createState() => _TajGoAppState();
}

class _TajGoAppState extends State<TajGoApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return TajGoScope(
      featureFlags: widget.featureFlags,
      child: _NotificationsHost(
        navigatorKey: _navigatorKey,
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'TajGo+',
          debugShowCheckedModeBanner: false,
          theme: TajGoTheme.light,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

/// Инициализирует FCM после построения (под [TajGoScope]). Разрешение здесь НЕ
/// запрашивается — только регистрация обработчиков; permission — по требованию.
class _NotificationsHost extends StatefulWidget {
  const _NotificationsHost({required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<_NotificationsHost> createState() => _NotificationsHostState();
}

class _NotificationsHostState extends State<_NotificationsHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scope = TajGoScope.of(context);
      scope.pushNotificationService.initialize(
        enabled: scope.featureFlags.notifications,
        navigatorKey: widget.navigatorKey,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
