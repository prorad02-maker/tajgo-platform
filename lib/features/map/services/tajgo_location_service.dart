import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/tajgo_map_location.dart';

class TajGoLocationException implements Exception {
  const TajGoLocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TajGoLocationService {
  Future<Position> determineCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const TajGoLocationException(
        'Включите геолокацию на телефоне и попробуйте ещё раз.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const TajGoLocationException(
        'Без разрешения на геолокацию мы не сможем показать ваше местоположение.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const TajGoLocationException(
        'Разрешение запрещено навсегда. Откройте настройки приложения и разрешите геолокацию.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<TajGoMapLocation> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final places = await Geocoding()
          .placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 5));
      if (places.isEmpty) {
        return _fallback(latitude, longitude);
      }
      final place = places.first;
      final parts = [
        place.street,
        place.subLocality,
        place.locality,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();
      if (parts.isEmpty) {
        return _fallback(latitude, longitude);
      }
      return TajGoMapLocation(
        latitude: latitude,
        longitude: longitude,
        address: parts.join(', '),
      );
    } catch (_) {
      return _fallback(latitude, longitude);
    }
  }

  Stream<Position> positionStream() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    ),
  );

  TajGoMapLocation _fallback(double latitude, double longitude) {
    return TajGoMapLocation(
      latitude: latitude,
      longitude: longitude,
      address: _label(latitude, longitude),
    );
  }

  String _label(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }
}
