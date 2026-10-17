import 'package:flutter/material.dart';

import '../../core/models/app_user.dart';
import '../../core/models/tajgo_order.dart';
import '../../core/services/user_error_message.dart';
import '../../shared/widgets/tajgo_order_history_tile.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../../shared/widgets/tajgo_state_view.dart';
import '../courier/courier_order_screen.dart';
import '../customer/order_tracking_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({
    super.key,
    required this.currentMode,
    this.loadOrders,
  });
  final String currentMode;
  final Stream<List<TajGoOrder>> Function()? loadOrders;

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  Stream<List<TajGoOrder>>? _orders;

  Stream<List<TajGoOrder>> _load() {
    if (widget.loadOrders != null) return widget.loadOrders!();
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser!.uid;
    return widget.currentMode == AppUserRole.courier
        ? scope.courierRepository.historyStream(uid)
        : scope.orderRepository.historyStream(uid);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _orders ??= _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('История заказов')),
    body: StreamBuilder<List<TajGoOrder>>(
      stream: _orders,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TajGoStateView(
            icon: Icons.cloud_off_rounded,
            title: 'Не удалось загрузить заказы',
            message: userErrorMessage(snapshot.error),
            onRetry: () => setState(() => _orders = _load()),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!;
        if (orders.isEmpty) {
          return const TajGoStateView(
            icon: Icons.receipt_long_outlined,
            title: 'Заказов пока нет',
            message: 'Здесь появятся ваши доставки и их статусы.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length + (orders.length == 100 ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == orders.length) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Последние 100 заказов',
                  textAlign: TextAlign.center,
                ),
              );
            }
            final order = orders[index];
            return TajGoOrderHistoryTile(
              order: order,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => widget.currentMode == AppUserRole.courier
                      ? CourierOrderScreen(orderId: order.id)
                      : OrderTrackingScreen(orderId: order.id),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
