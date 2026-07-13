import 'package:flutter/material.dart';

import '../../../core/constants/tajgo_colors.dart';
import '../models/tajgo_route.dart';

class TajGoRouteSummaryCard extends StatelessWidget {
  const TajGoRouteSummaryCard({
    super.key,
    required this.route,
    this.loading = false,
    this.onShowEntireRoute,
    this.compact = false,
  });

  final TajGoRoute? route;
  final bool loading;
  final VoidCallback? onShowEntireRoute;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final value = route;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F0),
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
              value?.isFallback == false
                  ? Icons.route_rounded
                  : Icons.timeline_rounded,
              color: value?.isFallback == false
                  ? TajGoColors.green
                  : TajGoColors.warning,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading
                      ? 'Строим маршрут…'
                      : value == null
                      ? 'Маршрут недоступен'
                      : '${value.distanceKm.toStringAsFixed(1)} км · ≈ ${value.etaMinutes} мин',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (!loading && value?.isFallback == true)
                  Text(
                    value!.qualityLabel,
                    style: const TextStyle(
                      color: TajGoColors.warning,
                      fontSize: 12,
                    ),
                  )
                else if (!loading && value != null)
                  const Text(
                    'Маршрут построен',
                    style: TextStyle(
                      color: TajGoColors.darkGreen,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (onShowEntireRoute != null)
            TextButton(
              onPressed: onShowEntireRoute,
              child: const Text('Показать весь'),
            ),
        ],
      ),
    );
  }
}
