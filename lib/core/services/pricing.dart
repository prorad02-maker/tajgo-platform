import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

double distanceKm(LatLng from, LatLng to) {
  final kilometers = const Distance().as(LengthUnit.Kilometer, from, to);
  return (kilometers * 10).round() / 10;
}

int etaMinutes(double kilometers) => (kilometers / 18 * 60).ceil() + 5;

num suggestedPrice(double kilometers) =>
    math.max(10, (10 + 4 * kilometers).ceil());

const double actionRadiusKm = 2.0;

bool withinActionRadius(double kilometers) => kilometers <= actionRadiusKm;

String generateConfirmationCode([math.Random? random]) {
  final value = (random ?? math.Random.secure()).nextInt(10000);
  return value.toString().padLeft(4, '0');
}
