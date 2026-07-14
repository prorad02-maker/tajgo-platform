import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/tajgo_route.dart';
import 'direct_route_provider.dart';
import 'map_performance_monitor.dart';
import 'road_route_provider.dart';
import 'route_cache.dart';
import 'route_sanity_service.dart';
import 'routing_health_monitor.dart';

class RouteService {
  RouteService({
    RoadRouteProvider? roadProvider,
    DirectRouteProvider? directProvider,
    RouteCache? cache,
    RouteSanityService? sanityService,
    RoutingHealthMonitor? healthMonitor,
    MapPerformanceMonitor? performanceMonitor,
  }) : _road = roadProvider ?? RoadRouteProvider(),
       _direct = directProvider ?? const DirectRouteProvider(),
       _cache = cache ?? RouteCache(),
       _sanity =
           sanityService ??
           RouteSanityService(
             directProvider: directProvider ?? const DirectRouteProvider(),
           ),
       performance = performanceMonitor ?? MapPerformanceMonitor.shared,
       health =
           healthMonitor ??
           RoutingHealthMonitor((roadProvider ?? RoadRouteProvider()).config);

  final RoadRouteProvider _road;
  final DirectRouteProvider _direct;
  final RouteCache _cache;
  final RouteSanityService _sanity;
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
        final checked = _sanity.sanitize(
          candidate: cached,
          from: from,
          to: to,
          mode: mode,
        );
        if (checked.usedFallback) {
          _cache.put(from, to, mode, checked.route);
        }
        health.recordCacheHit(checked.route);
        _debugRoute(
          from: from,
          to: to,
          result: checked,
          providerName: cached.providerName,
          routeSource: 'cache',
          cache: 'hit',
        );
        return Future.value(checked.route);
      }
    }

    final key = _cache.key(from, to, mode);
    final running = _inFlight[key];
    if (running != null && !forceRefresh) return running;
    final request = _build(from: from, to: to, mode: mode);
    _inFlight[key] = request;
    request.whenComplete(() => _inFlight.remove(key));
    return request;
  }

  Future<TajGoRoute> _build({
    required LatLng from,
    required LatLng to,
    required RouteMode mode,
  }) async {
    final stopwatch = Stopwatch()..start();
    late RouteSanityResult checked;
    var routeSource = 'direct';

    if (_road.configured) {
      try {
        final candidate = await _road.buildRoute(
          from: from,
          to: to,
          mode: mode,
        );
        checked = _sanity.sanitize(
          candidate: candidate,
          from: from,
          to: to,
          mode: mode,
        );
        routeSource = checked.usedFallback ? 'sanity_fallback' : 'road';
        if (checked.usedFallback) {
          health.recordFallback(
            checked.reason ?? 'route sanity check failed',
            stopwatch.elapsed,
            requestUrl: _road.lastRequestUrl,
            httpStatus: _road.lastHttpStatus,
            parseSuccess: _road.lastParseSuccess,
            route: checked.route,
          );
        } else {
          health.recordSuccess(
            checked.route,
            stopwatch.elapsed,
            requestUrl: _road.lastRequestUrl,
            httpStatus: _road.lastHttpStatus,
            parseSuccess: _road.lastParseSuccess,
          );
        }
      } catch (error) {
        checked = _sanity.sanitize(
          candidate: null,
          from: from,
          to: to,
          mode: mode,
          missingReason: error.toString(),
        );
        routeSource = 'provider_error_fallback';
        health.recordFallback(
          error.toString(),
          stopwatch.elapsed,
          requestUrl: _road.lastRequestUrl,
          httpStatus: _road.lastHttpStatus,
          parseSuccess: _road.lastParseSuccess,
          route: checked.route,
        );
      }
    } else {
      checked = _sanity.sanitize(
        candidate: null,
        from: from,
        to: to,
        mode: mode,
        missingReason: 'Road route endpoint is disabled.',
      );
      health.recordDisabledFallback(checked.route);
    }

    stopwatch.stop();
    performance.recordRoute(stopwatch.elapsed);
    _cache.put(from, to, mode, checked.route);
    _debugRoute(
      from: from,
      to: to,
      result: checked,
      providerName: _road.configured ? _road.name : 'disabled',
      routeSource: routeSource,
      cache: 'miss',
    );
    return checked.route;
  }

  void _debugRoute({
    required LatLng from,
    required LatLng to,
    required RouteSanityResult result,
    required String providerName,
    required String routeSource,
    required String cache,
  }) {
    if (!kDebugMode) return;
    final route = result.route;
    debugPrint(
      '[TajGoRoute] from=${from.latitude},${from.longitude} '
      'to=${to.latitude},${to.longitude} '
      'directDistanceMeters=${result.directDistanceMeters.toStringAsFixed(1)} '
      'providerDistanceMeters=${result.providerDistanceMeters?.toStringAsFixed(1)} '
      'selectedDistanceMeters=${(route.distanceKm * 1000).toStringAsFixed(1)} '
      'quality=${route.routeQuality.name} providerName=$providerName '
      'selectedProvider=${route.providerName} '
      'points=${route.points.length} source=$routeSource cache=$cache '
      'fallbackReason=${result.reason ?? '-'}',
    );
  }
}
