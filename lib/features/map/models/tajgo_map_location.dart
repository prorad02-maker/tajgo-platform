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
