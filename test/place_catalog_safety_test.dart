import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajgo/features/map/models/place_suggestion.dart';
import 'package:tajgo/features/map/services/geocoding_provider.dart';
import 'package:tajgo/features/map/services/place_search_service.dart';
import 'package:tajgo/features/map/services/recent_places_service.dart';
import 'package:tajgo/features/map/services/saved_places_service.dart';

class _Geocoder extends Fake implements GeocodingProvider {
  List<PlaceSuggestion> results = [];
  @override
  Future<List<PlaceSuggestion>> search(String query, LatLng? near) async =>
      results;
}

class _Preferences extends Fake implements SharedPreferencesAsync {
  _Preferences(this.stored);
  final String? stored;
  @override
  Future<String?> getString(String key) async => stored;
}

PlaceSuggestion _place(String id, {double lat = 40.28, double lng = 69.62}) =>
    PlaceSuggestion(
      id: id,
      title: 'Адрес',
      subtitle: 'Худжанд',
      shortTitle: 'Адрес',
      address: 'Худжанд, улица Рудаки, 54',
      lat: lat,
      lng: lng,
      source: 'manual',
      confidence: 1,
      category: 'address',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled demo points are absent from ordinary address search', () async {
    final service = PlaceSearchService(loadLocalStores: false);
    expect(await service.search(''), isEmpty);
  });

  test('bundled demo points require explicit preview selection', () async {
    final service = PlaceSearchService(
      loadLocalStores: false,
      allowPreviewPlaces: true,
    );
    final results = await service.search('');
    expect(results, hasLength(4));
    expect(results.every((place) => place.isPreview), isTrue);
  });

  test(
    'old demo favorites and recents stay hidden; real addresses survive',
    () async {
      final preferences = _Preferences(
        jsonEncode([
          _place('demo_center').toJson(),
          _place('real-home').toJson(),
        ]),
      );
      final service = PlaceSearchService(
        recentPlaces: RecentPlacesService(preferences: preferences),
        savedPlaces: SavedPlacesService(preferences: preferences),
      );
      expect((await service.search('')).map((place) => place.id), [
        'real-home',
      ]);
    },
  );

  test(
    'invalid remote coordinates and demo records cannot be selected',
    () async {
      final geocoder = _Geocoder()
        ..results = [
          _place('nan', lat: double.nan),
          _place('infinite', lng: double.infinity),
          _place('out-of-range', lat: 91),
          _place('zero', lat: 0, lng: 0),
          _place('demo_partner_pickup'),
          _place('valid'),
        ];
      final service = PlaceSearchService(
        remoteProvider: geocoder,
        loadLocalStores: false,
      );
      expect((await service.search('адрес')).map((place) => place.id), [
        'valid',
      ]);
    },
  );
}
