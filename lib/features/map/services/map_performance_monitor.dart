import 'package:flutter/foundation.dart';

class MapPerformanceSnapshot {
  const MapPerformanceSnapshot({
    required this.searches,
    required this.routeBuilds,
    required this.reverseGeocodes,
    required this.slowOperations,
    required this.totalRouteTime,
    required this.totalSearchTime,
  });

  final int searches;
  final int routeBuilds;
  final int reverseGeocodes;
  final int slowOperations;
  final Duration totalRouteTime;
  final Duration totalSearchTime;

  int get averageRouteMs =>
      routeBuilds == 0 ? 0 : totalRouteTime.inMilliseconds ~/ routeBuilds;
  int get averageSearchMs =>
      searches == 0 ? 0 : totalSearchTime.inMilliseconds ~/ searches;
}

class MapPerformanceMonitor extends ChangeNotifier {
  static final MapPerformanceMonitor shared = MapPerformanceMonitor();

  int _searches = 0;
  int _routeBuilds = 0;
  int _reverseGeocodes = 0;
  int _slowOperations = 0;
  Duration _totalRouteTime = Duration.zero;
  Duration _totalSearchTime = Duration.zero;

  void recordSearch(Duration elapsed) {
    _searches++;
    _totalSearchTime += elapsed;
    if (elapsed > const Duration(milliseconds: 800)) _slowOperations++;
    notifyListeners();
  }

  void recordRoute(Duration elapsed) {
    _routeBuilds++;
    _totalRouteTime += elapsed;
    if (elapsed > const Duration(seconds: 3)) _slowOperations++;
    notifyListeners();
  }

  void recordReverseGeocode(Duration elapsed) {
    _reverseGeocodes++;
    if (elapsed > const Duration(seconds: 2)) _slowOperations++;
    notifyListeners();
  }

  MapPerformanceSnapshot get snapshot => MapPerformanceSnapshot(
    searches: _searches,
    routeBuilds: _routeBuilds,
    reverseGeocodes: _reverseGeocodes,
    slowOperations: _slowOperations,
    totalRouteTime: _totalRouteTime,
    totalSearchTime: _totalSearchTime,
  );
}
