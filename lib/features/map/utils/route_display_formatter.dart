import '../models/tajgo_route.dart';

String formatRouteDistance(double distanceKm) {
  if (distanceKm < 1) {
    final meters = (distanceKm * 1000).round();
    if (meters < 10) return 'менее 10 м';
    return '$meters м';
  }
  return '${distanceKm.toStringAsFixed(1)} км';
}

String formatRouteEta(int etaMinutes) => '≈ ${etaMinutes.clamp(1, 999)} мин';

String formatRouteQuality(TajGoRoute? route) =>
    route?.routeQuality == RouteQuality.road
    ? 'Маршрут построен'
    : 'Маршрут предварительный';
