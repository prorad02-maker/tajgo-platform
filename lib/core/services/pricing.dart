import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

double haversineDistanceKm(LatLng from, LatLng to) =>
    const Distance().as(LengthUnit.Kilometer, from, to);

double distanceKm(LatLng from, LatLng to) {
  final kilometers = haversineDistanceKm(from, to);
  return (kilometers * 10).round() / 10;
}

int etaMinutes(double kilometers) => (kilometers / 18 * 60).ceil() + 5;

int courierNavigationEtaMinutes(double kilometers) =>
    ((kilometers / 18) * 60).ceil().clamp(1, 999);

num suggestedPrice(double kilometers) =>
    math.max(10, (10 + 4 * kilometers).ceil());

const double actionRadiusKm = 2.0;

bool withinActionRadius(double kilometers) => kilometers <= actionRadiusKm;

String generateConfirmationCode([math.Random? random]) {
  final value = (random ?? math.Random.secure()).nextInt(10000);
  return value.toString().padLeft(4, '0');
}
