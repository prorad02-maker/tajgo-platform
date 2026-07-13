import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/tajgo_navigation_step.dart';
import '../models/tajgo_route.dart';
import 'navigation_instruction_formatter.dart';
import 'route_provider.dart';
import 'routing_config.dart';

class RoadRouteProvider implements RouteProvider {
  RoadRouteProvider({
    RoutingConfig? config,
    http.Client? client,
    NavigationInstructionFormatter? formatter,
  }) : config = config ?? RoutingConfig.fromEnvironment(),
       _client = client ?? http.Client(),
       _formatter = formatter ?? const NavigationInstructionFormatter();

  final RoutingConfig config;
  final http.Client _client;
  final NavigationInstructionFormatter _formatter;
  Uri? _lastRequestUri;
  int? _lastHttpStatus;
  bool? _lastParseSuccess;
  String? _lastFailure;

  String? get lastRequestUrl {
    final uri = _lastRequestUri;
    if (uri == null) return null;
    final query = Map<String, String>.from(uri.queryParameters)..remove('key');
    return uri.replace(queryParameters: query).toString();
  }

  int? get lastHttpStatus => _lastHttpStatus;
  bool? get lastParseSuccess => _lastParseSuccess;
  String? get lastFailure => _lastFailure;

  bool get configured => config.isConfigured && config.validationIssues.isEmpty;

  @override
  String get name =>
      config.providerType == RoutingProviderType.osrm ? 'osrm' : 'graphhopper';

  @override
  Future<TajGoRoute> buildRoute({
    required LatLng from,
    required LatLng to,
    required RouteMode mode,
  }) async {
    if (!configured) {
      throw StateError('Road route provider is disabled.');
    }
    final effectiveMode = config.mode;
    final uri = buildRequestUri(from: from, to: to, mode: effectiveMode);
    _lastRequestUri = uri;
    _lastHttpStatus = null;
    _lastParseSuccess = null;
    _lastFailure = null;
    if (config.debugLogging) debugPrint('TajGo routing request: $name');
    try {
      final response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'TajGo-Pilot/1.0.1 (routing field test)',
            },
          )
          .timeout(config.timeout);
      _lastHttpStatus = response.statusCode;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Route provider returned ${response.statusCode}.');
      }
      final route = parseResponse(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      _lastParseSuccess = true;
      return route;
    } catch (error) {
      _lastParseSuccess = false;
      _lastFailure = error.toString();
      rethrow;
    }
  }

  TajGoRoute parseResponse(Map<String, dynamic> json) =>
      config.providerType == RoutingProviderType.osrm
      ? _parseOsrm(json)
      : _parseGraphHopper(json);

  Uri buildRequestUri({
    required LatLng from,
    required LatLng to,
    required RouteMode mode,
  }) => config.providerType == RoutingProviderType.osrm
      ? _osrmUri(from, to, mode)
      : _graphHopperUri(from, to, mode);

  Uri _osrmUri(LatLng from, LatLng to, RouteMode mode) {
    final modeProfile = switch (mode) {
      RouteMode.walking => 'foot',
      RouteMode.bicycle || RouteMode.scooter => 'bike',
      RouteMode.car => 'driving',
    };
    final profile = config.profileOverride.trim().isEmpty
        ? modeProfile
        : config.profileOverride.trim();
    final base = config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse(
      '$base/route/v1/$profile/${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
    ).replace(
      queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'true',
        'language': 'ru',
        if (config.apiKey.isNotEmpty) 'key': config.apiKey,
      },
    );
  }

  Uri _graphHopperUri(LatLng from, LatLng to, RouteMode mode) {
    final profile = switch (mode) {
      RouteMode.walking => 'foot',
      RouteMode.bicycle => 'bike',
      RouteMode.scooter => 'bike',
      RouteMode.car => 'car',
    };
    final base = Uri.parse(config.baseUrl);
    final query = <String>[
      if (base.query.isNotEmpty) base.query,
      'point=${Uri.encodeQueryComponent('${from.latitude},${from.longitude}')}',
      'point=${Uri.encodeQueryComponent('${to.latitude},${to.longitude}')}',
      'profile=${Uri.encodeQueryComponent(profile)}',
      'points_encoded=false',
      'locale=ru',
      'instructions=true',
      if (config.apiKey.isNotEmpty)
        'key=${Uri.encodeQueryComponent(config.apiKey)}',
    ].join('&');
    return base.replace(query: query);
  }

  TajGoRoute _parseOsrm(Map<String, dynamic> json) {
    final code = json['code'] as String?;
    if (code != null && code != 'Ok') {
      throw StateError('OSRM response code: $code');
    }
    final routes = json['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) throw StateError('Route not found.');
    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;
    final points = _points(coordinates);
    final steps = <TajGoNavigationStep>[];
    final legs = route['legs'] as List<dynamic>? ?? const [];
    for (final legValue in legs) {
      final leg = legValue as Map<String, dynamic>;
      final rawSteps = leg['steps'] as List<dynamic>? ?? const [];
      for (final indexed in rawSteps.indexed) {
        final step = indexed.$2 as Map<String, dynamic>;
        final maneuver = step['maneuver'] as Map<String, dynamic>? ?? const {};
        final location = maneuver['location'] as List<dynamic>?;
        if (location == null || location.length < 2) continue;
        final point = LatLng(
          (location[1] as num).toDouble(),
          (location[0] as num).toDouble(),
        );
        final type = maneuver['type'] as String? ?? 'unknown';
        final modifier = maneuver['modifier'] as String? ?? '';
        final street = step['name'] as String? ?? '';
        final distanceMeters = (step['distance'] as num?)?.toDouble() ?? 0;
        steps.add(
          TajGoNavigationStep(
            id: 'osrm_${steps.length}_${type}_$modifier',
            instructionRu: _formatter.format(
              maneuverType: type,
              modifier: modifier,
              streetName: street,
              distanceMeters: distanceMeters,
            ),
            streetName: street,
            distanceMeters: distanceMeters,
            durationSeconds: (step['duration'] as num?)?.toDouble() ?? 0,
            maneuverType: type,
            modifier: modifier,
            location: point,
            polylineIndex: _nearestIndex(points, point),
          ),
        );
      }
    }
    return _roadRoute(
      points,
      distanceMeters: (route['distance'] as num).toDouble(),
      durationMilliseconds: (route['duration'] as num).toDouble() * 1000,
      steps: steps,
    );
  }

  TajGoRoute _parseGraphHopper(Map<String, dynamic> json) {
    final paths = json['paths'] as List<dynamic>?;
    if (paths == null || paths.isEmpty) throw StateError('Route not found.');
    final path = paths.first as Map<String, dynamic>;
    final pointsJson = path['points'] as Map<String, dynamic>;
    final points = _points(pointsJson['coordinates'] as List<dynamic>);
    return _roadRoute(
      points,
      distanceMeters: (path['distance'] as num).toDouble(),
      durationMilliseconds: (path['time'] as num).toDouble(),
      steps: const [],
    );
  }

  List<LatLng> _points(List<dynamic> coordinates) => coordinates.map((item) {
    final pair = item as List<dynamic>;
    return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
  }).toList();

  int _nearestIndex(List<LatLng> points, LatLng target) {
    const distance = Distance();
    var result = 0;
    var nearest = double.infinity;
    for (var index = 0; index < points.length; index++) {
      final meters = distance.as(LengthUnit.Meter, points[index], target);
      if (meters < nearest) {
        nearest = meters;
        result = index;
      }
    }
    return result;
  }

  TajGoRoute _roadRoute(
    List<LatLng> points, {
    required double distanceMeters,
    required double durationMilliseconds,
    required List<TajGoNavigationStep> steps,
  }) {
    if (points.length < 2) throw StateError('Route geometry is empty.');
    return TajGoRoute(
      points: points,
      distanceKm: distanceMeters / 1000,
      etaMinutes: (durationMilliseconds / 60000).ceil().clamp(1, 999),
      isRoadRouteApproximation: false,
      providerName: name,
      routeQuality: RouteQuality.road,
      steps: steps,
      createdAt: DateTime.now().toUtc(),
    );
  }
}
