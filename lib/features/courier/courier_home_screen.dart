import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_courier.dart';
import '../../core/models/tajgo_order.dart';
import '../../shared/widgets/tajgo_action_button.dart';
import '../../shared/widgets/tajgo_order_card.dart';
import '../../shared/widgets/tajgo_order_progress.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../../shared/widgets/tajgo_stat_card.dart';
import '../../shared/widgets/tajgo_status_pill.dart';
import 'courier_order_screen.dart';

class CourierHomeScreen extends StatefulWidget {
  const CourierHomeScreen({super.key});

  @override
  State<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends State<CourierHomeScreen> {
  bool _busy = false;
  bool _broadcasting = false;
  bool _locationErrorShown = false;
  bool _locationBlocked = false;
  bool _locationStarting = false;
  StreamSubscription<Position>? _positionSubscription;

  String get _uid => TajGoScope.of(context).authService.currentUser!.uid;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setOnline(bool online) => _run(() async {
    final scope = TajGoScope.of(context);
    final user = await scope.userRepository.getUser(_uid);
    await scope.courierRepository.setOnline(
      uid: _uid,
      online: online,
      name: user?.name ?? 'Курьер',
      city: user?.city ?? 'Худжанд',
    );
  });

  void _openOrder(String orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourierOrderScreen(orderId: orderId)),
    );
  }

  Future<void> _acceptOrder(TajGoOrder order) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await TajGoScope.of(
        context,
      ).courierRepository.acceptOrder(orderId: order.id, courierId: _uid);
      if (mounted) {
        _openOrder(order.id);
      }
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resetTestOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Сбросить тестовый заказ?'),
        content: const Text(
          'Заказ вернётся в ленту со статусом waiting. Курьер останется на линии.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _run(() async {
      await TajGoScope.of(
        context,
      ).courierRepository.resetActiveOrderForTesting(courierId: _uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Тестовый заказ возвращён в ленту.')),
        );
      }
    });
  }

  Future<void> _syncLocationBroadcast(bool online) async {
    if (!online) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      _locationBlocked = false;
      _locationStarting = false;
      if (mounted && _broadcasting) {
        setState(() => _broadcasting = false);
      }
      return;
    }
    if (_positionSubscription != null ||
        _broadcasting ||
        _locationBlocked ||
        _locationStarting) {
      return;
    }
    _locationStarting = true;
    try {
      final scope = TajGoScope.of(context);
      final initial = await scope.locationService.determineCurrentPosition();
      await scope.courierRepository.updateLocation(
        uid: _uid,
        latitude: initial.latitude,
        longitude: initial.longitude,
      );
      _positionSubscription = scope.locationService.positionStream().listen(
        (position) => scope.courierRepository.updateLocation(
          uid: _uid,
          latitude: position.latitude,
          longitude: position.longitude,
        ),
        onError: (Object error) async {
          await _positionSubscription?.cancel();
          _positionSubscription = null;
          _locationBlocked = true;
          if (mounted) {
            setState(() => _broadcasting = false);
            if (!_locationErrorShown) {
              _locationErrorShown = true;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$error')));
            }
          }
        },
      );
      if (mounted) {
        setState(() {
          _broadcasting = true;
          _locationStarting = false;
          _locationErrorShown = false;
        });
      }
    } catch (error) {
      _locationBlocked = true;
      _locationStarting = false;
      if (mounted && !_locationErrorShown) {
        _locationErrorShown = true;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = TajGoScope.of(context).courierRepository;
    return Scaffold(
      body: StreamBuilder<TajGoCourier?>(
        stream: repository.courierStream(_uid),
        builder: (context, courierSnapshot) {
          final courier = courierSnapshot.data;
          final online = courier?.online ?? false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _syncLocationBroadcast(online);
            }
          });
          return StreamBuilder<TajGoOrder?>(
            stream: courier?.activeOrderId == null
                ? Stream<TajGoOrder?>.value(null)
                : repository.orderStream(courier!.activeOrderId!),
            builder: (context, activeSnapshot) {
              final activeOrder = activeSnapshot.data;
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _CourierHeader(
                    online: online,
                    broadcasting: _broadcasting,
                    busy: _busy,
                    onToggle: () => _setOnline(!online),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatsGrid(courier: courier),
                        const SizedBox(height: 24),
                        if (activeOrder != null) ...[
                          const Text(
                            'Мой активный заказ',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TajGoOrderCard(
                            order: activeOrder,
                            backgroundColor: TajGoColors.mint,
                            onTap: () => _openOrder(activeOrder.id),
                            actions: Column(
                              children: [
                                TajGoOrderProgress(
                                  currentStep: switch (activeOrder.status) {
                                    OrderStatus.accepted
                                        when activeOrder.arrivedAtPickupAt !=
                                            null =>
                                      1,
                                    OrderStatus.accepted => 0,
                                    OrderStatus.pickedUp => 3,
                                    OrderStatus.delivered ||
                                    OrderStatus.completed ||
                                    OrderStatus.disputed => 4,
                                    _ => 0,
                                  },
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  switch (activeOrder.status) {
                                    OrderStatus.accepted
                                        when activeOrder.arrivedAtPickupAt !=
                                            null =>
                                      'Курьер на месте',
                                    OrderStatus.accepted =>
                                      'Едем к точке забора',
                                    OrderStatus.pickedUp =>
                                      'Доставляем клиенту',
                                    OrderStatus.delivered =>
                                      'Ждём подтверждения клиента',
                                    OrderStatus.disputed =>
                                      'Доставка на проверке',
                                    OrderStatus.completed => 'Заказ завершён',
                                    _ => 'Активный заказ',
                                  },
                                  style: const TextStyle(
                                    color: TajGoColors.darkGreen,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (kDebugMode)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _busy ? null : _resetTestOrder,
                                icon: const Icon(Icons.restart_alt_rounded),
                                label: const Text(
                                  'Тест · Сбросить тестовый заказ',
                                ),
                              ),
                            ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                'Завершите текущий заказ, чтобы принять следующий',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: TajGoColors.muted),
                              ),
                            ),
                          ),
                        ] else ...[
                          if (kDebugMode && courier?.activeOrderId != null) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _busy ? null : _resetTestOrder,
                                icon: const Icon(Icons.restart_alt_rounded),
                                label: const Text(
                                  'Тест · Сбросить тестовый заказ',
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          const Text(
                            'Ожидающие заказы',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (!online)
                            const _EmptyFeed(
                              icon: '🛵',
                              text: 'Выйдите на линию, чтобы видеть заказы',
                            )
                          else
                            StreamBuilder<List<TajGoOrder>>(
                              stream: repository.waitingOrdersStream(),
                              builder: (context, snapshot) {
                                final orders =
                                    (snapshot.data ?? const <TajGoOrder>[])
                                        .where(
                                          (order) =>
                                              !order.declinedBy.contains(_uid),
                                        )
                                        .toList();
                                if (orders.isEmpty) {
                                  return const _EmptyFeed(
                                    icon: '📭',
                                    text: 'Пока заказов нет',
                                  );
                                }
                                return Column(
                                  children: orders
                                      .map(
                                        (order) => TajGoOrderCard(
                                          order: order,
                                          actions: Row(
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: SizedBox(
                                                  height: 52,
                                                  child: FilledButton(
                                                    style:
                                                        FilledButton.styleFrom(
                                                          backgroundColor:
                                                              TajGoColors
                                                                  .secondaryBtn,
                                                          foregroundColor:
                                                              TajGoColors
                                                                  .darkGreen,
                                                        ),
                                                    onPressed: _busy
                                                        ? null
                                                        : () => _run(
                                                            () => repository
                                                                .declineOrder(
                                                                  orderId:
                                                                      order.id,
                                                                  courierId:
                                                                      _uid,
                                                                ),
                                                          ),
                                                    child: const Text(
                                                      'Отказаться',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 3,
                                                child: TajGoActionButton(
                                                  label: 'Принять ✓',
                                                  busy: _busy,
                                                  onPressed: () =>
                                                      _acceptOrder(order),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CourierHeader extends StatelessWidget {
  const _CourierHeader({
    required this.online,
    required this.broadcasting,
    required this.busy,
    required this.onToggle,
  });

  final bool online;
  final bool broadcasting;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      12,
      MediaQuery.paddingOf(context).top + 6,
      18,
      24,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [TajGoColors.darkGreen, TajGoColors.green],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              color: Colors.white,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const Expanded(
              child: Text(
                'TajGo Курьер · 📍 Худжанд',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            TajGoStatusPill(online: online),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          online ? 'Вы на линии 🟢' : 'Готовы выйти на линию?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (broadcasting)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '📡 координаты передаются',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: online
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                  ),
                  onPressed: busy ? null : onToggle,
                  child: const Text('Уйти с линии'),
                )
              : FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: TajGoColors.darkGreen,
                  ),
                  onPressed: busy ? null : onToggle,
                  child: const Text('Выйти на линию'),
                ),
        ),
      ],
    ),
  );
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.courier});

  final TajGoCourier? courier;

  @override
  Widget build(BuildContext context) {
    final wideLayout = MediaQuery.sizeOf(context).width >= 700;
    final cards = <Widget>[
      TajGoStatCard(
        icon: '💰',
        value: '${courier?.earningsToday ?? 0} TJS',
        label: 'Сегодня',
      ),
      TajGoStatCard(
        icon: '📦',
        value: '${courier?.ordersToday ?? 0}',
        label: 'Заказов',
      ),
      TajGoStatCard(
        icon: '⭐',
        value: (courier?.rating ?? 5).toStringAsFixed(1),
        label: 'Рейтинг',
      ),
      TajGoStatCard(
        icon: '🏆',
        value: '${courier?.score ?? 100}',
        label: 'TajGo Score',
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wideLayout ? 4 : 2,
        mainAxisExtent: 126,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) => cards[index],
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
    child: Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 42)),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: TajGoColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
