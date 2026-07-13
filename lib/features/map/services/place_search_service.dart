import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../models/place_suggestion.dart';
import 'address_normalizer.dart';
import 'geocoding_provider.dart';
import 'recent_places_service.dart';
import 'reverse_geocoding_service.dart';

class PlaceSearchService {
  PlaceSearchService({
    GeocodingProvider? remoteProvider,
    RecentPlacesService? recentPlaces,
    AddressNormalizer? normalizer,
    ReverseGeocodingService? reverseGeocoding,
  }) : _remoteProvider = remoteProvider ?? const NativeGeocodingProvider(),
       recentPlaces = recentPlaces ?? RecentPlacesService(),
       _normalizer = normalizer ?? const AddressNormalizer(),
       _reverseGeocoding = reverseGeocoding ?? const ReverseGeocodingService();

  final GeocodingProvider _remoteProvider;
  final RecentPlacesService recentPlaces;
  final AddressNormalizer _normalizer;
  final ReverseGeocodingService _reverseGeocoding;
  List<PlaceSuggestion>? _localCache;

  Future<List<PlaceSuggestion>> search(
    String input, {
    LatLng? near,
    String? recentType,
  }) async {
    final query = _normalizer.normalizeQuery(input);
    final local = await _loadLocal();
    final recent = await recentPlaces.load(type: recentType);
    final output = <PlaceSuggestion>[];

    void addMatches(List<PlaceSuggestion> places, String source) {
      for (final place in places) {
        final score = query.isEmpty
            ? 0.5
            : _normalizer.scoreMatch(query, place);
        if (query.isNotEmpty && score < 0.35) continue;
        output.add(
          _withDistance(
            place.copyWith(source: source, confidence: score),
            near,
          ),
        );
      }
    }

    addMatches(recent, 'recent');
    addMatches(local, 'local');

    if (query.length >= 2) {
      final remote = await _remoteProvider.search(input.trim(), near);
      for (final place in remote) {
        output.add(_withDistance(place, near));
      }
    }

    final unique = <String, PlaceSuggestion>{};
    for (final place in output) {
      final key =
          '${place.lat.toStringAsFixed(5)}:${place.lng.toStringAsFixed(5)}';
      unique.putIfAbsent(key, () => place);
    }
    final result = unique.values.toList()
      ..sort((a, b) {
        final sourceOrder = _sourcePriority(
          a.source,
        ).compareTo(_sourcePriority(b.source));
        if (sourceOrder != 0) return sourceOrder;
        final confidenceOrder = b.confidence.compareTo(a.confidence);
        if (confidenceOrder != 0) return confidenceOrder;
        final popularityOrder = b.popularity.compareTo(a.popularity);
        if (popularityOrder != 0) return popularityOrder;
        return (a.distanceMetersFromUser ?? double.infinity).compareTo(
          b.distanceMetersFromUser ?? double.infinity,
        );
      });
    return result.take(12).toList();
  }

  Future<PlaceSuggestion> reverse(LatLng point) async {
    return _reverseGeocoding.resolve(point);
  }

  Future<List<PlaceSuggestion>> _loadLocal() async {
    final cached = _localCache;
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString(
        'assets/data/khujand_places.json',
      );
      final decoded = jsonDecode(raw) as List<dynamic>;
      final places = decoded
          .whereType<Map<String, dynamic>>()
          .map((item) => PlaceSuggestion.fromJson(item, source: 'local'))
          .where((place) => place.lat != 0 || place.lng != 0)
          .toList();
      _localCache = places;
      return places;
    } catch (_) {
      return const [];
    }
  }

  PlaceSuggestion _withDistance(PlaceSuggestion place, LatLng? near) {
    if (near == null) return place;
    const distance = Distance();
    return place.copyWith(
      distanceMetersFromUser: distance.as(LengthUnit.Meter, near, place.point),
    );
  }

  int _sourcePriority(String source) => switch (source) {
    'recent' => 0,
    'local' => 1,
    'remote' => 2,
    _ => 3,
  };
}
