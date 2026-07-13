import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_courier.dart';
import '../../core/models/tajgo_order.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../map/services/tajgo_map_camera.dart';
import '../map/widgets/tajgo_location_widgets.dart';
import 'admin_couriers_screen.dart';
import 'admin_order_details_screen.dart';
import 'admin_orders_screen.dart';
import 'widgets/admin_access_gate.dart';

enum _DispatchFilter { all, couriers, waiting, active }

class DispatchMapScreen extends StatefulWidget {
  const DispatchMapScreen({super.key, this.focusCourierId});
  final String? focusCourierId;

  @override
  State<DispatchMapScreen> createState() => _DispatchMapScreenState();
}

class _DispatchMapScreenState extends State<DispatchMapScreen> {
  static const _khujand = LatLng(40.2833, 69.6222);
  final _map = MapController();
  final _camera = TajGoMapCamera();
  Object? _selected;
  LatLng? _currentPosition;
  bool _locating = false;
  bool _focused = false;
  _DispatchFilter _filter = _DispatchFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreLocation());
  }

  Future<void> _restoreLocation() async {
    final position = await TajGoScope.of(
      context,
    ).locationService.currentPositionIfAuthorized();
    if (mounted && position != null) {
      setState(
        () => _currentPosition = LatLng(position.latitude, position.longitude),
      );
    }
  }

  Future<void> _locate() async {
    if (_locating) {
      return;
    }
    setState(() => _locating = true);
    final service = TajGoScope.of(context).locationService;
    try {
      final position = await service.determineCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) {
        return;
      }
      setState(() => _currentPosition = point);
      await _camera.animateTo(
        controller: _map,
        target: point,
        zoom: TajGoMapCamera.cityZoom,
      );
    } catch (error) {
      if (mounted) {
        final issue = service.userFacingException(error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(issue.message),
            action: issue.requiresSettings
                ? SnackBarAction(
                    label: 'Настройки',
                    onPressed: () async {
                      await service.openSettingsFor(issue.issue);
                    },
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  void _showCity() {
    setState(() => _selected = null);
    _camera.animateTo(controller: _map, target: _khujand, zoom: 12.5);
  }

  @override
  void dispose() {
    _camera.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdminAccessGate(
    child: Scaffold(
      body: StreamBuilder<List<TajGoCourier>>(
        stream: TajGoScope.of(context).adminRepository.couriersStream(),
        builder: (context, courierSnapshot) => StreamBuilder<List<TajGoOrder>>(
          stream: TajGoScope.of(
            context,
          ).adminRepository.ordersStream(limit: 50),
          builder: (context, orderSnapshot) {
            final couriers = courierSnapshot.data ?? const <TajGoCourier>[];
            final online = couriers
                .where((courier) => courier.online && courier.location != null)
                .toList();
            final orders = (orderSnapshot.data ?? const <TajGoOrder>[])
                .where(
                  (order) => const {
                    OrderStatus.waiting,
                    OrderStatus.accepted,
                    OrderStatus.pickedUp,
                    OrderStatus.delivered,
                  }.contains(order.status),
                )
                .toList();
            final waitingCount = orders
                .where((order) => order.status == OrderStatus.waiting)
                .length;
            final activeCount = orders.length - waitingCount;
            final visibleCouriers =
                _filter == _DispatchFilter.all ||
                    _filter == _DispatchFilter.couriers
                ? online
                : const <TajGoCourier>[];
            final visibleOrders = orders.where((order) {
              return switch (_filter) {
                _DispatchFilter.all => true,
                _DispatchFilter.couriers => false,
                _DispatchFilter.waiting => order.status == OrderStatus.waiting,
                _DispatchFilter.active => order.status != OrderStatus.waiting,
              };
            }).toList();
            if (!_focused && widget.focusCourierId != null) {
              final focused = couriers
                  .where(
                    (courier) =>
                        courier.uid == widget.focusCourierId &&
                        courier.location != null,
                  )
                  .firstOrNull;
              if (focused != null) {
                _focused = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _camera.animateTo(
                    controller: _map,
                    target: LatLng(
                      focused.location!.latitude,
                      focused.location!.longitude,
                    ),
                    zoom: TajGoMapCamera.cityZoom,
                  );
                  setState(() => _selected = focused);
                });
              }
            }
            final routeLines = <Polyline>[];
            final selectedOrder = _selected is TajGoOrder
                ? _selected as TajGoOrder
                : null;
            for (final order in <TajGoOrder>[?selectedOrder]) {
              if (order.fromLocation == null || order.toLocation == null) {
                continue;
              }
              final route = TajGoScope.of(context).routeService.directRoute(
                from: LatLng(
                  order.fromLocation!.latitude,
                  order.fromLocation!.longitude,
                ),
                to: LatLng(
                  order.toLocation!.latitude,
                  order.toLocation!.longitude,
                ),
              );
              routeLines.add(
                Polyline(
                  points: route.polylinePoints,
                  color: TajGoColors.green.withValues(alpha: 0.45),
                  strokeWidth: 3,
                ),
              );
            }
            return Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: const MapOptions(
                    initialCenter: _khujand,
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'tj.tajgo.app',
                    ),
                    PolylineLayer(polylines: routeLines),
                    MarkerLayer(
                      markers: [
                        ...visibleCouriers.map(
                          (courier) => Marker(
                            point: LatLng(
                              courier.location!.latitude,
                              courier.location!.longitude,
                            ),
                            width: 34,
                            height: 34,
                            child: GestureDetector(
                              onTap: () => setState(() => _selected = courier),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: TajGoColors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.delivery_dining_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                        ...visibleOrders.expand((order) sync* {
                          if (order.fromLocation != null) {
                            yield Marker(
                              point: LatLng(
                                order.fromLocation!.latitude,
                                order.fromLocation!.longitude,
                              ),
                              width: 42,
                              height: 42,
                              child: GestureDetector(
                                onTap: () => setState(() => _selected = order),
                                child: Icon(
                                  Icons.location_pin,
                                  color: order.status == OrderStatus.waiting
                                      ? TajGoColors.darkGreen
                                      : TajGoColors.darkGreen.withValues(
                                          alpha: 0.55,
                                        ),
                                  size: 42,
                                ),
                              ),
                            );
                          }
                          if (order.status != OrderStatus.waiting &&
                              order.toLocation != null) {
                            yield Marker(
                              point: LatLng(
                                order.toLocation!.latitude,
                                order.toLocation!.longitude,
                              ),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => setState(() => _selected = order),
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Colors.blue,
                                  size: 40,
                                ),
                              ),
                            );
                          }
                        }),
                        if (_currentPosition != null)
                          Marker(
                            point: _currentPosition!,
                            width: 44,
                            height: 44,
                            child: const TajGoCurrentLocationMarker(),
                          ),
                      ],
                    ),
                  ],
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 4,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                        const Spacer(),
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Text(
                              '🛵 ${online.length} на линии · 📦 $waitingCount ждут · 🚚 $activeCount в пути',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 70,
                  left: 12,
                  right: 12,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          children: [
                            _filterChip('Все', _DispatchFilter.all),
                            _filterChip('Курьеры', _DispatchFilter.couriers),
                            _filterChip('Ждут', _DispatchFilter.waiting),
                            _filterChip('В пути', _DispatchFilter.active),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: _selected == null ? 16 : 124,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'dispatchCity',
                        onPressed: _showCity,
                        backgroundColor: Colors.white,
                        foregroundColor: TajGoColors.darkGreen,
                        tooltip: 'Показать весь город',
                        child: const Icon(Icons.location_city_rounded),
                      ),
                      const SizedBox(height: 8),
                      TajGoLocateButton(
                        heroTag: 'dispatchLocate',
                        loading: _locating,
                        onPressed: _locate,
                      ),
                    ],
                  ),
                ),
                if (_selected != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _PeekCard(
                      selected: _selected!,
                      onClose: () => setState(() => _selected = null),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _filterChip(String label, _DispatchFilter value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: FilterChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() {
        _filter = value;
        _selected = null;
      }),
    ),
  );
}

class _PeekCard extends StatelessWidget {
  const _PeekCard({required this.selected, required this.onClose});
  final Object selected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isCourier = selected is TajGoCourier;
    final title = isCourier
        ? (selected as TajGoCourier).name
        : '${(selected as TajGoOrder).fromText} → ${(selected as TajGoOrder).toText}';
    final subtitle = isCourier
        ? ((selected as TajGoCourier).online
              ? 'Курьер на линии'
              : 'Курьер offline')
        : '${orderStatusLabel((selected as TajGoOrder).status)} · ${(selected as TajGoOrder).price} TJS';
    return SafeArea(
      top: false,
      child: Card(
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: TajGoColors.muted),
                    ),
                    if (!isCourier)
                      const Text(
                        'Маршрут предварительный',
                        style: TextStyle(
                          color: TajGoColors.warning,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => isCourier
                        ? const AdminCouriersScreen()
                        : AdminOrderDetailsScreen(
                            orderId: (selected as TajGoOrder).id,
                          ),
                  ),
                ),
                child: Text(isCourier ? 'Профиль' : 'Детали'),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
