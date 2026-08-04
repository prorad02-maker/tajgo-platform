import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

enum TaxiObservationSource {
  manual,
  api,
  observation,
  importFile,
  existingDatabase,
}

class TaxiPriceObservation {
  const TaxiPriceObservation({
    required this.cityId,
    required this.provider,
    required this.pickupBucket,
    required this.dropoffBucket,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.quotedPrice,
    required this.observedAt,
    required this.dayOfWeek,
    required this.localHour,
    required this.sourceType,
    this.currency = 'TJS',
    this.quality = 1,
  });

  final String cityId;
  final String provider;
  final String pickupBucket;
  final String dropoffBucket;
  final int distanceMeters;
  final int durationSeconds;
  final double quotedPrice;
  final String currency;
  final DateTime observedAt;
  final int dayOfWeek;
  final int localHour;
  final TaxiObservationSource sourceType;
  final double quality;
}

abstract interface class TaxiReferenceProvider {
  Future<TaxiReferenceSelection?> referenceFor({
    required String cityId,
    required int distanceMeters,
    required int durationSeconds,
    required DateTime at,
    String? pickupBucket,
    String? dropoffBucket,
  });
}

abstract interface class TaxiObservationRepository {
  Future<List<TaxiPriceObservation>> observationsForCity(String cityId);
}

class FirestoreTaxiObservationRepository implements TaxiObservationRepository {
  const FirestoreTaxiObservationRepository(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<List<TaxiPriceObservation>> observationsForCity(String cityId) async {
    final snapshot = await firestore
        .collection('taxi_price_observations')
        .where('cityId', isEqualTo: cityId)
        .limit(100)
        .get();
    return snapshot.docs
        .map((doc) => _fromMap(doc.data()))
        .whereType<TaxiPriceObservation>()
        .toList();
  }

  TaxiPriceObservation? _fromMap(Map<String, dynamic> data) {
    final observedAt = data['observedAt'];
    if (observedAt is! Timestamp) return null;
    final distance = data['distanceMeters'];
    final duration = data['durationSeconds'];
    final price = data['quotedPrice'];
    if (distance is! num || duration is! num || price is! num) return null;
    final sourceName = data['sourceType'] as String? ?? 'observation';
    final source = TaxiObservationSource.values.firstWhere(
      (value) => value.name == sourceName,
      orElse: () => TaxiObservationSource.observation,
    );
    return TaxiPriceObservation(
      cityId: data['cityId'] as String? ?? '',
      provider: data['provider'] as String? ?? 'unknown',
      pickupBucket: data['pickupBucket'] as String? ?? '',
      dropoffBucket: data['dropoffBucket'] as String? ?? '',
      distanceMeters: distance.toInt(),
      durationSeconds: duration.toInt(),
      quotedPrice: price.toDouble(),
      currency: data['currency'] as String? ?? 'TJS',
      observedAt: observedAt.toDate(),
      dayOfWeek:
          (data['dayOfWeek'] as num?)?.toInt() ?? observedAt.toDate().weekday,
      localHour:
          (data['localHour'] as num?)?.toInt() ?? observedAt.toDate().hour,
      sourceType: source,
      quality: (data['quality'] as num?)?.toDouble() ?? 1,
    );
  }
}

class TaxiReferenceSelection {
  const TaxiReferenceSelection({
    required this.priceTjs,
    required this.sampleCount,
    required this.confidence,
    required this.source,
  });

  final double priceTjs;
  final int sampleCount;
  final double confidence;
  final String source;
}

class ExistingDatabaseTaxiPriceProvider implements TaxiReferenceProvider {
  const ExistingDatabaseTaxiPriceProvider(
    this.repository, {
    this.minimumSamples = 3,
  });

  final TaxiObservationRepository repository;
  final int minimumSamples;

  @override
  Future<TaxiReferenceSelection?> referenceFor({
    required String cityId,
    required int distanceMeters,
    required int durationSeconds,
    required DateTime at,
    String? pickupBucket,
    String? dropoffBucket,
  }) async {
    final source = await repository.observationsForCity(cityId);
    final candidates = source.where((item) {
      if (item.cityId != cityId ||
          item.currency != 'TJS' ||
          item.quotedPrice <= 0) {
        return false;
      }
      final distanceRatio = item.distanceMeters / math.max(distanceMeters, 1);
      final durationRatio = item.durationSeconds / math.max(durationSeconds, 1);
      return distanceRatio >= .55 &&
          distanceRatio <= 1.8 &&
          durationRatio >= .4 &&
          durationRatio <= 2.2;
    }).toList();
    if (candidates.length < minimumSamples) return null;

    final unitPrices =
        candidates
            .map((item) => item.quotedPrice / math.max(item.distanceMeters, 1))
            .toList()
          ..sort();
    final unitMedian = unitPrices[unitPrices.length ~/ 2];
    final filtered = candidates.where((item) {
      final unit = item.quotedPrice / math.max(item.distanceMeters, 1);
      return unit >= unitMedian * .45 && unit <= unitMedian * 2.2;
    }).toList();
    if (filtered.length < minimumSamples) return null;

    var weighted = 0.0;
    var totalWeight = 0.0;
    for (final item in filtered) {
      final ageDays = at.difference(item.observedAt).inHours.abs() / 24;
      final recency = 1 / (1 + ageDays / 14);
      final hourDistance = (item.localHour - at.hour).abs();
      final hourWeight =
          1 / (1 + math.min(hourDistance, 24 - hourDistance) / 4);
      final dayWeight = item.dayOfWeek == at.weekday ? 1.2 : 1.0;
      final zoneWeight =
          pickupBucket != null &&
              dropoffBucket != null &&
              item.pickupBucket == pickupBucket &&
              item.dropoffBucket == dropoffBucket
          ? 1.5
          : 1.0;
      final weight =
          recency *
          hourWeight *
          dayWeight *
          zoneWeight *
          item.quality.clamp(.1, 1);
      weighted += item.quotedPrice * weight;
      totalWeight += weight;
    }
    final confidence =
        (filtered.length / 8).clamp(.25, 1.0) *
        (totalWeight / filtered.length).clamp(.25, 1.0);
    return TaxiReferenceSelection(
      priceTjs: weighted / totalWeight,
      sampleCount: filtered.length,
      confidence: confidence,
      source: 'existing_database_observations',
    );
  }
}
