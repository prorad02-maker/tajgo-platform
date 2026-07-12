import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_courier.dart';
import '../../core/models/tajgo_order.dart';
import '../../shared/widgets/tajgo_scope.dart';

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
    final repo = TajGoScope.of(context).courierRepository;
    return Scaffold(
      body: StreamBuilder<TajGoCourier?>(
        stream: repo.courierStream(_uid),
        builder: (context, courierSnapshot) {
          final courier = courierSnapshot.data;
          final online = courier?.online ?? false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _syncLocationBroadcast(online);
            }
          });
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _CourierHeader(
                online: online,
                earnings: courier?.earningsToday ?? 0,
                busy: _busy,
                broadcasting: _broadcasting,
                onToggle: () => _setOnline(!online),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Мой активный заказ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<List<TajGoOrder>>(
                      stream: repo.activeCourierOrdersStream(_uid),
                      builder: (context, snapshot) {
                        final orders = snapshot.data ?? [];
                        if (orders.isEmpty) {
                          return const Text('Активного заказа нет.');
                        }
                        return Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: TajGoColors.mint,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: orders
                                .map(
                                  (order) => _OrderCard(
                                    order: order,
                                    action: order.status == OrderStatus.accepted
                                        ? 'Забрал посылку'
                                        : 'Доставил',
                                    onAction: () => _run(
                                      () => order.status == OrderStatus.accepted
                                          ? repo.markPickedUp(
                                              orderId: order.id,
                                              courierId: _uid,
                                            )
                                          : repo.markDelivered(
                                              orderId: order.id,
                                              courierId: _uid,
                                            ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Ожидающие заказы',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!online)
                      const Text('Выйдите на линию, чтобы видеть заказы')
                    else
                      StreamBuilder<List<TajGoOrder>>(
                        stream: repo.waitingOrdersStream(),
                        builder: (context, snapshot) {
                          final orders = (snapshot.data ?? [])
                              .where(
                                (order) => !order.declinedBy.contains(_uid),
                              )
                              .toList();
                          if (orders.isEmpty) {
                            return const Text('Пока заказов нет.');
                          }
                          return Column(
                            children: orders
                                .map(
                                  (order) => _OrderCard(
                                    order: order,
                                    action: 'Принять',
                                    secondary: 'Отказаться',
                                    onAction: () => _run(
                                      () => repo.acceptOrder(
                                        orderId: order.id,
                                        courierId: _uid,
                                      ),
                                    ),
                                    onSecondary: () => _run(
                                      () => repo.declineOrder(
                                        orderId: order.id,
                                        courierId: _uid,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
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

class _CourierHeader extends StatelessWidget {
  const _CourierHeader({
    required this.online,
    required this.earnings,
    required this.busy,
    required this.broadcasting,
    required this.onToggle,
  });
  final bool online, busy, broadcasting;
  final num earnings;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      16,
      MediaQuery.paddingOf(context).top + 8,
      20,
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
        IconButton(
          onPressed: () => Navigator.pop(context),
          color: Colors.white,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const Text('📍 Худжанд', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        Text(
          online ? 'Вы на линии 🟢' : 'Готовы выйти на линию?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Сегодня заработано — $earnings TJS',
          style: const TextStyle(color: Colors.white),
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
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: TajGoColors.darkGreen,
          ),
          onPressed: busy ? null : onToggle,
          child: Text(online ? 'Уйти с линии' : 'Выйти на линию'),
        ),
      ],
    ),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.action,
    required this.onAction,
    this.secondary,
    this.onSecondary,
  });
  final TajGoOrder order;
  final String action;
  final VoidCallback onAction;
  final String? secondary;
  final VoidCallback? onSecondary;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${order.fromText} → ${order.toText}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text('${order.price} ${order.currency}'),
          if (order.distanceKm != null && order.etaMinutes != null)
            Text(
              '~${order.distanceKm} км · ~${order.etaMinutes} мин',
              style: const TextStyle(color: TajGoColors.muted),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(onPressed: onAction, child: Text(action)),
              ),
              if (secondary != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: TajGoColors.secondaryBtn,
                      foregroundColor: TajGoColors.darkGreen,
                    ),
                    onPressed: onSecondary,
                    child: Text(secondary!),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}
