import '../models/tajgo_route.dart';

String formatDistanceMeters(double meters, {double? directBaselineMeters}) {
  final safeMeters = (!meters.isFinite || meters < 0) ? 0.0 : meters;
  final baseline = directBaselineMeters;
  final validBaseline = baseline != null && baseline.isFinite && baseline >= 0;
  final displayMeters = validBaseline && baseline >= 10 && safeMeters < 10
      ? baseline
      : safeMeters;
  if (displayMeters < 10) return 'менее 10 м';
  if (displayMeters < 950) return '${displayMeters.round()} м';
  return '${(displayMeters / 1000).toStringAsFixed(1)} км';
}

String formatRouteDistance(double distanceKm, {double? directBaselineMeters}) =>
    formatDistanceMeters(
      distanceKm * 1000,
      directBaselineMeters: directBaselineMeters,
    );

String formatRouteEta(int etaMinutes) => '≈ ${etaMinutes.clamp(1, 999)} мин';

String formatRouteQuality(TajGoRoute? route) =>
    route?.routeQuality == RouteQuality.road
    ? 'Маршрут построен'
    : 'Маршрут предварительный';
