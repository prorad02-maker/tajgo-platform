import 'package:flutter/foundation.dart';

import '../models/routing_health.dart';
import '../models/tajgo_route.dart';
import 'routing_config.dart';

class RoutingHealthMonitor extends ChangeNotifier {
  RoutingHealthMonitor(this.config);

  final RoutingConfig config;
  int _requests = 0;
  int _successes = 0;
  int _fallbacks = 0;
  int _cacheHits = 0;
  DateTime? _lastAttemptAt;
  DateTime? _lastSuccessAt;
  Duration? _lastLatency;
  String? _lastError;
  RouteQuality? _lastQuality;

  void recordCacheHit(TajGoRoute route) {
    _cacheHits++;
    _lastQuality = route.routeQuality;
    notifyListeners();
  }

  void recordSuccess(TajGoRoute route, Duration latency) {
    _requests++;
    _successes++;
    _lastAttemptAt = DateTime.now().toUtc();
    _lastSuccessAt = _lastAttemptAt;
    _lastLatency = latency;
    _lastError = null;
    _lastQuality = route.routeQuality;
    notifyListeners();
  }

  void recordFallback(String reason, Duration latency) {
    _requests++;
    _fallbacks++;
    _lastAttemptAt = DateTime.now().toUtc();
    _lastLatency = latency;
    _lastError = reason;
    _lastQuality = RouteQuality.providerError;
    notifyListeners();
  }

  void recordDisabledFallback() {
    _fallbacks++;
    _lastQuality = RouteQuality.directFallback;
    notifyListeners();
  }

  RoutingHealthSnapshot get snapshot => RoutingHealthSnapshot(
    providerName: config.providerType.name,
    enabled: config.enabled,
    configured: config.isConfigured && config.validationIssues.isEmpty,
    requests: _requests,
    successes: _successes,
    fallbacks: _fallbacks,
    cacheHits: _cacheHits,
    lastAttemptAt: _lastAttemptAt,
    lastSuccessAt: _lastSuccessAt,
    lastLatency: _lastLatency,
    lastError: _lastError,
    lastQuality: _lastQuality,
  );
}
