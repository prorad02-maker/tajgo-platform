import 'package:flutter/material.dart';

import '../../../core/constants/tajgo_colors.dart';
import '../models/tajgo_route.dart';
import '../utils/route_display_formatter.dart';

class TajGoRouteSummaryCard extends StatelessWidget {
  const TajGoRouteSummaryCard({
    super.key,
    required this.route,
    this.loading = false,
    this.onShowEntireRoute,
    this.compact = false,
    this.directBaselineMeters,
    this.pointsTooClose = false,
  });

  final TajGoRoute? route;
  final bool loading;
  final VoidCallback? onShowEntireRoute;
  final bool compact;
  final double? directBaselineMeters;
  final bool pointsTooClose;

  @override
  Widget build(BuildContext context) {
    final value = route;
    final fallback = value?.isFallback ?? true;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: fallback ? const Color(0xFFFFF8E7) : const Color(0xFFF2F7F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Icon(
              fallback ? Icons.timeline_rounded : Icons.route_rounded,
              color: fallback ? TajGoColors.warning : TajGoColors.green,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pointsTooClose
                      ? 'Выберите другую точку доставки'
                      : loading
                      ? 'Строим маршрут…'
                      : value == null
                      ? 'Маршрут недоступен'
                      : '${formatRouteDistance(value.distanceKm, directBaselineMeters: directBaselineMeters)} · '
                            '${formatRouteEta(value.etaMinutes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (!loading && !pointsTooClose && value != null)
                  Text(
                    formatRouteQuality(value),
                    style: TextStyle(
                      color: fallback
                          ? TajGoColors.warning
                          : TajGoColors.darkGreen,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (onShowEntireRoute != null && value != null)
            TextButton(
              onPressed: onShowEntireRoute,
              child: const Text('Показать весь'),
            ),
        ],
      ),
    );
  }
}
