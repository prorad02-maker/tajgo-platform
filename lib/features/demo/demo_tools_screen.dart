import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/app_user.dart';
import '../../core/models/tajgo_courier.dart';
import '../../core/models/tajgo_order.dart';
import '../../core/services/pricing.dart' as pricing;
import '../../shared/widgets/tajgo_badge.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../map/models/tajgo_route.dart';

class DemoToolsScreen extends StatefulWidget {
  const DemoToolsScreen({super.key});

  @override
  State<DemoToolsScreen> createState() => _DemoToolsScreenState();
}

class _DemoToolsScreenState extends State<DemoToolsScreen> {
  String? _selectedOrderId;
  bool _busy = false;
  String? _routingProbeResult;

  String get _uid => TajGoScope.of(context).authService.currentUser!.uid;

  Future<void> _confirm(
    String title,
    String message,
    Future<void> Function() action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Тест · Выполнить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Тестовое действие выполнено')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createTestOrder({required bool nearby, double? meters}) async {
    final scope = TajGoScope.of(context);
    GeoPoint from = const GeoPoint(40.2833, 69.6222);
    if (nearby || meters != null) {
      final courier = await scope.adminRepository.courier(_uid);
      if (courier?.location != null) from = courier!.location!;
    }
    if (meters != null) {
      from = GeoPoint(from.latitude + meters / 111320, from.longitude);
    }
    final to = GeoPoint(from.latitude + 0.006, from.longitude + 0.007);
    final route = scope.routeService.directRoute(
      from: LatLng(from.latitude, from.longitude),
      to: LatLng(to.latitude, to.longitude),
    );
    final profile = await scope.userRepository.getUser(_uid);
    await scope.orderRepository.createOrder(
      customerId: _uid,
      customerName: profile?.displayName ?? 'Тестовый клиент',
      fromText: nearby ? 'Тест · Рядом с курьером' : 'Тест · Центр Худжанда',
      toText: 'Тест · Точка доставки',
      type: 'package',
      price: pricing.suggestedPrice(route.distanceKm),
      fromLocation: from,
      toLocation: to,
      distanceKm: route.distanceKm,
      etaMinutes: route.etaMinutes,
      comment: '[TEST] Демо-заказ v0.7.0',
      isTestOrder: true,
      orderType: 'customDelivery',
      suggestedPrice: pricing.suggestedPrice(route.distanceKm),
      clientPrice: pricing.suggestedPrice(route.distanceKm),
    );
  }

  Future<void> _seedOffers() async {
    final orderId = _selectedOrderId;
    if (orderId == null) throw StateError('Сначала выберите заказ.');
    final orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId);
    final batch = FirebaseFirestore.instance.batch();
    for (var index = 0; index < 3; index++) {
      final ref = orderRef
          .collection('offers')
          .doc('demo-courier-${index + 1}');
      batch.set(ref, {
        'courierId': 'demo-courier-${index + 1}',
        'courierName': 'Тестовый курьер ${index + 1}',
        'courierRating': 4.7 + index / 10,
        'courierTransport': index == 0 ? 'bicycle' : 'electric_bike',
        'courierDistanceMeters': 250 + index * 220,
        'proposedPrice': 15 + index * 2,
        'originalClientPrice': 15,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 30)),
        ),
        'isTest': true,
      });
    }
    batch.update(orderRef, {
      'offersCount': 3,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> _clearOffers() async {
    final orderId = _selectedOrderId;
    if (orderId == null) throw StateError('Сначала выберите заказ.');
    final orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId);
    final offers = await orderRef.collection('offers').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final offer in offers.docs) {
      batch.delete(offer.reference);
    }
    batch.update(orderRef, {
      'offersCount': 0,
      'selectedOfferId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> _seedMarketplace() async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final partners = <String, Map<String, dynamic>>{
      'demo-food': {
        'name': 'TajGo Kitchen',
        'category': 'food',
        'description': 'Горячие блюда и быстрые обеды',
        'address': 'проспект Исмоили Сомони, Худжанд',
        'location': const GeoPoint(40.2833, 69.6222),
        'minimumOrder': 30,
        'deliveryFee': 12,
        'rating': 4.9,
        'preparationMinutes': 25,
        'workingHours': '09:00–22:00',
      },
      'demo-groceries': {
        'name': 'Сабзавот Маркет',
        'category': 'groceries',
        'description': 'Свежие продукты на каждый день',
        'address': 'улица Камоли Худжанди, Худжанд',
        'location': const GeoPoint(40.2874, 69.6184),
        'minimumOrder': 25,
        'deliveryFee': 10,
        'rating': 4.8,
        'preparationMinutes': 15,
        'workingHours': '08:00–21:00',
      },
      'demo-flowers': {
        'name': 'Гулҳои Суғд',
        'category': 'flowers',
        'description': 'Букеты и цветы с быстрой доставкой',
        'address': 'улица Рахмон Набиев, Худжанд',
        'location': const GeoPoint(40.2798, 69.6268),
        'minimumOrder': 50,
        'deliveryFee': 15,
        'rating': 5.0,
        'preparationMinutes': 20,
        'workingHours': '08:00–23:00',
      },
    };
    for (final entry in partners.entries) {
      batch.set(db.collection('partners').doc(entry.key), {
        ...entry.value,
        'imageUrl': '',
        'isOpen': true,
        'isActive': true,
        'isTest': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final products = <String, Map<String, dynamic>>{
      'demo-food-plov': {
        'partnerId': 'demo-food',
        'name': 'Оши палав',
        'description': 'Порция традиционного плова',
        'price': 32,
        'unit': 'portion',
        'popularity': 100,
      },
      'demo-food-sambusa': {
        'partnerId': 'demo-food',
        'name': 'Самбӯса',
        'description': 'Самса из тандыра',
        'price': 8,
        'unit': 'item',
        'popularity': 80,
      },
      'demo-grocery-apples': {
        'partnerId': 'demo-groceries',
        'name': 'Яблоки',
        'description': 'Свежие яблоки',
        'price': 12,
        'unit': 'kg',
        'popularity': 70,
      },
      'demo-grocery-bread': {
        'partnerId': 'demo-groceries',
        'name': 'Лепёшка',
        'description': 'Горячий хлеб',
        'price': 4,
        'unit': 'item',
        'popularity': 90,
      },
      'demo-flower-roses': {
        'partnerId': 'demo-flowers',
        'name': 'Букет роз',
        'description': '7 свежих роз',
        'price': 85,
        'unit': 'bouquet',
        'popularity': 100,
      },
      'demo-flower-tulips': {
        'partnerId': 'demo-flowers',
        'name': 'Букет тюльпанов',
        'description': '9 сезонных тюльпанов',
        'price': 65,
        'unit': 'bouquet',
        'popularity': 75,
      },
    };
    for (final entry in products.entries) {
      batch.set(db.collection('products').doc(entry.key), {
        ...entry.value,
        'imageUrl': '',
        'isAvailable': true,
        'hidden': false,
        'isTest': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(db.collection('admin_logs').doc(), {
      'adminId': _uid,
      'action': 'marketplace.demo.seed',
      'entityType': 'marketplace',
      'entityId': 'demo-marketplace',
      'before': null,
      'after': {
        'partners': partners.keys.toList(),
        'products': products.keys.toList(),
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> _probeRoutingProvider() async {
    setState(() {
      _busy = true;
      _routingProbeResult = 'Проверяем маршрут…';
    });
    try {
      final route = await TajGoScope.of(context).routeService.buildRoute(
        from: const LatLng(40.2833, 69.6222),
        to: const LatLng(40.2933, 69.6322),
        mode: RouteMode.bicycle,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(
        () => _routingProbeResult =
            '${route.qualityLabel} · ${route.providerName} · '
            '${route.distanceKm.toStringAsFixed(1)} км · '
            '${route.etaMinutes} мин',
      );
    } catch (error) {
      if (mounted) setState(() => _routingProbeResult = 'Ошибка: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Demo Tools недоступны в release.')),
      );
    }
    final scope = TajGoScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Тест · Demo Tools')),
      body: StreamBuilder<AppUser?>(
        stream: scope.userRepository.userStream(_uid),
        builder: (context, userSnapshot) => StreamBuilder<TajGoCourier?>(
          stream: scope.courierRepository.courierStream(_uid),
          builder: (context, courierSnapshot) => StreamBuilder<List<TajGoOrder>>(
            stream: scope.adminRepository.ordersStream(),
            builder: (context, orderSnapshot) {
              final user = userSnapshot.data;
              final courier = courierSnapshot.data;
              final orders = orderSnapshot.data ?? const <TajGoOrder>[];
              final selected =
                  orders.any((order) => order.id == _selectedOrderId)
                  ? _selectedOrderId
                  : null;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: TajGoColors.mint,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'Текущий контекс',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Spacer(),
                              TajGoBadge(
                                text: 'debug',
                                background: TajGoColors.lime,
                                foreground: TajGoColors.ink,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText('uid: $_uid'),
                          Text('Роль: ${user?.role ?? '—'}'),
                          Text('Телефон: ${user?.phoneNumber ?? '—'}'),
                          Text('online: ${courier?.online ?? false}'),
                          Text(
                            'activeOrderId: ${courier?.activeOrderId ?? '—'}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      scope.routeService.health,
                      scope.routeService.performance,
                    ]),
                    builder: (context, _) {
                      final health = scope.routeService.health.snapshot;
                      final performance =
                          scope.routeService.performance.snapshot;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Routing & Map Health',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Статус: ${health.statusLabel}'),
                              Text(
                                'Enabled: ${health.enabled} · configured: '
                                '${health.configured}',
                              ),
                              Text('Provider: ${health.providerName}'),
                              Text(
                                'Base URL: '
                                '${health.baseUrlSet ? 'задан' : 'не задан'}',
                              ),
                              Text(
                                'Запросы: ${health.requests} · успех: '
                                '${health.successes} · fallback: ${health.fallbacks}',
                              ),
                              Text('Cache hits: ${health.cacheHits}'),
                              Text(
                                'Средний route: ${performance.averageRouteMs} мс · '
                                'search: ${performance.averageSearchMs} мс',
                              ),
                              Text(
                                'Медленные операции: '
                                '${performance.slowOperations}',
                              ),
                              if (health.lastLatency != null)
                                Text(
                                  'Последний ответ: '
                                  '${health.lastLatency!.inMilliseconds} мс',
                                ),
                              if (health.lastRequestUrl != null)
                                SelectableText(
                                  'Request: ${health.lastRequestUrl}',
                                ),
                              Text(
                                'HTTP: ${health.lastHttpStatus ?? '—'} · '
                                'parse: ${health.lastParseSuccess ?? '—'}',
                              ),
                              Text(
                                'Точек: ${health.lastPointsCount ?? '—'} · '
                                'distance: '
                                '${health.lastDistanceKm?.toStringAsFixed(3) ?? '—'} км · '
                                'ETA: ${health.lastEtaMinutes ?? '—'} мин',
                              ),
                              Text(
                                'Quality: ${health.lastQuality?.name ?? '—'}',
                              ),
                              if (health.fallbackReason != null)
                                SelectableText(
                                  'Fallback: ${health.fallbackReason}',
                                  style: const TextStyle(
                                    color: TajGoColors.warning,
                                  ),
                                ),
                              if (_routingProbeResult != null) ...[
                                const SizedBox(height: 6),
                                SelectableText(_routingProbeResult!),
                              ],
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _probeRoutingProvider,
                                icon: const Icon(Icons.route_rounded),
                                label: const Text('Проверить routing provider'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _ToolButton(
                    label: 'Тест · Создать demo marketplace',
                    busy: _busy,
                    onPressed: () => _confirm(
                      'Создать тестовую витрину?',
                      'Будут созданы 3 партнёра и 6 товаров. Повторный запуск обновит их.',
                      _seedMarketplace,
                    ),
                  ),
                  _ToolButton(
                    label: 'Тест · Создать заказ в Худжанде',
                    busy: _busy,
                    onPressed: () => _confirm(
                      'Создать тестовый заказ?',
                      'В Firestore появится waiting-заказ с тестовыми координатами.',
                      () => _createTestOrder(nearby: false),
                    ),
                  ),
                  _ToolButton(
                    label: 'Тест · Создать ближний заказ',
                    busy: _busy,
                    onPressed: () => _confirm(
                      'Создать ближний заказ?',
                      'Точка A будет рядом с текущей позицией курьера.',
                      () => _createTestOrder(nearby: true),
                    ),
                  ),
                  _ToolButton(
                    label: 'Тест · Создать заказ в 999 м',
                    busy: _busy,
                    onPressed: () => _confirm(
                      'Создать заказ на границе?',
                      'Точка A будет примерно в 999 м от текущего курьера.',
                      () => _createTestOrder(nearby: false, meters: 999),
                    ),
                  ),
                  _ToolButton(
                    label: 'Тест · Создать заказ в 1000 м',
                    busy: _busy,
                    onPressed: () => _confirm(
                      'Создать недоступный заказ?',
                      'Точка A будет примерно в 1000 м от текущего курьера.',
                      () => _createTestOrder(nearby: false, meters: 1000),
                    ),
                  ),
                  _ToolButton(
                    label: 'Тест · Сбросить activeOrderId',
                    busy: _busy || courier?.activeOrderId == null,
                    onPressed: () => _confirm(
                      'Сбросить activeOrderId?',
                      'Текущий заказ вернётся в waiting.',
                      () => scope.courierRepository.resetActiveOrderForTesting(
                        courierId: _uid,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Выбранный заказ',
                      border: OutlineInputBorder(),
                    ),
                    items: orders
                        .take(30)
                        .map(
                          (order) => DropdownMenuItem(
                            value: order.id,
                            child: Text(
                              '${orderStatusToString(order.status)} · ${order.fromText}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedOrderId = value),
                  ),
                  const SizedBox(height: 8),
                  _ToolButton(
                    label: 'Тест · Вернуть выбранный в waiting',
                    busy: _busy || selected == null,
                    onPressed: () => _confirm(
                      'Вернуть заказ?',
                      'Заказ снова появится в ленте курьера.',
                      () => scope.adminRepository.returnToWaiting(
                        orderId: selected!,
                        adminId: _uid,
                      ),
                    ),
                  ),
                  _ToolButton(
                    label: 'Тест · Создать 3 demo offers',
                    busy: _busy || selected == null,
                    onPressed: () => _confirm(
                      'Создать предложения?',
                      'У выбранного заказа появятся 3 тестовых предложения.',
                      _seedOffers,
                    ),
                  ),
                  _ToolButton(
                    label: 'Тест · Очистить offers',
                    busy: _busy || selected == null,
                    onPressed: () => _confirm(
                      'Очистить предложения?',
                      'Все offers выбранного заказа будут удалены.',
                      _clearOffers,
                    ),
                  ),
                  _ToolButton(
                    label: 'Тест · Очистить waiting test orders',
                    busy: _busy,
                    onPressed: () => _confirm(
                      'Очистить тестовые заказы?',
                      'Все waiting-заказы с меткой [TEST] будут отменены.',
                      () async {
                        await scope.adminRepository.cancelWaitingTestOrders(
                          adminId: _uid,
                        );
                      },
                    ),
                  ),
                  _ToolButton(
                    label: 'Тест · Сделать меня admin',
                    busy: _busy || user?.role == AppUserRole.admin,
                    onPressed: () => _confirm(
                      'Изменить роль?',
                      'Будет выполнена попытка записать role=admin. Текущие Rules могут это запретить.',
                      () => scope.userRepository.setAdminRoleForTesting(_uid),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton(
      onPressed: busy ? null : onPressed,
      child: Align(alignment: Alignment.centerLeft, child: Text(label)),
    ),
  );
}
