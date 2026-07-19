import 'package:latlong2/latlong.dart';

import 'pricing.dart';

enum CourierEligibilityIssue {
  none,
  activeOrder,
  locationMissing,
  locationStale,
  accuracyMissing,
  gpsWeak,
  outsideRadius,
}

class CourierEligibilityResult {
  const CourierEligibilityResult({required this.issue, this.distanceMeters});

  final CourierEligibilityIssue issue;
  final double? distanceMeters;
  bool get allowed => issue == CourierEligibilityIssue.none;

  String get message => switch (issue) {
    CourierEligibilityIssue.none => 'Заказ доступен.',
    CourierEligibilityIssue.activeOrder => 'Сначала завершите текущий заказ.',
    CourierEligibilityIssue.locationMissing ||
    CourierEligibilityIssue.locationStale => 'Обновляем ваше местоположение…',
    CourierEligibilityIssue.accuracyMissing ||
    CourierEligibilityIssue.gpsWeak =>
      'Нужна более точная геолокация. Подождите несколько секунд на открытом месте.',
    CourierEligibilityIssue.outsideRadius =>
      'Заказ пока далеко. Приблизьтесь к точке забора на расстояние меньше 1 км.',
  };
}

class CourierOrderEligibilityService {
  const CourierOrderEligibilityService({
    this.radiusMeters = 1000,
    this.maxLocationAge = const Duration(seconds: 15),
    this.maxAccuracyMeters = 50,
  });

  final double radiusMeters;
  final Duration maxLocationAge;
  final double maxAccuracyMeters;

  bool canAcceptDistance(double distanceMeters) =>
      distanceMeters < radiusMeters;

  CourierEligibilityResult evaluate({
    required LatLng? courierLocation,
    required DateTime? locationUpdatedAt,
    required double? accuracyMeters,
    required LatLng pickup,
    required bool hasActiveOrder,
    DateTime? now,
  }) {
    if (hasActiveOrder) {
      return const CourierEligibilityResult(
        issue: CourierEligibilityIssue.activeOrder,
      );
    }
    if (courierLocation == null || locationUpdatedAt == null) {
      return const CourierEligibilityResult(
        issue: CourierEligibilityIssue.locationMissing,
      );
    }
    final reference = now ?? DateTime.now();
    if (reference.difference(locationUpdatedAt).abs() > maxLocationAge) {
      return const CourierEligibilityResult(
        issue: CourierEligibilityIssue.locationStale,
      );
    }
    if (accuracyMeters == null || !accuracyMeters.isFinite) {
      return const CourierEligibilityResult(
        issue: CourierEligibilityIssue.accuracyMissing,
      );
    }
    if (accuracyMeters > maxAccuracyMeters) {
      return const CourierEligibilityResult(
        issue: CourierEligibilityIssue.gpsWeak,
      );
    }
    final meters = haversineDistanceKm(courierLocation, pickup) * 1000;
    return CourierEligibilityResult(
      issue: canAcceptDistance(meters)
          ? CourierEligibilityIssue.none
          : CourierEligibilityIssue.outsideRadius,
      distanceMeters: meters,
    );
  }
}
