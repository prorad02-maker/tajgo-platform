import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/tajgo_route.dart';
import '../models/tajgo_route_progress.dart';
import '../models/tajgo_navigation_step.dart';

class NearestRoutePoint {
  const NearestRoutePoint({
    required this.polylineIndex,
    required this.point,
    required this.distanceMeters,
  });

  final int polylineIndex;
  final LatLng point;
  final double distanceMeters;
}

class RouteProgressService {
  const RouteProgressService({this.offRouteThresholdMeters = 150});

  final double offRouteThresholdMeters;

  TajGoRouteProgress calculateProgress(
    TajGoRoute route,
    LatLng currentLocation,
  ) {
    if (route.points.length < 2) {
      return TajGoRouteProgress(
        remainingDistanceKm: route.distanceKm,
        remainingEtaMinutes: route.etaMinutes,
        passedDistanceKm: 0,
        distanceToRouteMeters: 0,
        nextStep: route.steps.firstOrNull,
        currentStepIndex: 0,
        isOffRoute: false,
        routeCompletionPercent: 0,
      );
    }
    final nearest = findNearestPolylinePoint(route.points, currentLocation);
    final remainingKm = calculateRemainingDistance(
      route.points,
      nearest.polylineIndex,
      nearest.point,
    );
    final routeDistance = math.max(route.distanceKm, 0.001);
    final passedKm = math.max(0, routeDistance - remainingKm).toDouble();
    final completion = (passedKm / routeDistance * 100)
        .clamp(0, 100)
        .toDouble();
    final currentStepIndex = _currentStepIndex(route, nearest.polylineIndex);
    return TajGoRouteProgress(
      remainingDistanceKm: remainingKm,
      remainingEtaMinutes: math.max(
        0,
        (route.etaMinutes * (remainingKm / routeDistance)).ceil(),
      ),
      passedDistanceKm: passedKm,
      distanceToRouteMeters: nearest.distanceMeters,
      nextStep: getNextStep(route, nearest.polylineIndex),
      currentStepIndex: currentStepIndex,
      isOffRoute:
          !route.isFallback && nearest.distanceMeters > offRouteThresholdMeters,
      routeCompletionPercent: completion,
    );
  }

  NearestRoutePoint findNearestPolylinePoint(
    List<LatLng> points,
    LatLng location,
  ) {
    var nearestDistance = double.infinity;
    var nearestPoint = points.first;
    var nearestIndex = 0;
    for (var index = 0; index < points.length - 1; index++) {
      final projection = _projectToSegment(
        location,
        points[index],
        points[index + 1],
      );
      if (projection.$2 < nearestDistance) {
        nearestDistance = projection.$2;
        nearestPoint = projection.$1;
        nearestIndex = index;
      }
    }
    return NearestRoutePoint(
      polylineIndex: nearestIndex,
      point: nearestPoint,
      distanceMeters: nearestDistance,
    );
  }

  double calculateDistanceToRoute(List<LatLng> points, LatLng location) =>
      findNearestPolylinePoint(points, location).distanceMeters;

  double calculateRemainingDistance(
    List<LatLng> points,
    int nearestIndex,
    LatLng currentLocation,
  ) {
    const distance = Distance();
    var meters = distance.as(
      LengthUnit.Meter,
      currentLocation,
      points[(nearestIndex + 1).clamp(0, points.length - 1)],
    );
    for (var index = nearestIndex + 1; index < points.length - 1; index++) {
      meters += distance.as(LengthUnit.Meter, points[index], points[index + 1]);
    }
    return meters / 1000;
  }

  TajGoNavigationStep? getNextStep(TajGoRoute route, int polylineIndex) {
    if (route.steps.isEmpty) return null;
    return route.steps.firstWhere(
      (step) => step.polylineIndex > polylineIndex,
      orElse: () => route.steps.last,
    );
  }

  bool detectOffRoute(TajGoRoute route, LatLng location) =>
      !route.isFallback &&
      calculateDistanceToRoute(route.points, location) >
          offRouteThresholdMeters;

  int _currentStepIndex(TajGoRoute route, int polylineIndex) {
    if (route.steps.isEmpty) return 0;
    var result = 0;
    for (var index = 0; index < route.steps.length; index++) {
      if (route.steps[index].polylineIndex <= polylineIndex) result = index;
    }
    return result;
  }

  (LatLng, double) _projectToSegment(LatLng p, LatLng a, LatLng b) {
    const earth = 6371000.0;
    final referenceLat = p.latitude * math.pi / 180;
    (double, double) xy(LatLng point) => (
      point.longitude * math.pi / 180 * earth * math.cos(referenceLat),
      point.latitude * math.pi / 180 * earth,
    );

    final point = xy(p);
    final start = xy(a);
    final end = xy(b);
    final dx = end.$1 - start.$1;
    final dy = end.$2 - start.$2;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0
        ? 0.0
        : (((point.$1 - start.$1) * dx + (point.$2 - start.$2) * dy) /
                  lengthSquared)
              .clamp(0.0, 1.0);
    final x = start.$1 + t * dx;
    final y = start.$2 + t * dy;
    final meters = math.sqrt(
      math.pow(point.$1 - x, 2) + math.pow(point.$2 - y, 2),
    );
    return (
      LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      ),
      meters,
    );
  }
}
