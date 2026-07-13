import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/navigation_state.dart';
import 'tajgo_map_camera.dart';

class NavigationCameraController {
  NavigationCameraController({
    required this.mapController,
    required this.camera,
    this.onModeChanged,
  });

  final MapController mapController;
  final TajGoMapCamera camera;
  final void Function(NavigationCameraMode mode)? onModeChanged;

  NavigationCameraMode mode = NavigationCameraMode.follow;
  DateTime? _lastFollowAt;
  LatLng? _lastFollowPosition;

  void setFree() => _setMode(NavigationCameraMode.free);

  Future<void> followPosition(LatLng position, {double speedMps = 0}) async {
    _setMode(NavigationCameraMode.follow);
    final now = DateTime.now();
    final lastAt = _lastFollowAt;
    final lastPosition = _lastFollowPosition;
    if (lastAt != null && now.difference(lastAt) < const Duration(seconds: 1)) {
      return;
    }
    if (lastPosition != null &&
        const Distance().as(LengthUnit.Meter, lastPosition, position) < 4 &&
        lastAt != null &&
        now.difference(lastAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastFollowAt = now;
    _lastFollowPosition = position;
    final zoom = speedMps < 2
        ? 17.8
        : speedMps < 7
        ? 17.2
        : 16.5;
    await camera.animateTo(
      controller: mapController,
      target: position,
      zoom: zoom,
      duration: const Duration(milliseconds: 550),
    );
  }

  void showOverview(List<LatLng> points) {
    if (points.isEmpty) return;
    _setMode(NavigationCameraMode.overview);
    if (points.length == 1) {
      mapController.move(points.single, 16);
      return;
    }
    mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(48, 105, 48, 70),
      ),
    );
  }

  void _setMode(NavigationCameraMode value) {
    if (mode == value) return;
    mode = value;
    onModeChanged?.call(value);
  }
}
