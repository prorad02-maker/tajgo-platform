import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/app_user.dart';
import '../../core/models/tajgo_courier.dart';
import '../../core/models/tajgo_order.dart';
import '../../shared/widgets/tajgo_badge.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'admin_orders_screen.dart';
import 'widgets/admin_access_gate.dart';
import 'widgets/tajgo_admin_action_button.dart';
import 'widgets/tajgo_status_timeline.dart';

class AdminOrderDetailsScreen extends StatelessWidget {
  const AdminOrderDetailsScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) =>
      AdminAccessGate(child: _AdminOrderDetailsBody(orderId: orderId));
}

class _AdminOrderDetailsBody extends StatefulWidget {
  const _AdminOrderDetailsBody({required this.orderId});
  final String orderId;

  @override
  State<_AdminOrderDetailsBody> createState() => _AdminOrderDetailsBodyState();
}

class _AdminOrderDetailsBodyState extends State<_AdminOrderDetailsBody> {
  final _note = TextEditingController();
  bool _noteInitialized = false;

  String get _adminId => TajGoScope.of(context).authService.currentUser!.uid;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _reasonAction({
    required String title,
    required String message,
    required Future<void> Function(String reason) action,
  }) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Причина',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    try {
      await action(reason);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Готово')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Детали заказа')),
      body: StreamBuilder<TajGoOrder?>(
        stream: scope.adminRepository.orderStream(widget.orderId),
        builder: (context, snapshot) {
          final order = snapshot.data;
          if (order == null) {
            if (snapshot.hasError) {
              return Center(child: Text('${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          if (!_noteInitialized) {
            _noteInitialized = true;
            _note.text = order.adminNote ?? '';
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              SizedBox(height: 280, child: _OrderMap(order: order)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TajGoBadge(
                          text: orderStatusLabel(order.status),
                          background: TajGoColors.mint,
                          foreground: TajGoColors.darkGreen,
                        ),
                        const Spacer(),
                        Text(
                          '${order.price} ${order.currency}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${order.fromText} → ${order.toText}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Цена: ${order.price} TJS · Расстояние: ${order.distanceKm?.toStringAsFixed(1) ?? '—'} км',
                      style: const TextStyle(color: TajGoColors.muted),
                    ),
                    if (order.orderType == 'catalogOrder' &&
                        order.items.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TajGoColors.mint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Партнёр: ${order.partnerName ?? order.partnerId ?? '—'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            for (final item in order.items)
                              Text(
                                '${item.name} × ${item.quantity} · '
                                '${item.lineTotal} TJS',
                              ),
                            const Divider(),
                            Text(
                              'Товары ${order.subtotal ?? 0} + доставка '
                              '${order.deliveryFee ?? order.price} = '
                              '${order.total ?? 0} TJS',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Text(
                      'Маршрут предварительный — показана прямая линия.',
                      style: TextStyle(
                        color: TajGoColors.warning,
                        fontSize: 12,
                      ),
                    ),
                    if ((order.comment ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('💬 ${order.comment}'),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'Участники',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Party(
                      title: 'Клиент',
                      uid: order.customerId,
                      fallbackName: order.customerName,
                    ),
                    if (order.courierId != null)
                      _Party(
                        title: 'Курьер',
                        uid: order.courierId!,
                        fallbackName: 'Курьер',
                      ),
                    const SizedBox(height: 18),
                    const Text(
                      'История статусов',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TajGoStatusTimeline(entries: _timeline(order)),
                    const SizedBox(height: 18),
                    const Text(
                      'Заметка админа',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _note,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        try {
                          await scope.adminRepository.setAdminNote(
                            orderId: order.id,
                            adminId: _adminId,
                            note: _note.text,
                          );
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('$error')));
                          }
                        }
                      },
                      child: const Text('Сохранить заметку'),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Действия',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _actions(order, scope),
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

  List<Widget> _actions(TajGoOrder order, TajGoScope scope) {
    final result = <Widget>[];
    if (!const {
      OrderStatus.completed,
      OrderStatus.cancelled,
    }.contains(order.status)) {
      result.add(
        OutlinedButton(
          onPressed: () => _reasonAction(
            title: 'Отменить заказ',
            message:
                'Заказ будет отменён для клиента и курьера. Укажите причину — она сохранится в журнале.',
            action: (reason) => scope.adminRepository.cancelOrder(
              orderId: order.id,
              adminId: _adminId,
              reason: reason,
            ),
          ),
          child: const Text('Отменить заказ'),
        ),
      );
    }
    if (const {
      OrderStatus.accepted,
      OrderStatus.pickedUp,
      OrderStatus.delivered,
      OrderStatus.disputed,
    }.contains(order.status)) {
      result.add(
        TajGoAdminActionButton(
          label: 'Вернуть в waiting',
          title: 'Вернуть в waiting?',
          message:
              'Заказ снова увидят все курьеры. Текущий курьер будет снят с заказа. Продолжить?',
          onConfirm: () => scope.adminRepository.returnToWaiting(
            orderId: order.id,
            adminId: _adminId,
          ),
        ),
      );
    }
    if (const {
      OrderStatus.pickedUp,
      OrderStatus.delivered,
      OrderStatus.disputed,
    }.contains(order.status)) {
      result.add(
        TajGoAdminActionButton(
          label: 'Завершить вручную',
          title: 'Завершить вручную?',
          message:
              'Заказ будет завершён, курьер получит оплату за заказ. Обычно это делается после разбора спора.',
          onConfirm: () => scope.adminRepository.completeManually(
            orderId: order.id,
            adminId: _adminId,
          ),
        ),
      );
    }
    if (const {
      OrderStatus.accepted,
      OrderStatus.pickedUp,
      OrderStatus.delivered,
      OrderStatus.completed,
    }.contains(order.status)) {
      result.add(
        OutlinedButton(
          onPressed: () => _reasonAction(
            title: 'Пометить спорным',
            message:
                'Заказ будет передан на разбор. Курьер не сможет брать новые заказы до решения.',
            action: (reason) => scope.adminRepository.markDisputed(
              orderId: order.id,
              adminId: _adminId,
              reason: reason,
            ),
          ),
          child: const Text('Пометить спорным'),
        ),
      );
    }
    return result;
  }

  List<TajGoTimelineEntry> _timeline(TajGoOrder order) => [
    if (order.createdAt != null) TajGoTimelineEntry('Создан', order.createdAt!),
    if (order.acceptedAt != null)
      TajGoTimelineEntry('Принят', order.acceptedAt!),
    if (order.arrivedAtPickupAt != null)
      TajGoTimelineEntry('Курьер на месте', order.arrivedAtPickupAt!),
    if (order.pickedUpAt != null)
      TajGoTimelineEntry('Забрал', order.pickedUpAt!),
    if (order.deliveredAt != null)
      TajGoTimelineEntry('Передан', order.deliveredAt!),
    if (order.completedAt != null)
      TajGoTimelineEntry('Завершён', order.completedAt!),
    if (order.disputedAt != null) TajGoTimelineEntry('Спор', order.disputedAt!),
    if (order.cancelledAt != null)
      TajGoTimelineEntry(
        'Отменён',
        order.cancelledAt!,
        details: order.cancelledReason,
      ),
  ];
}

class _OrderMap extends StatelessWidget {
  const _OrderMap({required this.order});
  final TajGoOrder order;

  @override
  Widget build(BuildContext context) {
    const center = LatLng(40.2833, 69.6222);
    final from = order.fromLocation == null
        ? null
        : LatLng(order.fromLocation!.latitude, order.fromLocation!.longitude);
    final to = order.toLocation == null
        ? null
        : LatLng(order.toLocation!.latitude, order.toLocation!.longitude);
    final route = from != null && to != null
        ? TajGoScope.of(context).routeService.directRoute(from: from, to: to)
        : null;
    Widget map(TajGoCourier? courier) => FlutterMap(
      options: MapOptions(initialCenter: from ?? to ?? center, initialZoom: 13),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'tj.tajgo.app',
        ),
        if (route != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route.polylinePoints,
                color: TajGoColors.green,
                strokeWidth: 4,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (from != null)
              Marker(
                point: from,
                width: 44,
                height: 44,
                child: const _Pin('A', TajGoColors.darkGreen),
              ),
            if (to != null)
              Marker(
                point: to,
                width: 44,
                height: 44,
                child: const _Pin('B', TajGoColors.lime),
              ),
            if (courier?.location != null)
              Marker(
                point: LatLng(
                  courier!.location!.latitude,
                  courier.location!.longitude,
                ),
                width: 24,
                height: 24,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
    if (order.courierId == null) return map(null);
    return StreamBuilder<TajGoCourier?>(
      stream: TajGoScope.of(
        context,
      ).courierRepository.publicCourierStream(order.courierId!),
      builder: (context, snapshot) => map(snapshot.data),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Icon(Icons.location_pin, size: 44, color: color),
      Positioned(
        top: 8,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}

class _Party extends StatelessWidget {
  const _Party({
    required this.title,
    required this.uid,
    required this.fallbackName,
  });
  final String title;
  final String uid;
  final String fallbackName;

  @override
  Widget build(BuildContext context) => FutureBuilder<AppUser?>(
    future: TajGoScope.of(context).adminRepository.user(uid),
    builder: (context, snapshot) {
      final user = snapshot.data;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
        title: Text('$title: ${user?.displayName ?? fallbackName}'),
        subtitle: Text(
          '${user?.phoneNumber ?? 'телефон не указан'}\nuid: $uid',
        ),
      );
    },
  );
}
