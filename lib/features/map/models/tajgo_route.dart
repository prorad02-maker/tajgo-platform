import 'package:latlong2/latlong.dart';

enum RouteMode { walking, bicycle, scooter, car }

enum RouteQuality { road, directFallback, unavailable }

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
  });

  final List<LatLng> points;
  final double distanceKm;
  final int etaMinutes;
  final bool isRoadRouteApproximation;
  final String providerName;
  final RouteQuality routeQuality;
  final String? errorMessage;
  final DateTime createdAt;

  List<LatLng> get polylinePoints => points;
  bool get isFallback => routeQuality != RouteQuality.road;
}
