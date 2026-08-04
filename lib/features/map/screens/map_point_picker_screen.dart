import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/map_provider_config.dart';
import '../../../shared/design/tajgo_components.dart';
import '../../../shared/widgets/tajgo_scope.dart';

/// Универсальный выбор точки на карте (адрес магазина, сохранённый адрес).
/// Возвращает выбранную [LatLng] через `Navigator.pop`.
class MapPointPickerScreen extends StatefulWidget {
  const MapPointPickerScreen({
    super.key,
    this.initial,
    this.title = 'Точка на карте',
  });

  final LatLng? initial;
  final String title;

  @override
  State<MapPointPickerScreen> createState() => _MapPointPickerScreenState();
}

class _MapPointPickerScreenState extends State<MapPointPickerScreen> {
  static const LatLng _khujand = LatLng(40.2833, 69.6222);

  final MapController _map = MapController();
  late LatLng _center = widget.initial ?? _khujand;
  bool _locating = false;

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final position = await TajGoScope.of(
        context,
      ).locationService.determineCurrentPosition();
      final target = LatLng(position.latitude, position.longitude);
      _map.move(target, 16);
      setState(() => _center = target);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось определить местоположение. Наведите карту вручную.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TajGoAppBar(title: widget.title),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              minZoom: 3,
              maxZoom: 19,
              onPositionChanged: (camera, _) => _center = camera.center,
            ),
            children: [
              TileLayer(
                urlTemplate: MapProviderConfig.current.tileUrlTemplate,
                userAgentPackageName:
                    MapProviderConfig.current.userAgentPackageName,
                maxZoom: 19,
              ),
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution(MapProviderConfig.attributionText),
                ],
              ),
            ],
          ),
          // Центр-маркер: точка = центр карты.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_on,
                  size: 44,
                  color: TajGoColors.darkGreen,
                ),
              ),
            ),
          ),
          Positioned(
            right: TajGoSpacing.lg,
            bottom: 96,
            child: FloatingActionButton.small(
              heroTag: 'picker-locate',
              backgroundColor: TajGoColors.card,
              foregroundColor: TajGoColors.darkGreen,
              onPressed: _locating ? null : _locate,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: TajGoSpacing.lg,
            right: TajGoSpacing.lg,
            bottom: TajGoSpacing.lg,
            child: SafeArea(
              top: false,
              child: TajGoPrimaryButton(
                label: 'Выбрать эту точку',
                icon: Icons.check_rounded,
                onPressed: () => Navigator.of(context).pop(_center),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
