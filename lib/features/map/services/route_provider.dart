import 'package:latlong2/latlong.dart';

import '../models/tajgo_route.dart';

abstract class RouteProvider {
  String get name;

  Future<TajGoRoute> buildRoute({
    required LatLng from,
    required LatLng to,
    required RouteMode mode,
  });
}
