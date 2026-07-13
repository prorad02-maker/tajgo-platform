import 'package:latlong2/latlong.dart';

class TajGoNavigationStep {
  const TajGoNavigationStep({
    required this.id,
    required this.instructionRu,
    required this.streetName,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuverType,
    required this.modifier,
    required this.location,
    required this.polylineIndex,
  });

  final String id;
  final String instructionRu;
  final String streetName;
  final double distanceMeters;
  final double durationSeconds;
  final String maneuverType;
  final String modifier;
  final LatLng location;
  final int polylineIndex;
}
