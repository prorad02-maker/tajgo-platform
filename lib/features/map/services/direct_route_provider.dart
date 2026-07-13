import 'package:latlong2/latlong.dart';

import '../../../core/services/pricing.dart' as pricing;
import '../models/tajgo_route.dart';
import 'route_provider.dart';

class DirectRouteProvider implements RouteProvider {
  const DirectRouteProvider();

  @override
  String get name => 'direct';

  @override
  Future<TajGoRoute> buildRoute({
    required LatLng from,
    required LatLng to,
    required RouteMode mode,
  }) async => buildSync(from: from, to: to, mode: mode);

  TajGoRoute buildSync({
    required LatLng from,
    required LatLng to,
    required RouteMode mode,
    String? errorMessage,
  }) {
    final distance = pricing.distanceKm(from, to);
    final speedKmH = switch (mode) {
      RouteMode.walking => 4.5,
      RouteMode.bicycle => 18,
      RouteMode.scooter => 24,
      RouteMode.car => 28,
    };
    final eta = ((distance / speedKmH) * 60).ceil().clamp(1, 999);
    return TajGoRoute(
      points: [from, to],
      distanceKm: distance,
      etaMinutes: eta,
      isRoadRouteApproximation: true,
      providerName: name,
      routeQuality: RouteQuality.directFallback,
      errorMessage: errorMessage,
      createdAt: DateTime.now().toUtc(),
    );
  }
}
