import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/tajgo_map_location.dart';

enum TajGoLocationIssue { serviceDisabled, denied, deniedForever }

class TajGoLocationException implements Exception {
  const TajGoLocationException(this.issue, this.message);

  final TajGoLocationIssue issue;
  final String message;

  bool get requiresSettings =>
      issue == TajGoLocationIssue.serviceDisabled ||
      issue == TajGoLocationIssue.deniedForever;

  @override
  String toString() => message;
}

class TajGoLocationService {
  StreamController<Position>? _positionController;
  StreamSubscription<Position>? _nativePositionSubscription;

  Future<Position> determineCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const TajGoLocationException(
        TajGoLocationIssue.serviceDisabled,
        'Включите геолокацию на телефоне и попробуйте ещё раз.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const TajGoLocationException(
        TajGoLocationIssue.denied,
        'Без разрешения на геолокацию мы не сможем показать ваше местоположение.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const TajGoLocationException(
        TajGoLocationIssue.deniedForever,
        'Разрешение запрещено навсегда. Откройте настройки приложения и разрешите геолокацию.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<bool> openSettingsFor(TajGoLocationIssue issue) {
    if (issue == TajGoLocationIssue.serviceDisabled) {
      return Geolocator.openLocationSettings();
    }
    return Geolocator.openAppSettings();
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

  /// One shared native GPS stream for CourierHome and CourierOrder.
  Stream<Position> positionStream() {
    final existing = _positionController;
    if (existing != null) {
      return existing.stream;
    }
    late final StreamController<Position> controller;
    controller = StreamController<Position>.broadcast(
      onListen: () => _startNativePositionStream(controller),
      onCancel: _stopNativePositionStream,
    );
    _positionController = controller;
    return controller.stream;
  }

  void _startNativePositionStream(StreamController<Position> controller) {
    if (_nativePositionSubscription != null) {
      return;
    }
    _nativePositionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(controller.add, onError: controller.addError);
  }

  Future<void> _stopNativePositionStream() async {
    final subscription = _nativePositionSubscription;
    _nativePositionSubscription = null;
    await subscription?.cancel();
  }

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
