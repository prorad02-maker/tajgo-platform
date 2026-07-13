import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/tajgo_colors.dart';

/// Синий маркер текущего пользователя. Стрелка используется в навигации.
class TajGoCurrentLocationMarker extends StatelessWidget {
  const TajGoCurrentLocationMarker({
    super.key,
    this.heading,
    this.navigation = false,
  });

  final double? heading;
  final bool navigation;

  @override
  Widget build(BuildContext context) {
    final direction = (heading ?? 0) * math.pi / 180;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: navigation ? 42 : 34,
          height: navigation ? 42 : 34,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: navigation ? 24 : 18,
          height: navigation ? 24 : 18,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 6),
            ],
          ),
          child: navigation
              ? Transform.rotate(
                  angle: direction,
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

/// Одинаковая кнопка «моё местоположение» на всех картах TajGo.
class TajGoLocateButton extends StatelessWidget {
  const TajGoLocateButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.following = false,
    this.heroTag,
  });

  final VoidCallback? onPressed;
  final bool loading;
  final bool following;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) => FloatingActionButton.small(
    heroTag: heroTag,
    onPressed: loading ? null : onPressed,
    backgroundColor: Colors.white,
    foregroundColor: TajGoColors.darkGreen,
    tooltip: following
        ? 'Карта следует за вами'
        : 'Показать моё местоположение',
    child: loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Icon(following ? Icons.gps_fixed_rounded : Icons.my_location_rounded),
  );
}
