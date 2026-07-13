import 'package:latlong2/latlong.dart';

import '../models/tajgo_route.dart';
import 'direct_route_provider.dart';
import 'road_route_provider.dart';
import 'route_cache.dart';
import 'map_performance_monitor.dart';
import 'routing_health_monitor.dart';

class RouteService {
  RouteService({
    RoadRouteProvider? roadProvider,
    DirectRouteProvider? directProvider,
    RouteCache? cache,
    RoutingHealthMonitor? healthMonitor,
    MapPerformanceMonitor? performanceMonitor,
  }) : _road = roadProvider ?? RoadRouteProvider(),
       _direct = directProvider ?? const DirectRouteProvider(),
       _cache = cache ?? RouteCache(),
       performance = performanceMonitor ?? MapPerformanceMonitor.shared,
       health =
           healthMonitor ??
           RoutingHealthMonitor((roadProvider ?? RoadRouteProvider()).config);

  final RoadRouteProvider _road;
  final DirectRouteProvider _direct;
  final RouteCache _cache;
  final RoutingHealthMonitor health;
  final MapPerformanceMonitor performance;
  final Map<String, Future<TajGoRoute>> _inFlight = {};

  TajGoRoute directRoute({
    required LatLng from,
    required LatLng to,
    RouteMode mode = RouteMode.bicycle,
  }) => _direct.buildSync(from: from, to: to, mode: mode);

  Future<TajGoRoute> roadRoute({
    required LatLng from,
    required LatLng to,
    RouteMode mode = RouteMode.bicycle,
  }) => buildRoute(from: from, to: to, mode: mode);

  Future<TajGoRoute> buildRoute({
    required LatLng from,
    required LatLng to,
    required RouteMode mode,
    bool forceRefresh = false,
  }) {
    if (!forceRefresh) {
      final cached = _cache.get(from, to, mode);
      if (cached != null) {
        health.recordCacheHit(cached);
        return Future.value(cached);
      }
    }
    final key = _cache.key(from, to, mode);
    final running = _inFlight[key];
    if (running != null && !forceRefresh) return running;
    final request = _build(from: from, to: to, mode: mode);
    _inFlight[key] = request;
    request.then(
      (_) {
        _inFlight.remove(key);
      },
      onError: (_) {
        _inFlight.remove(key);
      },
    );
    return request;
  }

  Future<TajGoRoute> _build({
    required LatLng from,
    required LatLng to,
    required RouteMode mode,
  }) async {
    final stopwatch = Stopwatch()..start();
    TajGoRoute route;
    if (_road.configured) {
      try {
        route = await _road.buildRoute(from: from, to: to, mode: mode);
        health.recordSuccess(route, stopwatch.elapsed);
      } catch (error) {
        route = _direct.buildSync(
          from: from,
          to: to,
          mode: mode,
          errorMessage: error.toString(),
          quality: RouteQuality.providerError,
        );
        health.recordFallback(error.toString(), stopwatch.elapsed);
      }
    } else {
      route = _direct.buildSync(
        from: from,
        to: to,
        mode: mode,
        errorMessage: 'Road route endpoint is disabled.',
      );
      health.recordDisabledFallback();
    }
    stopwatch.stop();
    performance.recordRoute(stopwatch.elapsed);
    _cache.put(from, to, mode, route);
    return route;
  }
}
