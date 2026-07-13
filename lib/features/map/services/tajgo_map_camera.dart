import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Единое плавное перемещение карты для клиентских и курьерских экранов.
class TajGoMapCamera {
  static const double cityZoom = 16.5;
  static const double navigationZoom = 17;

  int _animationId = 0;
  DateTime? _lastAnimationAt;
  LatLng? _lastTarget;

  Future<void> animateTo({
    required MapController controller,
    required LatLng target,
    double zoom = cityZoom,
    Duration duration = const Duration(milliseconds: 420),
  }) async {
    final now = DateTime.now();
    final lastAt = _lastAnimationAt;
    final lastTarget = _lastTarget;
    if (lastAt != null &&
        lastTarget != null &&
        now.difference(lastAt) < const Duration(milliseconds: 250) &&
        const Distance().as(LengthUnit.Meter, lastTarget, target) < 5) {
      return;
    }
    _lastAnimationAt = now;
    _lastTarget = target;
    final animationId = ++_animationId;
    try {
      final start = controller.camera;
      final startCenter = start.center;
      final startZoom = start.zoom;
      final steps = (duration.inMilliseconds / 16).ceil().clamp(1, 60).toInt();

      for (var step = 1; step <= steps; step++) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        if (animationId != _animationId) {
          return;
        }
        final progress = Curves.easeOutCubic.transform(step / steps);
        controller.move(
          LatLng(
            startCenter.latitude +
                (target.latitude - startCenter.latitude) * progress,
            startCenter.longitude +
                (target.longitude - startCenter.longitude) * progress,
          ),
          startZoom + (zoom - startZoom) * progress,
        );
      }
    } catch (_) {
      // Карта могла ещё не завершить первый layout. В этом случае безопасно
      // применяем итоговую позицию без анимации.
      try {
        controller.move(target, zoom);
      } catch (_) {
        // Экран мог быть закрыт во время анимации.
      }
    }
  }

  void stop() => _animationId++;
}
