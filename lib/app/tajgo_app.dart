import 'dart:async';
import 'package:flutter/material.dart';

import '../features/splash/splash_screen.dart';
import '../shared/widgets/tajgo_scope.dart';
import 'tajgo_theme.dart';
import '../core/config/feature_flags.dart';
import 'package:flutter/foundation.dart';
import '../core/services/order_notification_service.dart';
import '../core/services/diagnostic_service.dart';
import '../features/customer/order_tracking_screen.dart';
import '../features/courier/courier_order_screen.dart';

class TajGoApp extends StatefulWidget {
  const TajGoApp({super.key, this.diagnostics, this.featureFlags});
  final DiagnosticService? diagnostics;
  final FeatureFlags? featureFlags;
  @override
  State<TajGoApp> createState() => _TajGoAppState();
}

class _TajGoAppState extends State<TajGoApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final TajGoScope _scope;
  late final OrderNotificationService _notifications;
  late final DiagnosticService _diagnostics;
  StreamSubscription<OrderNotification>? _foreground, _opened;
  String? _visibleOrder;
  int _openingGeneration = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final flags = widget.featureFlags ?? FeatureFlags.resolve();
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    _notifications = OrderNotificationService(
      supported: android,
      allowed: flags.notifications,
    );
    _diagnostics =
        widget.diagnostics ??
        DiagnosticService(allowed: android && flags.crashReporting);
    _scope = TajGoScope(
      featureFlags: flags,
      notifications: _notifications,
      diagnostics: _diagnostics,
      child: MaterialApp(
        title: 'TajGo+',
        navigatorKey: _navigator,
        scaffoldMessengerKey: _messenger,
        debugShowCheckedModeBanner: false,
        theme: TajGoTheme.light,
        home: const SplashScreen(),
      ),
    );
    _foreground = _notifications.foreground.listen((message) {
      _messenger.currentState?.showSnackBar(
        SnackBar(
          content: Text(message.title),
          action: SnackBarAction(
            label: 'Открыть',
            onPressed: () => _openOrder(message),
          ),
        ),
      );
    });
    _opened = _notifications.opened.listen(_openOrder);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_notifications.initialize());
        unawaited(_diagnostics.initialize());
      }
    });
  }

  Future<void> _openOrder(OrderNotification message) async {
    final uid = _scope.authService.currentUser?.uid;
    if (uid != message.recipientId || _visibleOrder == message.orderId) return;
    final generation = ++_openingGeneration;
    final sessionRevision = _notifications.sessionRevision;
    try {
      final order = await _scope.orderRepository
          .orderStream(message.orderId)
          .first
          .timeout(const Duration(seconds: 10));
      if (!mounted ||
          generation != _openingGeneration ||
          sessionRevision != _notifications.sessionRevision ||
          _scope.authService.currentUser?.uid != uid) {
        return;
      }
      final customer = order?.customerId == uid;
      final courier =
          order?.courierId == uid || order?.selectedCourierId == uid;
      if (order == null || (!customer && !courier)) {
        throw StateError('Order no longer assigned');
      }
      final navigator = _navigator.currentState;
      if (navigator == null) return;
      _visibleOrder = order.id;
      unawaited(
        navigator
            .push<void>(
              MaterialPageRoute(
                builder: (_) => customer
                    ? OrderTrackingScreen(orderId: order.id)
                    : CourierOrderScreen(orderId: order.id),
              ),
            )
            .whenComplete(() {
              if (_visibleOrder == order.id) _visibleOrder = null;
            }),
      );
    } catch (_) {
      if (mounted &&
          generation == _openingGeneration &&
          sessionRevision == _notifications.sessionRevision &&
          _scope.authService.currentUser?.uid == uid) {
        _messenger.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Заказ недоступен. Обновите список заказов.'),
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_notifications.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _openingGeneration++;
    unawaited(_foreground?.cancel());
    unawaited(_opened?.cancel());
    _notifications.dispose();
    if (widget.diagnostics == null) _diagnostics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _scope;
}
