import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_order.dart';
import 'tajgo_badge.dart';

/// Строка истории заказов: тип, маршрут, дата, цена и бейдж статуса.
class TajGoOrderHistoryTile extends StatelessWidget {
  const TajGoOrderHistoryTile({super.key, required this.order, this.onTap});

  final TajGoOrder order;
  final VoidCallback? onTap;

  static const _emoji = <String, String>{
    'package': '📦',
    'food': '🍔',
    'shops': '🛒',
    'pharmacy': '💊',
    'flowers': '🌸',
    'docs': '📄',
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
    return '${two(created.day)}.${two(created.month)}';
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
    _ => ('✖ Отменён', TajGoColors.soonBg, TajGoColors.soonText),
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
          child: Row(
            children: [
              Text(
                _emoji[order.type] ?? '📦',
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.fromText} → ${order.toText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dateLabel(),
                      style: const TextStyle(
                        color: TajGoColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${order.price} ${order.currency}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
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
