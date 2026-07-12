import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

double distanceKm(LatLng from, LatLng to) {
  final kilometers = const Distance().as(LengthUnit.Kilometer, from, to);
  return (kilometers * 10).round() / 10;
}

int etaMinutes(double kilometers) => (kilometers / 18 * 60).ceil() + 5;

num suggestedPrice(double kilometers) =>
    math.max(10, (10 + 4 * kilometers).ceil());
