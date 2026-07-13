import 'package:latlong2/latlong.dart';

import '../models/tajgo_route.dart';

class RouteCache {
  RouteCache({
    this.roadTtl = const Duration(minutes: 8),
    this.fallbackTtl = const Duration(seconds: 45),
  });

  final Duration roadTtl;
  final Duration fallbackTtl;
  final Map<String, TajGoRoute> _entries = {};

  String key(LatLng from, LatLng to, RouteMode mode) =>
      '${from.latitude.toStringAsFixed(4)},${from.longitude.toStringAsFixed(4)}:'
      '${to.latitude.toStringAsFixed(4)},${to.longitude.toStringAsFixed(4)}:'
      '${mode.name}';

  TajGoRoute? get(LatLng from, LatLng to, RouteMode mode) {
    prune();
    final value = _entries[key(from, to, mode)];
    if (value == null) return null;
    final ttl = value.isFallback ? fallbackTtl : roadTtl;
    if (DateTime.now().toUtc().difference(value.createdAt) > ttl) {
      _entries.remove(key(from, to, mode));
      return null;
    }
    return value;
  }

  void put(LatLng from, LatLng to, RouteMode mode, TajGoRoute route) {
    _entries[key(from, to, mode)] = route;
    prune();
  }

  void prune() {
    final now = DateTime.now().toUtc();
    _entries.removeWhere((_, route) {
      final ttl = route.isFallback ? fallbackTtl : roadTtl;
      return now.difference(route.createdAt) > ttl;
    });
  }

  void clear() => _entries.clear();
}
