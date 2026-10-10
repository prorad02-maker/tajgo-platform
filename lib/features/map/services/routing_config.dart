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
    this.profileOverride = '',
  });

  final bool enabled;
  final RoutingProviderType providerType;
  final String baseUrl;
  final String apiKey;
  final Duration timeout;
  final RouteMode mode;
  final bool debugLogging;
  final String profileOverride;

  factory RoutingConfig.fromEnvironment() {
    const preferredProvider = String.fromEnvironment('ROUTING_PROVIDER');
    const legacyProvider = String.fromEnvironment(
      'TAJGO_ROUTE_PROVIDER',
      defaultValue: 'osrm',
    );
    const provider = preferredProvider == ''
        ? legacyProvider
        : preferredProvider;
    const preferredMode = String.fromEnvironment('ROUTING_MODE');
    const legacyMode = String.fromEnvironment(
      'TAJGO_ROUTE_MODE',
      defaultValue: 'bicycle',
    );
    const modeValue = preferredMode == '' ? legacyMode : preferredMode;
    const preferredBaseUrl = String.fromEnvironment('ROUTING_BASE_URL');
    const legacyBaseUrl = String.fromEnvironment('TAJGO_ROUTE_ENDPOINT');
    const preferredKey = String.fromEnvironment('ROUTING_API_KEY');
    const legacyKey = String.fromEnvironment('TAJGO_ROUTE_API_KEY');
    const timeoutSeconds = int.fromEnvironment(
      'ROUTING_TIMEOUT_SECONDS',
      defaultValue: 0,
    );
    const legacyTimeoutMs = int.fromEnvironment(
      'TAJGO_ROUTE_TIMEOUT_MS',
      defaultValue: 7000,
    );
    return RoutingConfig(
      enabled:
          const bool.fromEnvironment('ROUTING_ENABLED', defaultValue: true) &&
          const bool.fromEnvironment('TAJGO_ROUTE_ENABLED', defaultValue: true),
      providerType: provider == 'graphhopper'
          ? RoutingProviderType.graphHopper
          : RoutingProviderType.osrm,
      baseUrl: preferredBaseUrl.isNotEmpty
          ? preferredBaseUrl
          : legacyBaseUrl.isNotEmpty
          ? legacyBaseUrl
          : 'https://routing.openstreetmap.de',
      apiKey: preferredKey == '' ? legacyKey : preferredKey,
      timeout: Duration(
        milliseconds: timeoutSeconds > 0
            ? timeoutSeconds * 1000
            : legacyTimeoutMs,
      ),
      mode: routeModeFromString(modeValue),
      debugLogging: kDebugMode,
      profileOverride: const String.fromEnvironment('ROUTING_PROFILE'),
    );
  }

  bool get isConfigured => enabled && baseUrl.trim().isNotEmpty;

  List<String> get validationIssues => [
    if (enabled && baseUrl.trim().isEmpty) 'ROUTING_BASE_URL не задан',
    if (timeout <= Duration.zero) 'Timeout должен быть больше нуля',
    if (baseUrl.isNotEmpty && !_validEndpoint(baseUrl))
      'ROUTING_BASE_URL должен быть HTTP(S) URL с именем сервера',
  ];

  static bool _validEndpoint(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment;
  }
}
