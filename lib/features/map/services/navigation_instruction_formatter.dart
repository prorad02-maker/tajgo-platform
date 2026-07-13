import '../models/navigation_state.dart';

class NavigationInstructionFormatter {
  const NavigationInstructionFormatter();

  String format({
    required String maneuverType,
    required String modifier,
    required String streetName,
    required double distanceMeters,
    NavigationTarget? target,
  }) {
    final distance = _distance(distanceMeters);
    final street = streetName.trim().isEmpty ? '' : ' на ${streetName.trim()}';
    final normalizedType = maneuverType.toLowerCase();
    final normalizedModifier = modifier.toLowerCase();

    if (normalizedType == 'arrive') {
      return switch (target) {
        NavigationTarget.pickup => 'Вы прибыли к точке забора',
        NavigationTarget.dropoff => 'Вы прибыли к клиенту',
        null => 'Вы прибыли к точке',
      };
    }
    if (normalizedType == 'depart') {
      return 'Начните движение${street.isEmpty ? '' : street}';
    }
    if (normalizedType == 'roundabout' ||
        normalizedType == 'rotary' ||
        normalizedType == 'roundabout turn') {
      return '$distance въезжайте на круговое движение';
    }
    if (normalizedType == 'merge') {
      return '$distance перестройтесь в поток$street';
    }
    if (normalizedType == 'fork') {
      final side = _side(normalizedModifier);
      return '$distance держитесь $side$street';
    }
    if (normalizedType == 'uturn' ||
        normalizedModifier == 'uturn' ||
        normalizedModifier == 'u-turn') {
      return '$distance развернитесь, когда будет безопасно';
    }
    if (normalizedType == 'turn') {
      return '$distance поверните ${_side(normalizedModifier)}$street';
    }
    if (normalizedType == 'continue' || normalizedType == 'new name') {
      return '$distance двигайтесь прямо$street';
    }
    return '$distance двигайтесь к точке по маршруту';
  }

  String fallback({NavigationTarget target = NavigationTarget.pickup}) =>
      target == NavigationTarget.pickup
      ? 'Двигайтесь к точке забора'
      : 'Двигайтесь к клиенту';

  String _distance(double meters) {
    if (meters <= 20) return 'Сейчас';
    if (meters < 1000) return 'Через ${_roundMeters(meters)} м';
    return 'Через ${(meters / 1000).toStringAsFixed(1)} км';
  }

  int _roundMeters(double meters) {
    if (meters < 100) return (meters / 10).round() * 10;
    return (meters / 50).round() * 50;
  }

  String _side(String modifier) => switch (modifier) {
    'left' || 'slight left' || 'sharp left' => 'налево',
    'right' || 'slight right' || 'sharp right' => 'направо',
    _ => 'прямо',
  };
}
