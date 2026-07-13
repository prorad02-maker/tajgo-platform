import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/tajgo_route.dart';
import 'route_provider.dart';

enum RoadRouteApi { osrm, graphHopper }

class RoadRouteProvider implements RouteProvider {
  RoadRouteProvider({
    String? endpoint,
    String? apiKey,
    RoadRouteApi? api,
    http.Client? client,
  }) : endpoint =
           endpoint ?? const String.fromEnvironment('TAJGO_ROUTE_ENDPOINT'),
       apiKey = apiKey ?? const String.fromEnvironment('TAJGO_ROUTE_API_KEY'),
       api =
           api ??
           (const String.fromEnvironment('TAJGO_ROUTE_PROVIDER') ==
                   'graphhopper'
               ? RoadRouteApi.graphHopper
               : RoadRouteApi.osrm),
       _client = client ?? http.Client();

  final String endpoint;
  final String apiKey;
  final RoadRouteApi api;
  final http.Client _client;

  bool get configured => endpoint.trim().isNotEmpty;

  @override
  String get name => api == RoadRouteApi.osrm ? 'osrm' : 'graphhopper';

  @override
  Future<TajGoRoute> buildRoute({
    required LatLng from,
    required LatLng to,
    required RouteMode mode,
  }) async {
    if (!configured) {
      throw StateError('Road route endpoint is not configured.');
    }
    final uri = api == RoadRouteApi.osrm
        ? _osrmUri(from, to, mode)
        : _graphHopperUri(from, to, mode);
    final response = await _client.get(uri).timeout(const Duration(seconds: 7));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Route provider returned ${response.statusCode}.');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return api == RoadRouteApi.osrm
        ? _parseOsrm(json)
        : _parseGraphHopper(json);
  }

  Uri _osrmUri(LatLng from, LatLng to, RouteMode mode) {
    final profile = switch (mode) {
      RouteMode.walking => 'foot',
      RouteMode.bicycle => 'bike',
      RouteMode.scooter || RouteMode.car => 'driving',
    };
    final base = endpoint.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse(
      '$base/route/v1/$profile/${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
    ).replace(
      queryParameters: const {'overview': 'full', 'geometries': 'geojson'},
    );
  }

  Uri _graphHopperUri(LatLng from, LatLng to, RouteMode mode) {
    final profile = switch (mode) {
      RouteMode.walking => 'foot',
      RouteMode.bicycle => 'bike',
      RouteMode.scooter => 'scooter',
      RouteMode.car => 'car',
    };
    final base = Uri.parse(endpoint);
    final query = <String>[
      if (base.query.isNotEmpty) base.query,
      'point=${Uri.encodeQueryComponent('${from.latitude},${from.longitude}')}',
      'point=${Uri.encodeQueryComponent('${to.latitude},${to.longitude}')}',
      'profile=${Uri.encodeQueryComponent(profile)}',
      'points_encoded=false',
      if (apiKey.isNotEmpty) 'key=${Uri.encodeQueryComponent(apiKey)}',
    ].join('&');
    return base.replace(query: query);
  }

  TajGoRoute _parseOsrm(Map<String, dynamic> json) {
    final routes = json['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) throw StateError('Route not found.');
    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;
    return _roadRoute(
      coordinates,
      distanceMeters: (route['distance'] as num).toDouble(),
      durationMilliseconds: (route['duration'] as num).toDouble() * 1000,
    );
  }

  TajGoRoute _parseGraphHopper(Map<String, dynamic> json) {
    final paths = json['paths'] as List<dynamic>?;
    if (paths == null || paths.isEmpty) throw StateError('Route not found.');
    final path = paths.first as Map<String, dynamic>;
    final points = path['points'] as Map<String, dynamic>;
    final coordinates = points['coordinates'] as List<dynamic>;
    return _roadRoute(
      coordinates,
      distanceMeters: (path['distance'] as num).toDouble(),
      durationMilliseconds: (path['time'] as num).toDouble(),
    );
  }

  TajGoRoute _roadRoute(
    List<dynamic> coordinates, {
    required double distanceMeters,
    required double durationMilliseconds,
  }) {
    final points = coordinates.map((item) {
      final pair = item as List<dynamic>;
      return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
    }).toList();
    if (points.length < 2) throw StateError('Route geometry is empty.');
    return TajGoRoute(
      points: points,
      distanceKm: distanceMeters / 1000,
      etaMinutes: (durationMilliseconds / 60000).ceil().clamp(1, 999),
      isRoadRouteApproximation: false,
      providerName: name,
      routeQuality: RouteQuality.road,
      createdAt: DateTime.now().toUtc(),
    );
  }
}
