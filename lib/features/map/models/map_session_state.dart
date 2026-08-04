enum LocationAvailability {
  idle,
  locating,
  fresh,
  stale,
  poorAccuracy,
  serviceDisabled,
  denied,
  deniedForever,
  timeout,
  unavailable,
}

class LocationFixQuality {
  const LocationFixQuality({
    required this.state,
    required this.age,
    required this.accuracyMeters,
  });

  final LocationAvailability state;
  final Duration age;
  final double accuracyMeters;

  bool get usableForInitialCamera =>
      state == LocationAvailability.fresh ||
      state == LocationAvailability.stale ||
      state == LocationAvailability.poorAccuracy;
  bool get authoritative => state == LocationAvailability.fresh;

  static LocationFixQuality evaluate({
    required DateTime timestamp,
    required double accuracyMeters,
    required DateTime now,
    Duration maxAge = const Duration(minutes: 2),
    double maxAccuracyMeters = 50,
  }) {
    final age = now.toUtc().difference(timestamp.toUtc());
    if (age > maxAge) {
      return LocationFixQuality(
        state: LocationAvailability.stale,
        age: age,
        accuracyMeters: accuracyMeters,
      );
    }
    if (!accuracyMeters.isFinite || accuracyMeters > maxAccuracyMeters) {
      return LocationFixQuality(
        state: LocationAvailability.poorAccuracy,
        age: age,
        accuracyMeters: accuracyMeters,
      );
    }
    return LocationFixQuality(
      state: LocationAvailability.fresh,
      age: age,
      accuracyMeters: accuracyMeters,
    );
  }
}

class CameraOwnership {
  const CameraOwnership({
    this.userHasInteracted = false,
    this.explicitRecenter = false,
  });

  final bool userHasInteracted;
  final bool explicitRecenter;

  bool get permitsAutomaticMove => !userHasInteracted || explicitRecenter;

  CameraOwnership onUserGesture() =>
      const CameraOwnership(userHasInteracted: true);
  CameraOwnership requestRecenter() => CameraOwnership(
    userHasInteracted: userHasInteracted,
    explicitRecenter: true,
  );
  CameraOwnership consumeMove() => CameraOwnership(
    userHasInteracted: userHasInteracted,
    explicitRecenter: false,
  );
}

enum DeliveryMapFlowState {
  noPoints,
  pickupSelected,
  calculating,
  routeReady,
  routeError,
}

class LatestRequestGate {
  int _generation = 0;

  int begin() => ++_generation;
  void cancel() => ++_generation;
  bool isCurrent(int generation) => generation == _generation;
}
