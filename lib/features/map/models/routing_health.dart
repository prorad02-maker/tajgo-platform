import 'tajgo_route.dart';

class RoutingHealthSnapshot {
  const RoutingHealthSnapshot({
    required this.providerName,
    required this.enabled,
    required this.configured,
    required this.baseUrlSet,
    required this.requests,
    required this.successes,
    required this.fallbacks,
    required this.cacheHits,
    this.lastAttemptAt,
    this.lastSuccessAt,
    this.lastLatency,
    this.lastError,
    this.lastQuality,
    this.lastRequestUrl,
    this.lastHttpStatus,
    this.lastParseSuccess,
    this.lastPointsCount,
    this.lastDistanceKm,
    this.lastEtaMinutes,
    this.fallbackReason,
  });

  final String providerName;
  final bool enabled;
  final bool configured;
  final bool baseUrlSet;
  final int requests;
  final int successes;
  final int fallbacks;
  final int cacheHits;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;
  final Duration? lastLatency;
  final String? lastError;
  final RouteQuality? lastQuality;
  final String? lastRequestUrl;
  final int? lastHttpStatus;
  final bool? lastParseSuccess;
  final int? lastPointsCount;
  final double? lastDistanceKm;
  final int? lastEtaMinutes;
  final String? fallbackReason;

  bool get healthy => configured && successes > 0 && lastError == null;

  String get statusLabel {
    if (!enabled) return 'Провайдер выключен';
    if (!configured) return 'Конфигурация неполная';
    if (healthy) return 'Провайдер отвечает';
    if (lastError != null) return 'Включён безопасный fallback';
    return 'Готов к проверке';
  }
}
