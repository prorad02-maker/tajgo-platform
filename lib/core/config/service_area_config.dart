import 'package:latlong2/latlong.dart';

class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  bool contains(LatLng point) =>
      point.latitude >= south &&
      point.latitude <= north &&
      point.longitude >= west &&
      point.longitude <= east;
}

class ServiceAreaConfig {
  const ServiceAreaConfig({
    required this.id,
    required this.displayNameRu,
    required this.country,
    required this.center,
    required this.bounds,
    required this.defaultZoom,
    required this.pricingProfileId,
    required this.routingProfile,
    required this.enabled,
  });

  final String id;
  final String displayNameRu;
  final String country;
  final LatLng center;
  final GeoBounds bounds;
  final double defaultZoom;
  final String pricingProfileId;
  final String routingProfile;
  final bool enabled;

  bool contains(LatLng point) => enabled && bounds.contains(point);
}

class ServiceAreaRegistry {
  const ServiceAreaRegistry._();

  static const khujand = ServiceAreaConfig(
    id: 'khujand',
    displayNameRu: 'Худжанд',
    country: 'TJ',
    center: LatLng(40.2833, 69.6222),
    bounds: GeoBounds(south: 40.20, west: 69.50, north: 40.36, east: 69.76),
    defaultZoom: 13,
    pricingProfileId: 'delivery_khujand_v2',
    routingProfile: 'bicycle',
    enabled: true,
  );

  static const dushanbe = ServiceAreaConfig(
    id: 'dushanbe',
    displayNameRu: 'Душанбе',
    country: 'TJ',
    center: LatLng(38.5598, 68.7870),
    bounds: GeoBounds(south: 38.44, west: 68.68, north: 38.68, east: 68.93),
    defaultZoom: 12.8,
    pricingProfileId: 'delivery_dushanbe_v2',
    routingProfile: 'bicycle',
    enabled: true,
  );

  static const values = [khujand, dushanbe];

  static ServiceAreaConfig? byId(String? id) {
    for (final city in values) {
      if (city.id == id && city.enabled) return city;
    }
    return null;
  }

  static ServiceAreaConfig? detect(LatLng point) {
    for (final city in values) {
      if (city.contains(point)) return city;
    }
    return null;
  }

  static ServiceAreaConfig resolve({LatLng? point, String? lastCityId}) =>
      (point == null ? null : detect(point)) ?? byId(lastCityId) ?? khujand;
}
