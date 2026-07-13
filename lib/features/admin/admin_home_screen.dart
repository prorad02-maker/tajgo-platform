import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_courier.dart';
import '../../core/models/tajgo_order.dart';
import '../../shared/widgets/tajgo_badge.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../../shared/widgets/tajgo_stat_card.dart';
import 'admin_couriers_screen.dart';
import 'admin_orders_screen.dart';
import 'dispatch_map_screen.dart';
import 'widgets/admin_access_gate.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminAccessGate(
    child: Scaffold(
      body: StreamBuilder<List<TajGoOrder>>(
        stream: TajGoScope.of(context).adminRepository.ordersStream(),
        builder: (context, allSnapshot) => StreamBuilder<List<TajGoOrder>>(
          stream: TajGoScope.of(context).adminRepository.todayOrdersStream(),
          builder: (context, todaySnapshot) => StreamBuilder<List<TajGoCourier>>(
            stream: TajGoScope.of(context).adminRepository.couriersStream(),
            builder: (context, courierSnapshot) {
              final all = allSnapshot.data ?? const <TajGoOrder>[];
              final today = todaySnapshot.data ?? const <TajGoOrder>[];
              final couriers = courierSnapshot.data ?? const <TajGoCourier>[];
              final loading =
                  !allSnapshot.hasData ||
                  !todaySnapshot.hasData ||
                  !courierSnapshot.hasData;
              final active = all
                  .where(
                    (order) => const {
                      OrderStatus.waiting,
                      OrderStatus.accepted,
                      OrderStatus.pickedUp,
                      OrderStatus.delivered,
                    }.contains(order.status),
                  )
                  .length;
              final completed = today
                  .where((order) => order.status == OrderStatus.completed)
                  .toList();
              final disputed = all
                  .where((order) => order.status == OrderStatus.disputed)
                  .length;
              final turnover = completed.fold<num>(
                0,
                (sum, order) => sum + order.price,
              );
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  const _AdminHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (allSnapshot.hasError ||
                            todaySnapshot.hasError ||
                            courierSnapshot.hasError)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Нет доступа к данным. Проверьте admin-role и Rules.',
                              style: TextStyle(color: TajGoColors.error),
                            ),
                          ),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.45,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          children: [
                            _stat(
                              context,
                              '📦',
                              loading ? '—' : '${today.length}',
                              'Заказов сегодня',
                              AdminOrderFilter.all,
                            ),
                            _stat(
                              context,
                              '🔄',
                              loading ? '—' : '$active',
                              'Активные сейчас',
                              AdminOrderFilter.active,
                            ),
                            _stat(
                              context,
                              '✅',
                              loading ? '—' : '${completed.length}',
                              'Завершённые',
                              AdminOrderFilter.completed,
                            ),
                            _stat(
                              context,
                              '⚠️',
                              loading ? '—' : '$disputed',
                              'Спорные',
                              AdminOrderFilter.disputed,
                            ),
                            _stat(
                              context,
                              '🛵',
                              loading
                                  ? '—'
                                  : '${couriers.where((c) => c.online).length}',
                              'Курьеров на линии',
                              null,
                            ),
                            _stat(
                              context,
                              '💰',
                              loading ? '—' : '$turnover TJS',
                              'Оборот сегодня',
                              AdminOrderFilter.completed,
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Разделы',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _NavCard(
                          icon: Icons.receipt_long_rounded,
                          title: 'Заказы',
                          subtitle: 'Лента, фильтры и детали',
                          onTap: () =>
                              _open(context, const AdminOrdersScreen()),
                        ),
                        _NavCard(
                          icon: Icons.delivery_dining_rounded,
                          title: 'Курьеры',
                          subtitle: 'Линия, статистика и активные заказы',
                          onTap: () =>
                              _open(context, const AdminCouriersScreen()),
                        ),
                        _NavCard(
                          icon: Icons.map_rounded,
                          title: 'Карта города',
                          subtitle: 'Курьеры и заказы Худжанда',
                          onTap: () =>
                              _open(context, const DispatchMapScreen()),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _stat(
    BuildContext context,
    String icon,
    String value,
    String label,
    AdminOrderFilter? filter,
  ) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: filter == null
        ? () => _open(context, const AdminCouriersScreen())
        : () => _open(context, AdminOrdersScreen(initialFilter: filter)),
    child: TajGoStatCard(icon: icon, value: value, label: label),
  );

  void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 20,
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  '🛠 Управление TajGo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TajGoBadge(
                text: kDebugMode ? 'debug' : 'admin',
                background: TajGoColors.lime,
                foreground: TajGoColors.ink,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '📍 Худжанд · ${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: TajGoColors.mint,
        child: Icon(icon, color: TajGoColors.darkGreen),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}
