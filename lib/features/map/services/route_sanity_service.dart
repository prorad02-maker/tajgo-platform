import 'package:latlong2/latlong.dart';

import '../../../core/services/pricing.dart' as pricing;
import '../models/tajgo_route.dart';
import 'direct_route_provider.dart';

class RouteSanityResult {
  const RouteSanityResult({
    required this.route,
    required this.directDistanceMeters,
    required this.providerDistanceMeters,
    required this.usedFallback,
    this.reason,
  });

  final TajGoRoute route;
  final double directDistanceMeters;
  final double? providerDistanceMeters;
  final bool usedFallback;
  final String? reason;

  bool get providerAccepted => !usedFallback;
}

/// Compares every provider result with an independent haversine baseline.
class RouteSanityService {
  const RouteSanityService({
    DirectRouteProvider directProvider = const DirectRouteProvider(),
  }) : _direct = directProvider;

  final DirectRouteProvider _direct;

  double directDistanceMeters(LatLng from, LatLng to) =>
      pricing.haversineDistanceKm(from, to) * 1000;

  RouteSanityResult sanitize({
    required TajGoRoute? candidate,
    required LatLng from,
    required LatLng to,
    required RouteMode mode,
    String? missingReason,
  }) {
    final directMeters = directDistanceMeters(from, to);
    final providerMeters = candidate == null
        ? null
        : candidate.distanceKm * 1000;
    final reason = _invalidReason(candidate, directMeters, providerMeters);
    if (reason == null) {
      final selectedFallback = candidate!.isFallback;
      return RouteSanityResult(
        route: candidate,
        directDistanceMeters: directMeters,
        providerDistanceMeters: providerMeters,
        usedFallback: selectedFallback,
        reason: selectedFallback ? candidate.errorMessage : null,
      );
    }

    final fallbackReason = missingReason ?? reason;
    final fallback = _direct.buildSync(
      from: from,
      to: to,
      mode: mode,
      errorMessage: fallbackReason,
      quality: candidate == null
          ? RouteQuality.directFallback
          : RouteQuality.providerError,
    );
    return RouteSanityResult(
      route: fallback,
      directDistanceMeters: directMeters,
      providerDistanceMeters: providerMeters,
      usedFallback: true,
      reason: fallbackReason,
    );
  }

  String? _invalidReason(
    TajGoRoute? route,
    double directMeters,
    double? routeMeters,
  ) {
    if (route == null) return 'route is null';
    if (route.points.length < 2) return 'route has fewer than two points';
    if (routeMeters == null || !routeMeters.isFinite || routeMeters <= 0) {
      return 'route distance is not positive';
    }

    if (route.isFallback) {
      final tolerance = (directMeters * 0.05).clamp(2.0, 20.0);
      if ((routeMeters - directMeters).abs() > tolerance) {
        return 'fallback distance differs from direct baseline';
      }
      return null;
    }

    if (directMeters > 0 && routeMeters < directMeters * 0.6) {
      return 'provider distance is below 60% of direct baseline';
    }
    if (directMeters > 0 && routeMeters > directMeters * 5) {
      return 'provider distance exceeds 5x direct baseline';
    }
    if (directMeters > 50 && routeMeters < 10) {
      return 'provider distance would show less than 10 m';
    }
    if (directMeters >= 20 && routeMeters < 20) {
      return 'different points produced a route below 20 m';
    }
    return null;
  }
}
