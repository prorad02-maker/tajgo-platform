import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../models/place_suggestion.dart';
import 'address_normalizer.dart';
import 'geocoding_provider.dart';
import 'recent_places_service.dart';
import 'reverse_geocoding_service.dart';
import 'saved_places_service.dart';
import 'map_performance_monitor.dart';

class PlaceSearchService {
  PlaceSearchService({
    GeocodingProvider? remoteProvider,
    RecentPlacesService? recentPlaces,
    AddressNormalizer? normalizer,
    ReverseGeocodingService? reverseGeocoding,
    SavedPlacesService? savedPlaces,
    MapPerformanceMonitor? performanceMonitor,
  }) : _remoteProvider = remoteProvider ?? const NativeGeocodingProvider(),
       recentPlaces = recentPlaces ?? RecentPlacesService(),
       _normalizer = normalizer ?? const AddressNormalizer(),
       _reverseGeocoding = reverseGeocoding ?? const ReverseGeocodingService(),
       savedPlaces = savedPlaces ?? SavedPlacesService(),
       performance = performanceMonitor ?? MapPerformanceMonitor.shared;

  final GeocodingProvider _remoteProvider;
  final RecentPlacesService recentPlaces;
  final AddressNormalizer _normalizer;
  final ReverseGeocodingService _reverseGeocoding;
  final SavedPlacesService savedPlaces;
  final MapPerformanceMonitor performance;
  List<PlaceSuggestion>? _localCache;

  Future<List<PlaceSuggestion>> search(
    String input, {
    LatLng? near,
    String? recentType,
  }) async {
    final stopwatch = Stopwatch()..start();
    final query = _normalizer.normalizeQuery(input);
    final local = await _loadLocal();
    final recent = await recentPlaces.load(type: recentType);
    final favorites = await savedPlaces.load();
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

    addMatches(favorites, 'favorite');
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
    stopwatch.stop();
    performance.recordSearch(stopwatch.elapsed);
    return result.take(16).toList();
  }

  Future<PlaceSuggestion> reverse(LatLng point) async {
    final stopwatch = Stopwatch()..start();
    final result = await _reverseGeocoding.resolve(point);
    stopwatch.stop();
    performance.recordReverseGeocode(stopwatch.elapsed);
    return result;
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
    'favorite' => 0,
    'recent' => 1,
    'local' => 2,
    'remote' => 3,
    _ => 4,
  };
}
