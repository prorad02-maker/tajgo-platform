import 'package:latlong2/latlong.dart';

import '../models/place_suggestion.dart';
import 'geocoding_provider.dart';

class ReverseGeocodingService {
  const ReverseGeocodingService({
    this.provider = const NativeGeocodingProvider(),
  });

  final GeocodingProvider provider;

  Future<PlaceSuggestion> resolve(LatLng point) async {
    final result = await provider.reverse(point);
    return result ??
        PlaceSuggestion(
          id: 'manual_${point.latitude}_${point.longitude}',
          title: 'Точка на карте',
          subtitle:
              '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
          shortTitle: 'Точка на карте',
          address: 'Точка на карте',
          lat: point.latitude,
          lng: point.longitude,
          source: 'manual',
          confidence: 0.3,
          category: 'mapPoint',
        );
  }
}
