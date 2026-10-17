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
        .orderBy('observedAt', descending: true)
        .limit(200)
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
    final local = _tajikLocalParts(observedAt.toDate());
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
      dayOfWeek: local.$1,
      localHour: local.$2,
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
    if (distanceMeters < 0 ||
        distanceMeters > 100000 ||
        durationSeconds < 0 ||
        durationSeconds > 86400 ||
        minimumSamples < 3) {
      throw ArgumentError('Invalid taxi reference request.');
    }
    final source = await repository.observationsForCity(cityId);
    final seen = <String>{};
    final providerCounts = <String, int>{};
    final candidates = source.where((item) {
      final age = at.toUtc().difference(item.observedAt.toUtc());
      if (item.cityId != cityId ||
          item.currency != 'TJS' ||
          !item.quotedPrice.isFinite ||
          item.quotedPrice <= 0 ||
          item.quotedPrice > 10000 ||
          item.distanceMeters <= 0 ||
          item.distanceMeters > 100000 ||
          item.durationSeconds <= 0 ||
          item.durationSeconds > 86400 ||
          !item.quality.isFinite ||
          item.quality < .1 ||
          item.quality > 1 ||
          age < const Duration(minutes: -5) ||
          age > const Duration(days: 45) ||
          item.dayOfWeek < 1 ||
          item.dayOfWeek > 7 ||
          item.localHour < 0 ||
          item.localHour > 23) {
        return false;
      }
      final provider = item.provider.trim().toLowerCase();
      final key =
          '$cityId|$provider|${item.pickupBucket}|${item.dropoffBucket}|'
          '${(item.distanceMeters / 50).round()}|${(item.durationSeconds / 30).round()}|'
          '${item.quotedPrice.toStringAsFixed(2)}|${item.observedAt.millisecondsSinceEpoch ~/ 300000}';
      if (!seen.add(key) || (providerCounts[provider] ?? 0) >= 10) return false;
      final distanceRatio = item.distanceMeters / math.max(distanceMeters, 1);
      final durationRatio = item.durationSeconds / math.max(durationSeconds, 1);
      final matches =
          distanceRatio >= .55 &&
          distanceRatio <= 1.8 &&
          durationRatio >= .4 &&
          durationRatio <= 2.2;
      if (matches) {
        providerCounts[provider] = (providerCounts[provider] ?? 0) + 1;
      }
      return matches;
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
      return unit >= unitMedian * .5 && unit <= unitMedian * 2;
    }).toList();
    if (filtered.length < minimumSamples) return null;

    var weighted = 0.0;
    var totalWeight = 0.0;
    for (final item in filtered) {
      final ageDays =
          math.max(0, at.difference(item.observedAt).inMinutes) / 1440;
      final recency = 1 / (1 + ageDays / 14);
      final local = _tajikLocalParts(at);
      final hourDistance = (item.localHour - local.$2).abs();
      final hourWeight =
          1 / (1 + math.min(hourDistance, 24 - hourDistance) / 4);
      final dayWeight = item.dayOfWeek == local.$1 ? 1.2 : 1.0;
      final weight = recency * hourWeight * dayWeight * item.quality;
      weighted += item.quotedPrice * weight;
      totalWeight += weight;
    }
    final confidence =
        ((filtered.length / 8).clamp(0, 1.0) *
                (totalWeight / filtered.length).clamp(0, 1.0))
            .toDouble();
    return TaxiReferenceSelection(
      priceTjs: weighted / totalWeight,
      sampleCount: filtered.length,
      confidence: confidence,
      source: 'existing_database_observations',
    );
  }
}

(int, int) _tajikLocalParts(DateTime at) {
  final local = at.toUtc().add(const Duration(hours: 5));
  return (local.weekday, local.hour);
}
