import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

double haversineDistanceKm(LatLng from, LatLng to) => const DistanceHaversine(
  roundResult: false,
).as(LengthUnit.Kilometer, from, to);

double distanceKm(LatLng from, LatLng to) {
  final kilometers = haversineDistanceKm(from, to);
  return (kilometers * 10).round() / 10;
}

int etaMinutes(double kilometers) => (kilometers / 18 * 60).ceil() + 5;

int courierNavigationEtaMinutes(double kilometers) =>
    ((kilometers / 18) * 60).ceil().clamp(1, 999);

const num minimumPrice = 10;
const num basePrice = 7;
const num pricePerKm = 3;

class ClientPriceValidation {
  const ClientPriceValidation({
    required this.isValid,
    required this.requiresConfirmation,
    this.value,
    this.message,
  });

  final bool isValid;
  final bool requiresConfirmation;
  final int? value;
  final String? message;
}

ClientPriceValidation validateClientPrice({
  required String rawValue,
  required num recommendedPrice,
  num minimum = minimumPrice,
}) {
  final normalized = rawValue.trim();
  if (!RegExp(r'^\d+$').hasMatch(normalized)) {
    return const ClientPriceValidation(
      isValid: false,
      requiresConfirmation: false,
      message: 'Укажите цену целым числом в сомони.',
    );
  }
  final value = int.tryParse(normalized);
  if (value == null || value < minimum) {
    return ClientPriceValidation(
      isValid: false,
      requiresConfirmation: false,
      message: 'Минимальная цена — ${minimum.toInt()} TJS.',
    );
  }
  return ClientPriceValidation(
    isValid: true,
    requiresConfirmation: value >= recommendedPrice * 2,
    value: value,
  );
}

num suggestedPrice(double kilometers) =>
    math.max(minimumPrice, (basePrice + pricePerKm * kilometers).round());

const double actionRadiusKm = 2.0;

bool withinActionRadius(double kilometers) => kilometers <= actionRadiusKm;

String generateConfirmationCode([math.Random? random]) {
  final value = (random ?? math.Random.secure()).nextInt(10000);
  return value.toString().padLeft(4, '0');
}
