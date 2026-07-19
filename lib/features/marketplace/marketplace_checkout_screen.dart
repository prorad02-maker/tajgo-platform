import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/marketplace_cart.dart';
import '../../core/models/marketplace_partner.dart';
import '../../core/models/marketplace_product.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../customer/order_tracking_screen.dart';
import '../map/models/place_suggestion.dart';
import '../map/models/tajgo_route.dart';
import '../map/services/place_search_service.dart';
import '../map/widgets/tajgo_location_widgets.dart';
import '../map/widgets/tajgo_route_summary_card.dart';

class MarketplaceDeliverySelection {
  const MarketplaceDeliverySelection({
    required this.location,
    required this.address,
    required this.distanceKm,
    required this.etaMinutes,
  });

  final GeoPoint location;
  final String address;
  final double distanceKm;
  final int etaMinutes;
}

class MarketplaceCheckoutScreen extends StatefulWidget {
  const MarketplaceCheckoutScreen({super.key});

  @override
  State<MarketplaceCheckoutScreen> createState() =>
      _MarketplaceCheckoutScreenState();
}

class _MarketplaceCheckoutScreenState extends State<MarketplaceCheckoutScreen> {
  final _comment = TextEditingController();
  MarketplaceDeliverySelection? _delivery;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _chooseDelivery(MarketplacePartner partner) async {
    final selected = await Navigator.push<MarketplaceDeliverySelection>(
      context,
      MaterialPageRoute(
        builder: (_) => MarketplaceDeliveryPointScreen(partner: partner),
      ),
    );
    if (selected != null && mounted) setState(() => _delivery = selected);
  }

  Future<void> _submit(MarketplaceCart cart) async {
    final partner = cart.partner;
    final delivery = _delivery;
    if (partner == null || cart.isEmpty) return;
    if (delivery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите адрес доставки на карте.')),
      );
      return;
    }
    final quote = MarketplaceCheckoutQuote(
      subtotal: cart.subtotal,
      deliveryFee: cart.deliveryFee,
      minimumOrder: partner.minimumOrder,
    );
    if (!quote.meetsMinimum) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Добавьте товаров ещё на ${quote.missingForMinimum} TJS.',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final scope = TajGoScope.of(context);
      final uid = scope.authService.currentUser!.uid;
      final user = await scope.userRepository.getUser(uid);
      if (!mounted) return;
      final orderId = await scope.marketplaceRepository.createCatalogOrder(
        customerId: uid,
        customerName: user?.displayName ?? 'Клиент',
        partner: partner,
        cartLines: List.of(cart.lines),
        deliveryLocation: delivery.location,
        deliveryAddress: delivery.address,
        distanceKm: delivery.distanceKm,
        etaMinutes: delivery.etaMinutes,
        comment: _comment.text,
      );
      cart.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OrderTrackingScreen(orderId: orderId),
        ),
        (route) => route.isFirst,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = TajGoScope.of(context).marketplaceCart;
    return AnimatedBuilder(
      animation: cart,
      builder: (context, _) {
        final partner = cart.partner;
        return Scaffold(
          appBar: AppBar(title: const Text('Корзина и доставка')),
          body: partner == null || cart.isEmpty
              ? const Center(child: Text('Корзина пока пуста.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      partner.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...cart.lines.map(
                      (line) => _CartLineTile(line: line, cart: cart),
                    ),
                    const SizedBox(height: 10),
                    _TotalsCard(cart: cart, partner: partner),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.location_on_rounded,
                          color: TajGoColors.green,
                        ),
                        title: Text(
                          _delivery?.address ?? 'Выберите адрес доставки',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: _delivery == null
                            ? const Text('Укажите точку B на карте')
                            : Text(
                                '${_delivery!.distanceKm.toStringAsFixed(1)} км · ≈ ${_delivery!.etaMinutes} мин',
                              ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _chooseDelivery(partner),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _comment,
                      maxLines: 2,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий к заказу',
                        hintText: 'Подъезд, ориентир или пожелание',
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: partner == null || cart.isEmpty
              ? null
              : SafeArea(
                  minimum: const EdgeInsets.all(12),
                  child: FilledButton(
                    onPressed: _busy ? null : () => _submit(cart),
                    child: Text(
                      _busy ? 'Оформляем…' : 'Оформить · ${cart.total} TJS',
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.line, required this.cart});

  final MarketplaceCartLine line;
  final MarketplaceCart cart;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: IconButton(
        tooltip: 'Удалить',
        onPressed: () => cart.remove(line.product.id),
        icon: const Icon(Icons.delete_outline_rounded),
      ),
      title: Text(line.product.name),
      subtitle: Text(
        '${line.product.price} TJS × ${_quantity(line.quantity)} ${marketplaceUnitLabel(line.product.unit)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Уменьшить',
            onPressed: () => cart.decrement(line.product.id),
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          Text('${line.total}'),
          IconButton(
            tooltip: 'Добавить',
            onPressed: () => cart.increment(line.product.id),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    ),
  );
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.cart, required this.partner});

  final MarketplaceCart cart;
  final MarketplacePartner partner;

  @override
  Widget build(BuildContext context) {
    final quote = MarketplaceCheckoutQuote(
      subtotal: cart.subtotal,
      deliveryFee: cart.deliveryFee,
      minimumOrder: partner.minimumOrder,
    );
    return Card(
      color: TajGoColors.mint,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _money('Товары', quote.subtotal),
            _money('Доставка', quote.deliveryFee),
            const Divider(),
            _money('Итого', quote.total, strong: true),
            if (!quote.meetsMinimum)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Добавьте товаров ещё на ${quote.missingForMinimum} TJS.',
                  style: const TextStyle(
                    color: TajGoColors.warning,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _money(String label, num value, {bool strong = false}) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        '$value TJS',
        style: TextStyle(
          fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
    ],
  );
}

class MarketplaceDeliveryPointScreen extends StatefulWidget {
  const MarketplaceDeliveryPointScreen({super.key, required this.partner});

  final MarketplacePartner partner;

  @override
  State<MarketplaceDeliveryPointScreen> createState() =>
      _MarketplaceDeliveryPointScreenState();
}

class _MarketplaceDeliveryPointScreenState
    extends State<MarketplaceDeliveryPointScreen> {
  final _map = MapController();
  late final PlaceSearchService _places;
  TajGoRoute? _route;
  String _address = 'Определяем адрес…';
  bool _loading = true;
  bool _locating = false;
  int _requestId = 0;

  LatLng get _pickup => LatLng(
    widget.partner.location.latitude,
    widget.partner.location.longitude,
  );

  @override
  void initState() {
    super.initState();
    _places = PlaceSearchService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    final position = await TajGoScope.of(
      context,
    ).locationService.currentPositionIfAuthorized();
    if (!mounted) return;
    final point = position == null
        ? LatLng(_pickup.latitude + 0.008, _pickup.longitude + 0.006)
        : LatLng(position.latitude, position.longitude);
    _map.move(point, 15);
    await _refresh();
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await TajGoScope.of(
        context,
      ).locationService.determineCurrentPosition();
      if (!mounted) return;
      _map.move(LatLng(position.latitude, position.longitude), 16);
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось определить геолокацию.')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _refresh() async {
    final request = ++_requestId;
    final point = _map.camera.center;
    setState(() {
      _loading = true;
      _route = null;
      _address = 'Определяем адрес…';
    });
    final results = await Future.wait([
      _places.reverse(point),
      TajGoScope.of(context).routeService.buildRoute(
        from: _pickup,
        to: point,
        mode: RouteMode.bicycle,
      ),
    ]);
    if (!mounted || request != _requestId) return;
    final place = results[0] as PlaceSuggestion;
    setState(() {
      _address = place.address;
      _route = results[1] as TajGoRoute;
      _loading = false;
    });
  }

  void _confirm() {
    final route = _route;
    if (route == null) return;
    final point = _map.camera.center;
    Navigator.pop(
      context,
      MarketplaceDeliverySelection(
        location: GeoPoint(point.latitude, point.longitude),
        address: _address,
        distanceKm: route.distanceKm,
        etaMinutes: route.etaMinutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Куда доставить?')),
    body: Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _pickup,
              initialZoom: 14,
              minZoom: 3,
              maxZoom: 19,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) _refresh();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'tj.tajgo.app',
                maxZoom: 19,
              ),
              if (_route != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route!.points,
                      color: _route!.isFallback
                          ? TajGoColors.warning
                          : TajGoColors.green,
                      strokeWidth: 4,
                      pattern: _route!.isFallback
                          ? StrokePattern.dashed(segments: const [8, 8])
                          : const StrokePattern.solid(),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _pickup,
                    width: 44,
                    height: 44,
                    child: const _MapPoint(label: 'A'),
                  ),
                ],
              ),
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        IgnorePointer(
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: const _MapPoint(label: 'B'),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 190,
          child: TajGoLocateButton(
            heroTag: 'marketplaceDeliveryLocate',
            loading: _locating,
            onPressed: _locating ? null : _locate,
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    TajGoRouteSummaryCard(route: _route, loading: _loading),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _loading ? null : _confirm,
                      child: const Text('Доставить сюда'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _MapPoint extends StatelessWidget {
  const _MapPoint({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.topCenter,
    children: [
      Icon(
        Icons.location_pin,
        size: 44,
        color: label == 'A' ? TajGoColors.darkGreen : TajGoColors.lime,
      ),
      Positioned(
        top: 7,
        child: Text(
          label,
          style: TextStyle(
            color: label == 'A' ? Colors.white : TajGoColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}

String _quantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
