import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_order.dart';
import '../../shared/widgets/tajgo_badge.dart';
import '../../shared/widgets/tajgo_order_card.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'admin_order_details_screen.dart';
import 'widgets/admin_access_gate.dart';

enum AdminOrderFilter { all, waiting, active, disputed, completed, cancelled }

extension AdminOrderFilterUi on AdminOrderFilter {
  String get label => switch (this) {
    AdminOrderFilter.all => 'Все',
    AdminOrderFilter.waiting => 'Ожидают',
    AdminOrderFilter.active => 'Активные',
    AdminOrderFilter.disputed => 'Спорные',
    AdminOrderFilter.completed => 'Завершённые',
    AdminOrderFilter.cancelled => 'Отменённые',
  };

  bool matches(TajGoOrder order) => switch (this) {
    AdminOrderFilter.all => true,
    AdminOrderFilter.waiting => order.status == OrderStatus.waiting,
    AdminOrderFilter.active => const {
      OrderStatus.accepted,
      OrderStatus.pickedUp,
      OrderStatus.delivered,
    }.contains(order.status),
    AdminOrderFilter.disputed => order.status == OrderStatus.disputed,
    AdminOrderFilter.completed => order.status == OrderStatus.completed,
    AdminOrderFilter.cancelled => order.status == OrderStatus.cancelled,
  };
}

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({
    super.key,
    this.initialFilter = AdminOrderFilter.all,
  });

  final AdminOrderFilter initialFilter;

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late AdminOrderFilter _filter = widget.initialFilter;

  @override
  Widget build(BuildContext context) => AdminAccessGate(
    child: Scaffold(
      appBar: AppBar(title: const Text('Заказы')),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: AdminOrderFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = AdminOrderFilter.values[index];
                return ChoiceChip(
                  label: Text(filter.label),
                  selected: filter == _filter,
                  selectedColor: TajGoColors.darkGreen,
                  labelStyle: TextStyle(
                    color: filter == _filter ? Colors.white : TajGoColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => setState(() => _filter = filter),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TajGoOrder>>(
              stream: TajGoScope.of(context).adminRepository.ordersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _Message(
                    icon: Icons.lock_rounded,
                    text: '${snapshot.error}',
                  );
                }
                final orders = (snapshot.data ?? const <TajGoOrder>[])
                    .where(_filter.matches)
                    .toList();
                if (orders.isEmpty) {
                  return const _Message(
                    icon: Icons.inbox_rounded,
                    text: 'Заказов нет',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                TajGoBadge(
                                  text: orderStatusLabel(order.status),
                                  background: TajGoColors.secondaryBtn,
                                  foreground: TajGoColors.darkGreen,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_created(order.createdAt)} · ${order.customerName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: TajGoColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TajGoOrderCard(
                            order: order,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AdminOrderDetailsScreen(orderId: order.id),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  String _created(DateTime? value) {
    if (value == null) return '—';
    final now = DateTime.now();
    final time =
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    return value.year == now.year &&
            value.month == now.month &&
            value.day == now.day
        ? '$time · сегодня'
        : '${value.day}.${value.month} · $time';
  }
}

String orderStatusLabel(OrderStatus status) => switch (status) {
  OrderStatus.waiting => 'Ожидает',
  OrderStatus.accepted => 'Принят',
  OrderStatus.pickedUp => 'В пути',
  OrderStatus.delivered => 'Передан',
  OrderStatus.completed => 'Завершён',
  OrderStatus.disputed => 'Спорный',
  OrderStatus.cancelled => 'Отменён',
};

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: TajGoColors.muted),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
