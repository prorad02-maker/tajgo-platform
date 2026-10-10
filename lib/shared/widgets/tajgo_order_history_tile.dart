import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_order.dart';
import '../../core/utils/money_formatter.dart';
import 'tajgo_badge.dart';

/// Строка истории заказов: тип, маршрут, дата, цена и бейдж статуса.
class TajGoOrderHistoryTile extends StatelessWidget {
  const TajGoOrderHistoryTile({super.key, required this.order, this.onTap});

  final TajGoOrder order;
  final VoidCallback? onTap;

  static const _icons = <String, IconData>{
    'package': Icons.inventory_2_outlined,
    'food': Icons.restaurant_rounded,
    'shops': Icons.shopping_basket_outlined,
    'groceries': Icons.shopping_basket_outlined,
    'pharmacy': Icons.local_pharmacy_outlined,
    'flowers': Icons.local_florist_outlined,
    'docs': Icons.description_outlined,
  };

  String _dateLabel() {
    final created = order.createdAt;
    if (created == null) {
      return '';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(created.year, created.month, created.day);
    if (day == today) {
      return 'сегодня';
    }
    if (day == today.subtract(const Duration(days: 1))) {
      return 'вчера';
    }
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(created.day)}.${two(created.month)}${created.year == now.year ? '' : '.${created.year}'}';
  }

  (String, Color, Color) get _badge => switch (order.status) {
    OrderStatus.completed => (
      '✅ Доставлен',
      TajGoColors.mint,
      TajGoColors.darkGreen,
    ),
    OrderStatus.disputed => (
      '⚠ Спор',
      const Color(0xFFFEE2E2),
      TajGoColors.error,
    ),
    OrderStatus.cancelled => (
      '✖ Отменён',
      TajGoColors.soonBg,
      TajGoColors.soonText,
    ),
    OrderStatus.waiting => (
      'Поиск курьера',
      TajGoColors.mint,
      TajGoColors.darkGreen,
    ),
    OrderStatus.accepted ||
    OrderStatus.pickedUp => ('В пути', TajGoColors.mint, TajGoColors.darkGreen),
    OrderStatus.delivered => (
      'Ожидает подтверждения',
      TajGoColors.mint,
      TajGoColors.darkGreen,
    ),
    OrderStatus.unknown => (
      'Статус недоступен',
      TajGoColors.soonBg,
      TajGoColors.soonText,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final badge = _badge;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _icons[order.type] ?? Icons.inventory_2_outlined,
                    color: TajGoColors.darkGreen,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${order.fromText} → ${order.toText}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _dateLabel(),
                    style: const TextStyle(
                      color: TajGoColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${formatMoney(order.price)} ${order.currency}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  TajGoBadge(
                    text: badge.$1,
                    background: badge.$2,
                    foreground: badge.$3,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
