import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_courier.dart';
import '../../shared/widgets/tajgo_badge.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'admin_order_details_screen.dart';
import 'admin_courier_application_details_screen.dart';
import 'dispatch_map_screen.dart';
import 'widgets/admin_access_gate.dart';
import 'widgets/tajgo_admin_action_button.dart';

class AdminCouriersScreen extends StatelessWidget {
  const AdminCouriersScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminAccessGate(
    child: Scaffold(
      appBar: AppBar(title: const Text('Курьеры')),
      body: StreamBuilder<List<TajGoCourier>>(
        stream: TajGoScope.of(context).adminRepository.couriersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }
          final couriers = snapshot.data ?? const <TajGoCourier>[];
          if (couriers.isEmpty) {
            return const Center(child: Text('Курьеров пока нет'));
          }
          final online = couriers.where((courier) => courier.online).toList();
          final offline = couriers.where((courier) => !courier.online).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _Section(title: 'На линии', couriers: online),
              const SizedBox(height: 18),
              _Section(title: 'Не на линии', couriers: offline),
            ],
          );
        },
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.couriers});
  final String title;
  final List<TajGoCourier> couriers;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$title · ${couriers.length}',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      if (couriers.isEmpty)
        const Text('Пусто', style: TextStyle(color: TajGoColors.muted))
      else
        ...couriers.map((courier) => _CourierCard(courier: courier)),
    ],
  );
}

class _CourierCard extends StatelessWidget {
  const _CourierCard({required this.courier});
  final TajGoCourier courier;

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    final adminId = scope.authService.currentUser!.uid;
    final stale =
        courier.locationUpdatedAt == null ||
        DateTime.now().difference(courier.locationUpdatedAt!).inMinutes > 10;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: courier.online
                      ? TajGoColors.mint
                      : TajGoColors.soonBg,
                  child: Icon(
                    Icons.delivery_dining_rounded,
                    color: courier.online
                        ? TajGoColors.darkGreen
                        : TajGoColors.muted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courier.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        courier.phoneNumber ?? 'Телефон не указан',
                        style: const TextStyle(color: TajGoColors.muted),
                      ),
                    ],
                  ),
                ),
                TajGoBadge(
                  text: courier.online ? '🟢 online' : '⚪ offline',
                  background: courier.online
                      ? TajGoColors.mint
                      : TajGoColors.soonBg,
                  foreground: courier.online
                      ? TajGoColors.darkGreen
                      : TajGoColors.muted,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Text('⭐ ${courier.rating.toStringAsFixed(1)}'),
                Text('🏆 ${courier.score}'),
                Text('💰 ${courier.earningsToday} TJS'),
                Text('📦 ${courier.ordersToday}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              courier.locationUpdatedAt == null
                  ? 'Координат нет'
                  : 'Координаты обновлены ${DateTime.now().difference(courier.locationUpdatedAt!).inMinutes} мин назад',
              style: TextStyle(
                color: stale ? TajGoColors.warning : TajGoColors.muted,
                fontSize: 12,
              ),
            ),
            if (courier.activeOrderId != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminOrderDetailsScreen(
                      orderId: courier.activeOrderId!,
                    ),
                  ),
                ),
                child: Text(
                  'Активный заказ: ${courier.activeOrderId}',
                  style: const TextStyle(
                    color: TajGoColors.darkGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AdminCourierApplicationDetailsScreen(
                        uid: courier.uid,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Проверка'),
                ),
                OutlinedButton.icon(
                  onPressed: courier.location == null
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DispatchMapScreen(focusCourierId: courier.uid),
                          ),
                        ),
                  icon: const Icon(Icons.location_on_rounded),
                  label: const Text('На карте'),
                ),
                if (courier.online)
                  TajGoAdminActionButton(
                    label: 'Снять с линии',
                    title: 'Снять курьера с линии?',
                    message:
                        'Курьер перестанет показываться клиентам и получать новые заказы.',
                    onConfirm: () => scope.adminRepository.forceOffline(
                      courierId: courier.uid,
                      adminId: adminId,
                    ),
                  ),
                if (courier.activeOrderId != null)
                  TajGoAdminActionButton(
                    label: 'Очистить activeOrderId',
                    title: 'Очистить активный заказ?',
                    message:
                        'Курьер будет разблокирован. Сам заказ не изменится.',
                    onConfirm: () => scope.adminRepository.clearActiveOrder(
                      courierId: courier.uid,
                      adminId: adminId,
                    ),
                    dangerous: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
