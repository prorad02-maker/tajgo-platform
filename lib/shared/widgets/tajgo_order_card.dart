import 'package:flutter/material.dart';
import '../../core/constants/tajgo_colors.dart';
import '../../core/design/tajgo_money.dart';
import '../../core/models/tajgo_order.dart';
import '../delivery/delivery_widgets.dart';

class TajGoOrderCard extends StatelessWidget {
  const TajGoOrderCard({
    super.key,
    required this.order,
    this.actions,
    this.backgroundColor,
    this.onTap,
  });
  final TajGoOrder order;
  final Widget? actions;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  static const _types = <String, (IconData, String)>{
    'package': (Icons.inventory_2_outlined, 'Посылка'),
    'food': (Icons.restaurant_outlined, 'Еда'),
    'shops': (Icons.shopping_bag_outlined, 'Покупки'),
    'pharmacy': (Icons.local_pharmacy_outlined, 'Аптека'),
    'flowers': (Icons.local_florist_outlined, 'Цветы'),
    'docs': (Icons.description_outlined, 'Документы'),
  };
  @override
  Widget build(BuildContext context) {
    final type = _types[order.type] ?? _types['package']!;
    return Card(
      color: backgroundColor ?? Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFDEE8E0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF5EF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      type.$1,
                      color: TajGoColors.deepGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      type.$2,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.arrow_outward_rounded,
                      size: 20,
                      color: TajGoColors.muted,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  DeliveryPill(
                    label: deliveryStatusLabel(order.status),
                    warning:
                        order.status == OrderStatus.disputed ||
                        order.status == OrderStatus.cancelled,
                  ),
                  if (order.isTestOrder)
                    const DeliveryPill(label: 'ТЕСТ', warning: true),
                ],
              ),
              const SizedBox(height: 16),
              DeliveryRouteStops(
                from: order.fromText,
                to: order.toText,
                compact: true,
              ),
              if ((order.comment ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  order.comment!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TajGoColors.muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: Color(0xFFE5ECE6)),
              ),
              const Text(
                'Стоимость доставки',
                style: TextStyle(color: TajGoColors.muted, fontSize: 12),
              ),
              Text(
                TajGoMoney.format(order.effectivePrice),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: TajGoColors.ink,
                ),
              ),
              if (order.distanceKm != null || order.etaMinutes != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (order.distanceKm != null)
                      DeliveryPill(
                        label: '${order.distanceKm} км',
                        icon: Icons.route_rounded,
                      ),
                    if (order.etaMinutes != null)
                      DeliveryPill(
                        label: '≈ ${order.etaMinutes} мин',
                        icon: Icons.schedule_rounded,
                      ),
                  ],
                ),
              ],
              if (actions != null) ...[const SizedBox(height: 16), actions!],
            ],
          ),
        ),
      ),
    );
  }
}
