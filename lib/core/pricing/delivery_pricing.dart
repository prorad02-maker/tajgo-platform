import 'dart:math' as math;

class DeliveryPricingProfile {
  const DeliveryPricingProfile({
    required this.id,
    required this.cityId,
    required this.taxiReferenceMultiplier,
    required this.minimumDeliveryPrice,
    required this.minimumCourierPayout,
    required this.platformMinimumMargin,
    required this.fallbackBasePrice,
    required this.fallbackPerKm,
    required this.fallbackPerMinute,
    this.surgeFactor = 1,
  });

  final String id;
  final String cityId;
  final double taxiReferenceMultiplier;
  final double minimumDeliveryPrice;
  final double minimumCourierPayout;
  final double platformMinimumMargin;
  final double fallbackBasePrice;
  final double fallbackPerKm;
  final double fallbackPerMinute;
  final double surgeFactor;

  double get economicFloor => minimumCourierPayout + platformMinimumMargin;
}

class DeliveryPricingProfiles {
  const DeliveryPricingProfiles._();

  // Existing TajGo pilot baseline (7 + 3/km, min 10) is preserved as the
  // low-confidence fallback until enough city observations exist.
  static const khujand = DeliveryPricingProfile(
    id: 'delivery_khujand_v3',
    cityId: 'khujand',
    taxiReferenceMultiplier: 0.50,
    minimumDeliveryPrice: 10,
    minimumCourierPayout: 7,
    platformMinimumMargin: 3,
    fallbackBasePrice: 7,
    fallbackPerKm: 3,
    fallbackPerMinute: 0,
  );

  static const dushanbe = DeliveryPricingProfile(
    id: 'delivery_dushanbe_v3',
    cityId: 'dushanbe',
    taxiReferenceMultiplier: 0.50,
    minimumDeliveryPrice: 10,
    minimumCourierPayout: 7,
    platformMinimumMargin: 3,
    fallbackBasePrice: 7,
    fallbackPerKm: 3,
    fallbackPerMinute: 0,
  );

  static DeliveryPricingProfile forCity(String cityId) => switch (cityId) {
    'dushanbe' => dushanbe,
    _ => khujand,
  };
}

enum QuoteConfidence { low, medium, high }

class TaxiReference {
  const TaxiReference({
    required this.priceTjs,
    required this.source,
    required this.confidence,
    required this.sampleCount,
  });

  final double priceTjs;
  final String source;
  final QuoteConfidence confidence;
  final int sampleCount;
}

class DeliveryQuote {
  const DeliveryQuote({
    required this.priceTjs,
    required this.currency,
    required this.isPreview,
    required this.confidence,
    required this.source,
  });

  final int priceTjs;
  final String currency;
  final bool isPreview;
  final QuoteConfidence confidence;
  final String source;
}

class DeliveryQuoteEngine {
  const DeliveryQuoteEngine();

  DeliveryQuote quote({
    required DeliveryPricingProfile profile,
    required double distanceKm,
    required double durationMinutes,
    TaxiReference? taxiReference,
    bool preview = true,
  }) {
    if (!distanceKm.isFinite || distanceKm < 0) {
      throw ArgumentError.value(distanceKm, 'distanceKm');
    }
    if (!durationMinutes.isFinite || durationMinutes < 0) {
      throw ArgumentError.value(durationMinutes, 'durationMinutes');
    }
    final profileValues = [
      profile.minimumDeliveryPrice,
      profile.minimumCourierPayout,
      profile.platformMinimumMargin,
      profile.fallbackBasePrice,
      profile.fallbackPerKm,
      profile.fallbackPerMinute,
    ];
    if (profileValues.any((value) => !value.isFinite || value < 0) ||
        !profile.taxiReferenceMultiplier.isFinite ||
        profile.taxiReferenceMultiplier <= 0 ||
        profile.taxiReferenceMultiplier > 1 ||
        !profile.surgeFactor.isFinite ||
        profile.surgeFactor < .5 ||
        profile.surgeFactor > 3 ||
        (taxiReference != null &&
            (!taxiReference.priceTjs.isFinite ||
                taxiReference.priceTjs <= 0))) {
      throw ArgumentError('Invalid pricing inputs.');
    }
    final fallback =
        profile.fallbackBasePrice +
        profile.fallbackPerKm * distanceKm +
        profile.fallbackPerMinute * durationMinutes;
    final marketTarget = taxiReference == null
        ? fallback
        : taxiReference.priceTjs * profile.taxiReferenceMultiplier;
    final price = math.max(
      math.max(marketTarget, profile.minimumDeliveryPrice),
      profile.economicFloor,
    );
    return DeliveryQuote(
      priceTjs: (price * profile.surgeFactor).ceil(),
      currency: 'TJS',
      isPreview: preview,
      confidence: taxiReference?.confidence ?? QuoteConfidence.low,
      source: taxiReference?.source ?? 'city_fallback',
    );
  }
}
