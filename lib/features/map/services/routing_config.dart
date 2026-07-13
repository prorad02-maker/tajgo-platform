import 'package:flutter/foundation.dart';

import '../models/tajgo_route.dart';

enum RoutingProviderType { osrm, graphHopper }

class RoutingConfig {
  const RoutingConfig({
    required this.enabled,
    required this.providerType,
    required this.baseUrl,
    required this.apiKey,
    required this.timeout,
    required this.mode,
    required this.debugLogging,
  });

  final bool enabled;
  final RoutingProviderType providerType;
  final String baseUrl;
  final String apiKey;
  final Duration timeout;
  final RouteMode mode;
  final bool debugLogging;

  factory RoutingConfig.fromEnvironment() {
    const provider = String.fromEnvironment(
      'TAJGO_ROUTE_PROVIDER',
      defaultValue: 'osrm',
    );
    const modeValue = String.fromEnvironment(
      'TAJGO_ROUTE_MODE',
      defaultValue: 'bicycle',
    );
    return RoutingConfig(
      enabled: const bool.fromEnvironment(
        'TAJGO_ROUTE_ENABLED',
        defaultValue: false,
      ),
      providerType: provider == 'graphhopper'
          ? RoutingProviderType.graphHopper
          : RoutingProviderType.osrm,
      baseUrl: const String.fromEnvironment('TAJGO_ROUTE_ENDPOINT'),
      apiKey: const String.fromEnvironment('TAJGO_ROUTE_API_KEY'),
      timeout: Duration(
        milliseconds: const int.fromEnvironment(
          'TAJGO_ROUTE_TIMEOUT_MS',
          defaultValue: 7000,
        ),
      ),
      mode: switch (modeValue) {
        'walking' => RouteMode.walking,
        'scooter' => RouteMode.scooter,
        'car' => RouteMode.car,
        _ => RouteMode.bicycle,
      },
      debugLogging: kDebugMode,
    );
  }
}
