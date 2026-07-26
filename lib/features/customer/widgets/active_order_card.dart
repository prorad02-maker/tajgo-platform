import 'package:flutter/material.dart';

import '../../../core/models/tajgo_order.dart';
import '../../../shared/design/tajgo_components.dart';
import '../order_tracking_screen.dart';

/// Карточка активного заказа клиента — акцентная (mint), ведёт в трекинг.
class ActiveOrderCard extends StatelessWidget {
  const ActiveOrderCard({super.key, required this.order, this.margin});

  final TajGoOrder order;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return TajGoCard(
      accent: true,
      margin: margin,
      padding: const EdgeInsets.all(TajGoSpacing.md),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OrderTrackingScreen(orderId: order.id),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: TajGoColors.darkGreen,
            child: Icon(
              Icons.delivery_dining_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: TajGoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusText(order.status),
                  style: TajGoTypography.bodyStrong,
                ),
                const SizedBox(height: TajGoSpacing.xxs),
                Text(
                  '${order.fromText} → ${order.toText}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TajGoTypography.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: TajGoColors.darkGreen),
        ],
      ),
    );
  }

  static String _statusText(OrderStatus status) => switch (status) {
    OrderStatus.waiting => 'Ищем курьера',
    OrderStatus.accepted => 'Курьер едет за заказом',
    OrderStatus.pickedUp => 'Заказ у курьера — едет к вам',
    OrderStatus.delivered => 'Курьер на месте',
    OrderStatus.disputed => 'Требуется решение',
    _ => 'Активная доставка',
  };
}
