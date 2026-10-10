import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class TajGoMapLocation {
  const TajGoMapLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
  final double latitude, longitude;
  final String address;

  bool get isValid =>
      address.trim().isNotEmpty &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  void validate() {
    if (!isValid) {
      throw ArgumentError('Укажите адрес и корректную точку на карте.');
    }
  }

  GeoPoint toGeoPoint() => GeoPoint(latitude, longitude);
  LatLng toLatLng() => LatLng(latitude, longitude);
  factory TajGoMapLocation.fromGeoPoint(
    GeoPoint point, {
    String address = '',
  }) => TajGoMapLocation(
    latitude: point.latitude,
    longitude: point.longitude,
    address: address,
  );
  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
  };
}
