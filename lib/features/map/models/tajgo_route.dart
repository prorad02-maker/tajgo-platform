import 'package:latlong2/latlong.dart';

import 'tajgo_navigation_step.dart';

enum RouteMode { bicycle, scooter, car }

/// Старые значения walking/foot/pedestrian безопасно переводятся на велосипед.
RouteMode routeModeFromString(String? value) => switch (value) {
  'scooter' => RouteMode.scooter,
  'car' => RouteMode.car,
  _ => RouteMode.bicycle,
};

enum RouteQuality {
  road,
  approximate,
  directFallback,
  providerError,
  unavailable,
}

extension RouteQualityLabel on RouteQuality {
  String get userLabel => switch (this) {
    RouteQuality.road => 'Маршрут построен',
    RouteQuality.approximate ||
    RouteQuality.directFallback => 'Маршрут предварительный',
    RouteQuality.providerError => 'Используем предварительный маршрут',
    RouteQuality.unavailable => 'Маршрут недоступен',
  };
}

class TajGoRoute {
  const TajGoRoute({
    required this.points,
    required this.distanceKm,
    required this.etaMinutes,
    required this.isRoadRouteApproximation,
    required this.providerName,
    required this.routeQuality,
    required this.createdAt,
    this.errorMessage,
    this.steps = const [],
  });

  final List<LatLng> points;
  final double distanceKm;
  final int etaMinutes;
  final bool isRoadRouteApproximation;
  final String providerName;
  final RouteQuality routeQuality;
  final String? errorMessage;
  final DateTime createdAt;
  final List<TajGoNavigationStep> steps;

  List<LatLng> get polylinePoints => points;
  bool get isFallback => routeQuality != RouteQuality.road;
  String get qualityLabel => routeQuality.userLabel;
}
