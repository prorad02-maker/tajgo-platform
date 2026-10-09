import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

import '../models/place_suggestion.dart';

abstract class GeocodingProvider {
  Future<List<PlaceSuggestion>> search(String query, LatLng? near);
  Future<PlaceSuggestion?> reverse(LatLng point);
}

class NativeGeocodingProvider implements GeocodingProvider {
  const NativeGeocodingProvider();

  @override
  Future<List<PlaceSuggestion>> search(String query, LatLng? near) async {
    if (query.trim().length < 2) return const [];
    try {
      final locations = await Geocoding()
          .locationFromAddress('$query, Худжанд, Таджикистан')
          .timeout(const Duration(seconds: 5));
      return await Future.wait(
        locations.take(5).indexed.map((entry) async {
          final location = entry.$2;
          final resolved = await reverse(
            LatLng(location.latitude, location.longitude),
          );
          return PlaceSuggestion(
            id: 'remote_${location.latitude}_${location.longitude}_${entry.$1}',
            title: resolved?.title ?? query.trim(),
            subtitle: resolved?.address ?? 'Уточните точку на карте',
            shortTitle: resolved?.shortTitle ?? query.trim(),
            address: resolved?.address ?? '$query, Худжанд',
            lat: location.latitude,
            lng: location.longitude,
            source: 'remote',
            confidence: entry.$1 == 0 ? 0.72 : 0.58,
            category: 'address',
          );
        }),
      );
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<PlaceSuggestion?> reverse(LatLng point) async {
    try {
      final places = await Geocoding()
          .placemarkFromCoordinates(point.latitude, point.longitude)
          .timeout(const Duration(seconds: 5));
      if (places.isEmpty) return null;
      final place = places.first;
      final address = formatPlacemarkAddress(place);
      if (address.isEmpty) return null;
      return PlaceSuggestion(
        id: 'manual_${point.latitude}_${point.longitude}',
        title: address.split(',').first,
        subtitle: address,
        shortTitle: address.split(',').first,
        address: address,
        lat: point.latitude,
        lng: point.longitude,
        source: 'manual',
        confidence: 0.65,
        category: 'mapPoint',
      );
    } catch (_) {
      return null;
    }
  }
}

String formatPlacemarkAddress(Placemark place) {
  final street = (place.street ?? '').trim();
  final road = (place.thoroughfare ?? '').trim();
  final house = (place.subThoroughfare ?? '').trim();
  final first = road.isNotEmpty
      ? [road, if (house.isNotEmpty) house].join(', ')
      : street;
  final seen = <String>{};
  return [first, place.subLocality, place.locality]
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty && seen.add(part.toLowerCase()))
      .join(', ');
}
