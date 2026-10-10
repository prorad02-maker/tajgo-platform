import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:tajgo/features/map/models/tajgo_map_location.dart';
import 'package:tajgo/features/map/models/tajgo_route.dart';
import 'package:tajgo/features/map/services/geocoding_provider.dart';
import 'package:tajgo/features/map/services/road_route_provider.dart';
import 'package:tajgo/features/map/services/route_sanity_service.dart';
import 'package:tajgo/features/map/services/route_service.dart';
import 'package:tajgo/features/map/services/routing_config.dart';

const from = LatLng(40.2833, 69.6222);
const to = LatLng(40.2933, 69.6322);

RoutingConfig config({
  String url = 'https://routing.example.tj',
  bool enabled = true,
}) => RoutingConfig(
  enabled: enabled,
  providerType: RoutingProviderType.osrm,
  baseUrl: url,
  apiKey: '',
  timeout: const Duration(seconds: 2),
  mode: RouteMode.bicycle,
  debugLogging: false,
);

Map<String, dynamic> response() => {
  'code': 'Ok',
  'routes': [
    {
      'distance': 1800,
      'duration': 480,
      'geometry': {
        'coordinates': [
          [from.longitude, from.latitude],
          [69.627, 40.287],
          [to.longitude, to.latitude],
        ],
      },
      'legs': [],
    },
  ],
};

void main() {
  test('default builds enable a road service', () {
    final value = RoutingConfig.fromEnvironment();
    expect(value.enabled, isTrue);
    expect(value.validationIssues, isEmpty);
  });

  test('routing rejects non HTTP endpoints and missing hosts', () {
    for (final url in [
      'file:///tmp/routes',
      'https:',
      'https://user:secret@host.test',
      'https://host.test/#secret',
    ]) {
      expect(config(url: url).validationIssues, isNotEmpty);
    }
  });

  test('OSRM preserves endpoint path and query parameters', () {
    final provider = RoadRouteProvider(
      config: config(url: 'https://host.test/routing/?tenant=tajgo'),
    );
    final uri = provider.buildRequestUri(
      from: from,
      to: to,
      mode: RouteMode.car,
    );
    expect(uri.path, startsWith('/routing/route/v1/driving/'));
    expect(uri.queryParameters['tenant'], 'tajgo');
  });

  test('public OSRM selects transport dataset, not only URL profile', () {
    final provider = RoadRouteProvider(
      config: config(url: 'https://routing.openstreetmap.de'),
    );
    expect(
      provider
          .buildRequestUri(from: from, to: to, mode: RouteMode.bicycle)
          .path,
      startsWith('/routed-bike/route/v1/driving/'),
    );
    expect(
      provider.buildRequestUri(from: from, to: to, mode: RouteMode.car).path,
      startsWith('/routed-car/route/v1/driving/'),
    );
  });

  test('network request uses requested transport mode', () async {
    late Uri requested;
    final provider = RoadRouteProvider(
      config: config(),
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(jsonEncode(response()), 200);
      }),
    );
    final route = await provider.buildRoute(
      from: from,
      to: to,
      mode: RouteMode.car,
    );
    expect(requested.path, contains('/driving/'));
    expect(route.distanceKm, 1.8);
    expect(route.etaMinutes, 8);
    expect(route.points.length, 3);
  });

  test('provider outage is explicit fallback, not a road route', () async {
    final provider = RoadRouteProvider(
      config: config(),
      client: MockClient((_) async => http.Response('', 503)),
    );
    final route = await RouteService(
      roadProvider: provider,
    ).buildRoute(from: from, to: to, mode: RouteMode.bicycle);
    expect(route.isFallback, isTrue);
    expect(route.errorMessage, contains('503'));
  });

  test('road route with unrelated geometry is rejected', () {
    final provider = RoadRouteProvider(config: config());
    final json = response();
    (json['routes'] as List).first['geometry'] = {
      'coordinates': [
        [30, 50],
        [30.01, 50.01],
      ],
    };
    final result = const RouteSanityService().sanitize(
      candidate: provider.parseResponse(json),
      from: from,
      to: to,
      mode: RouteMode.bicycle,
    );
    expect(result.usedFallback, isTrue);
    expect(result.reason, contains('endpoints'));
  });

  test('address model roundtrip keeps coordinates and address together', () {
    const location = TajGoMapLocation(
      latitude: 40.28,
      longitude: 69.62,
      address: 'Сомони, 54, Худжанд',
    );
    final restored = TajGoMapLocation.fromGeoPoint(
      location.toGeoPoint(),
      address: location.address,
    );
    expect(restored.toMap(), location.toMap());
    expect(restored.isValid, isTrue);
    expect(
      const TajGoMapLocation(
        latitude: 91,
        longitude: 69,
        address: 'A',
      ).validate,
      throwsArgumentError,
    );
    expect(
      const TajGoMapLocation(latitude: 40, longitude: 69, address: ' ').isValid,
      isFalse,
    );
  });

  test('geocoder includes house number and removes duplicate locality', () {
    expect(
      formatPlacemarkAddress(
        const Placemark(
          street: 'Сомони',
          thoroughfare: 'Сомони',
          subThoroughfare: '54',
          subLocality: 'Худжанд',
          locality: 'Худжанд',
        ),
      ),
      'Сомони, 54, Худжанд',
    );
  });
}
