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
  String? _lastRequestUrl;
  int? _lastHttpStatus;
  bool? _lastParseSuccess;
  int? _lastPointsCount;
  double? _lastDistanceKm;
  int? _lastEtaMinutes;
  String? _fallbackReason;

  void recordCacheHit(TajGoRoute route) {
    _cacheHits++;
    _lastQuality = route.routeQuality;
    notifyListeners();
  }

  void recordSuccess(
    TajGoRoute route,
    Duration latency, {
    String? requestUrl,
    int? httpStatus,
    bool? parseSuccess,
  }) {
    _requests++;
    _successes++;
    _lastAttemptAt = DateTime.now().toUtc();
    _lastSuccessAt = _lastAttemptAt;
    _lastLatency = latency;
    _lastError = null;
    _lastQuality = route.routeQuality;
    _lastRequestUrl = requestUrl;
    _lastHttpStatus = httpStatus;
    _lastParseSuccess = parseSuccess;
    _lastPointsCount = route.points.length;
    _lastDistanceKm = route.distanceKm;
    _lastEtaMinutes = route.etaMinutes;
    _fallbackReason = null;
    notifyListeners();
  }

  void recordFallback(
    String reason,
    Duration latency, {
    String? requestUrl,
    int? httpStatus,
    bool? parseSuccess,
    TajGoRoute? route,
  }) {
    _requests++;
    _fallbacks++;
    _lastAttemptAt = DateTime.now().toUtc();
    _lastLatency = latency;
    _lastError = reason;
    _lastQuality = RouteQuality.providerError;
    _lastRequestUrl = requestUrl;
    _lastHttpStatus = httpStatus;
    _lastParseSuccess = parseSuccess;
    _lastPointsCount = route?.points.length;
    _lastDistanceKm = route?.distanceKm;
    _lastEtaMinutes = route?.etaMinutes;
    _fallbackReason = reason;
    notifyListeners();
  }

  void recordDisabledFallback(TajGoRoute route) {
    _fallbacks++;
    _lastQuality = RouteQuality.directFallback;
    _lastPointsCount = route.points.length;
    _lastDistanceKm = route.distanceKm;
    _lastEtaMinutes = route.etaMinutes;
    _fallbackReason = 'Routing provider выключен или не настроен';
    notifyListeners();
  }

  RoutingHealthSnapshot get snapshot => RoutingHealthSnapshot(
    providerName: config.providerType.name,
    enabled: config.enabled,
    configured: config.isConfigured && config.validationIssues.isEmpty,
    baseUrlSet: config.baseUrl.trim().isNotEmpty,
    requests: _requests,
    successes: _successes,
    fallbacks: _fallbacks,
    cacheHits: _cacheHits,
    lastAttemptAt: _lastAttemptAt,
    lastSuccessAt: _lastSuccessAt,
    lastLatency: _lastLatency,
    lastError: _lastError,
    lastQuality: _lastQuality,
    lastRequestUrl: _lastRequestUrl,
    lastHttpStatus: _lastHttpStatus,
    lastParseSuccess: _lastParseSuccess,
    lastPointsCount: _lastPointsCount,
    lastDistanceKm: _lastDistanceKm,
    lastEtaMinutes: _lastEtaMinutes,
    fallbackReason: _fallbackReason,
  );
}
