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
    if (age < const Duration(seconds: -5) || age > maxAge) {
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

class DeliveryRequestCoordinator {
  int _cityOwnership = 0;
  int _inputGeneration = 0;
  int _gpsGeneration = 0;
  int _reverseGeneration = 0;
  int _routeGeneration = 0;
  int _quoteGeneration = 0;

  int get cityOwnership => _cityOwnership;
  int get inputGeneration => _inputGeneration;

  int beginGps() => ++_gpsGeneration;
  int beginReverse() => ++_reverseGeneration;
  int beginRoute() => ++_routeGeneration;
  int beginQuote() => ++_quoteGeneration;

  bool isGpsCurrent(int value) => value == _gpsGeneration;
  bool isReverseCurrent(int value) => value == _reverseGeneration;
  bool isRouteCurrent(int value) => value == _routeGeneration;
  bool isQuoteCurrent(int value) => value == _quoteGeneration;

  void inputChanged() {
    _inputGeneration++;
    _reverseGeneration++;
    _routeGeneration++;
    _quoteGeneration++;
  }

  void manualCitySwitch() {
    _cityOwnership++;
    _gpsGeneration++;
    inputChanged();
  }

  void pause() {
    _gpsGeneration++;
    _reverseGeneration++;
    _routeGeneration++;
    _quoteGeneration++;
  }
}
