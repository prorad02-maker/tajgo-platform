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

class DemoToolsScreen extends StatefulWidget {
  const DemoToolsScreen({super.key});

  @override
  State<DemoToolsScreen> createState() => _DemoToolsScreenState();
}

class _DemoToolsScreenState extends State<DemoToolsScreen> {
  String? _selectedOrderId;
  bool _busy = false;

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

  Future<void> _createTestOrder({required bool nearby}) async {
    final scope = TajGoScope.of(context);
    GeoPoint from = const GeoPoint(40.2833, 69.6222);
    if (nearby) {
      final courier = await scope.adminRepository.courier(_uid);
      if (courier?.location != null) from = courier!.location!;
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
    );
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
