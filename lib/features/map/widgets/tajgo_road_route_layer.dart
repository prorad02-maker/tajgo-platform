import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/tajgo_colors.dart';
import '../../../shared/widgets/tajgo_scope.dart';
import '../models/tajgo_route.dart';
import '../services/route_service.dart';

/// Loads only a validated road route. Changing endpoints immediately hides the
/// previous geometry, even when its request completes after the new selection.
class TajGoRoadRouteLayer extends StatefulWidget {
  const TajGoRoadRouteLayer({
    super.key,
    required this.from,
    required this.to,
    this.mode = RouteMode.bicycle,
    this.routeService,
    this.statusBottomPadding = 32,
  });
  final LatLng from, to;
  final RouteMode mode;
  final RouteService? routeService;
  final double statusBottomPadding;

  @override
  State<TajGoRoadRouteLayer> createState() => _TajGoRoadRouteLayerState();
}

class _TajGoRoadRouteLayerState extends State<TajGoRoadRouteLayer> {
  RouteService? _service;
  Future<TajGoRoute>? _route;

  void _load({bool force = false}) {
    _route = _service!.buildRoute(
      from: widget.from,
      to: widget.to,
      mode: widget.mode,
      forceRefresh: force,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = widget.routeService ?? TajGoScope.of(context).routeService;
    if (_service != service) {
      _service = service;
      _load();
    }
  }

  @override
  void didUpdateWidget(TajGoRoadRouteLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.from != widget.from ||
        oldWidget.to != widget.to ||
        oldWidget.mode != widget.mode ||
        oldWidget.routeService != widget.routeService) {
      _service = widget.routeService ?? TajGoScope.of(context).routeService;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TajGoRoute>(
    future: _route,
    builder: (context, snapshot) {
      final loading = snapshot.connectionState != ConnectionState.done;
      final route = loading ? null : snapshot.data;
      if (!snapshot.hasError && route?.routeQuality == RouteQuality.road) {
        return PolylineLayer(
          polylines: [
            Polyline(
              points: route!.polylinePoints,
              color: TajGoColors.green,
              strokeWidth: 4,
            ),
          ],
        );
      }
      return Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, widget.statusBottomPadding),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading) ...[
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      loading ? 'Строим маршрут…' : 'Маршрут недоступен',
                    ),
                  ),
                  if (!loading)
                    TextButton(
                      onPressed: () => setState(() => _load(force: true)),
                      child: const Text('Повторить'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
