import 'package:latlong2/latlong.dart';

import 'pricing.dart' as pricing;

class TajGoRoute {
  const TajGoRoute({
    required this.distanceKm,
    required this.etaMinutes,
    required this.polylinePoints,
    required this.isRoadRouteApproximation,
  });

  final double distanceKm;
  final int etaMinutes;
  final List<LatLng> polylinePoints;
  final bool isRoadRouteApproximation;
}

class RouteService {
  const RouteService();

  TajGoRoute directRoute({required LatLng from, required LatLng to}) {
    final distance = pricing.distanceKm(from, to);
    return TajGoRoute(
      distanceKm: distance,
      etaMinutes: pricing.courierNavigationEtaMinutes(distance),
      polylinePoints: [from, to],
      isRoadRouteApproximation: true,
    );
  }

  Future<TajGoRoute> roadRoute({
    required LatLng from,
    required LatLng to,
  }) async => directRoute(from: from, to: to);
}
