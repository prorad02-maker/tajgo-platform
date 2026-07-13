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
    if (query.trim().length < 3) return const [];
    try {
      final locations = await Geocoding()
          .locationFromAddress('$query, Худжанд, Таджикистан')
          .timeout(const Duration(seconds: 5));
      return locations.take(5).indexed.map((entry) {
        final location = entry.$2;
        return PlaceSuggestion(
          id: 'remote_${location.latitude}_${location.longitude}_${entry.$1}',
          title: query.trim(),
          subtitle: 'Результат геокодера · уточните точку на карте',
          shortTitle: query.trim(),
          address: '$query, Худжанд',
          lat: location.latitude,
          lng: location.longitude,
          source: 'remote',
          confidence: entry.$1 == 0 ? 0.72 : 0.58,
          category: 'address',
        );
      }).toList();
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
      final parts = [
        place.street,
        place.subLocality,
        place.locality,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();
      if (parts.isEmpty) return null;
      final address = parts.join(', ');
      return PlaceSuggestion(
        id: 'manual_${point.latitude}_${point.longitude}',
        title: parts.first,
        subtitle: address,
        shortTitle: parts.first,
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
