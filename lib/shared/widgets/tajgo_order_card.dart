import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_order.dart';
import 'tajgo_badge.dart';

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

  static const _types = <String, (String, String)>{
    'package': ('📦', 'Посылка'),
    'food': ('🍔', 'Еда'),
    'shops': ('🛒', 'Магазины'),
    'pharmacy': ('💊', 'Аптека'),
    'flowers': ('🌸', 'Цветы'),
    'docs': ('📄', 'Документы'),
  };

  @override
  Widget build(BuildContext context) {
    final type = _types[order.type] ?? _types['package']!;
    final meta = <String>[
      if (order.distanceKm != null) '${order.distanceKm} км',
      if (order.etaMinutes != null) '~${order.etaMinutes} мин',
      '${order.price} ${order.currency}',
    ].join(' · ');
    return Card(
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(type.$1, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type.$2,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TajGoBadge(
                    text: '${order.price} ${order.currency}',
                    background: TajGoColors.mint,
                    foreground: TajGoColors.darkGreen,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${order.fromText} → ${order.toText}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                meta,
                style: const TextStyle(color: TajGoColors.muted, fontSize: 13),
              ),
              if (actions != null) ...[const SizedBox(height: 14), actions!],
            ],
          ),
        ),
      ),
    );
  }
}
