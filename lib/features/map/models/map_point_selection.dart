import 'package:latlong2/latlong.dart';

import 'place_suggestion.dart';

enum MapPointType { pickup, dropoff }

class MapPointSelection {
  const MapPointSelection({
    required this.type,
    required this.point,
    required this.address,
    required this.confirmed,
    this.suggestion,
    this.approximate = false,
  });

  final MapPointType type;
  final LatLng point;
  final String address;
  final bool confirmed;
  final PlaceSuggestion? suggestion;
  final bool approximate;

  MapPointSelection copyWith({
    LatLng? point,
    String? address,
    bool? confirmed,
    PlaceSuggestion? suggestion,
    bool? approximate,
  }) => MapPointSelection(
    type: type,
    point: point ?? this.point,
    address: address ?? this.address,
    confirmed: confirmed ?? this.confirmed,
    suggestion: suggestion ?? this.suggestion,
    approximate: approximate ?? this.approximate,
  );
}
