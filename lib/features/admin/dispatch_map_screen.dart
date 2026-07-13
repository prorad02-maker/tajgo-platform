import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_courier.dart';
import '../../core/models/tajgo_order.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'admin_couriers_screen.dart';
import 'admin_order_details_screen.dart';
import 'admin_orders_screen.dart';
import 'widgets/admin_access_gate.dart';

class DispatchMapScreen extends StatefulWidget {
  const DispatchMapScreen({super.key, this.focusCourierId});
  final String? focusCourierId;

  @override
  State<DispatchMapScreen> createState() => _DispatchMapScreenState();
}

class _DispatchMapScreenState extends State<DispatchMapScreen> {
  static const _khujand = LatLng(40.2833, 69.6222);
  final _map = MapController();
  Object? _selected;
  bool _focused = false;

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
                  _map.move(
                    LatLng(
                      focused.location!.latitude,
                      focused.location!.longitude,
                    ),
                    16,
                  );
                  setState(() => _selected = focused);
                });
              }
            }
            final routeLines = <Polyline>[];
            for (final order in orders) {
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
                        ...online.map(
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
                        ...orders.expand((order) sync* {
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
                                  color: TajGoColors.lime,
                                  size: 40,
                                ),
                              ),
                            );
                          }
                        }),
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
                              '🛵 ${online.length} на линии · 📦 ${orders.length} активных',
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
