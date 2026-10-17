import 'package:flutter/material.dart';
import '../../../core/models/tajgo_order.dart';
import '../../../shared/widgets/tajgo_order_card.dart';
import '../order_tracking_screen.dart';

class ActiveOrderCard extends StatelessWidget {
  const ActiveOrderCard({super.key, required this.order, this.margin});
  final TajGoOrder order;
  final EdgeInsetsGeometry? margin;
  @override
  Widget build(BuildContext context) => Padding(
    padding: margin ?? EdgeInsets.zero,
    child: TajGoOrderCard(
      order: order,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OrderTrackingScreen(orderId: order.id),
        ),
      ),
    ),
  );
}
