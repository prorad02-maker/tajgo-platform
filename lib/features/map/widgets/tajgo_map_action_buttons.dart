import 'package:flutter/material.dart';

import '../../../core/constants/tajgo_colors.dart';
import 'tajgo_location_widgets.dart';

class TajGoMapActionButtons extends StatelessWidget {
  const TajGoMapActionButtons({
    super.key,
    required this.onLocate,
    this.onShowRoute,
    this.locating = false,
    this.following = false,
    this.heroPrefix = 'mapActions',
  });

  final VoidCallback? onLocate;
  final VoidCallback? onShowRoute;
  final bool locating;
  final bool following;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (onShowRoute != null) ...[
        FloatingActionButton.small(
          heroTag: '${heroPrefix}Route',
          onPressed: onShowRoute,
          backgroundColor: Colors.white,
          foregroundColor: TajGoColors.darkGreen,
          tooltip: 'Показать весь маршрут',
          child: const Icon(Icons.route_rounded),
        ),
        const SizedBox(height: 8),
      ],
      TajGoLocateButton(
        heroTag: '${heroPrefix}Locate',
        onPressed: onLocate,
        loading: locating,
        following: following,
      ),
    ],
  );
}
