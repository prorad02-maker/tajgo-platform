import '../../core/services/user_error_message.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/marketplace_cart.dart';
import '../../core/models/marketplace_partner.dart';
import '../../core/models/marketplace_product.dart';
import '../../core/utils/money_formatter.dart';
import '../../shared/widgets/tajgo_state_view.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../customer/order_tracking_screen.dart';
import '../map/models/place_suggestion.dart';
import '../map/models/tajgo_route.dart';
import '../map/models/tajgo_map_location.dart';
import '../map/services/place_search_service.dart';
import '../map/widgets/tajgo_location_widgets.dart';
import '../map/widgets/place_search_sheet.dart';
import '../map/widgets/tajgo_route_summary_card.dart';
import '../map/widgets/address_details_dialog.dart';

class MarketplaceDeliverySelection {
  const MarketplaceDeliverySelection({
    required this.destination,
    required this.distanceKm,
    required this.etaMinutes,
  });

  final TajGoMapLocation destination;
  GeoPoint get location => destination.toGeoPoint();
  String get address => destination.address;
  final double distanceKm;
  final int etaMinutes;
}

class MarketplaceCheckoutScreen extends StatefulWidget {
  const MarketplaceCheckoutScreen({super.key, this.cart});
  final MarketplaceCart? cart;

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
    if (_busy) return;
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
            'Добавьте товаров ещё на ${formatMoney(quote.missingForMinimum)} TJS.',
          ),
        ),
      );
      return;
    }
    final submittedLines = List.of(cart.lines);
    final comment = _comment.text;
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
        cartLines: submittedLines,
        deliveryLocation: delivery.location,
        deliveryAddress: delivery.address,
        distanceKm: delivery.distanceKm,
        etaMinutes: delivery.etaMinutes,
        comment: comment,
      );
      if (cart.partner?.id == partner.id &&
          cart.lines.length == submittedLines.length &&
          cart.lines.every(
            (line) => submittedLines.any(
              (submitted) =>
                  submitted.product.id == line.product.id &&
                  submitted.quantity == line.quantity,
            ),
          )) {
        cart.clear();
      }
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
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart ?? TajGoScope.of(context).marketplaceCart;
    return AnimatedBuilder(
      animation: cart,
      builder: (context, _) {
        final partner = cart.partner;
        return Scaffold(
          appBar: AppBar(title: const Text('Корзина и доставка')),
          body: partner == null || cart.isEmpty
              ? const TajGoStateView(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Корзина пока пуста',
                  message: 'Выберите заведение и добавьте товары из каталога.',
                )
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
                      (line) => _CartLineTile(
                        line: line,
                        cart: cart,
                        enabled: !_busy,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _TotalsCard(cart: cart, partner: partner),
                    if (partner.isPreview) ...[
                      const SizedBox(height: 10),
                      const Card(
                        color: Color(0xFFFFF8E1),
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Это демонстрационный ассортимент. '
                            'Оформить заказ у этого заведения пока нельзя.',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
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
                        onTap: _busy ? null : () => _chooseDelivery(partner),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _comment,
                      enabled: !_busy,
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
                    onPressed: _busy || partner.isPreview
                        ? null
                        : () => _submit(cart),
                    child: Text(
                      partner.isPreview
                          ? 'Демонстрационный ассортимент'
                          : _busy
                          ? 'Оформляем…'
                          : 'Оформить · ${formatMoney(cart.total)} TJS',
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.cart,
    required this.enabled,
  });

  final MarketplaceCartLine line;
  final MarketplaceCart cart;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Удалить',
                onPressed: enabled ? () => cart.remove(line.product.id) : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          Text(
            '${formatMoney(line.product.price)} TJS / ${marketplaceUnitLabel(line.product.unit)}',
            style: const TextStyle(color: TajGoColors.muted),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatMoney(line.total)} TJS',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Уменьшить',
                onPressed: enabled
                    ? () => cart.decrement(line.product.id)
                    : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Semantics(
                label: 'Количество',
                child: Text(_quantity(line.quantity)),
              ),
              IconButton(
                tooltip: 'Добавить',
                onPressed:
                    enabled && line.quantity + line.product.quantityStep <= 100
                    ? () => cart.increment(line.product.id)
                    : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
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
                  'Добавьте товаров ещё на ${formatMoney(quote.missingForMinimum)} TJS.',
                  style: const TextStyle(
                    color: TajGoColors.ink,
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
        '${formatMoney(value)} TJS',
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
  LatLng? _currentPosition;
  Timer? _moveDebounce;
  LatLng? _selectedPoint;
  bool _overview = false;

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

  @override
  void dispose() {
    _moveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    final initialRequest = _requestId;
    final position = await TajGoScope.of(
      context,
    ).locationService.currentPositionIfAuthorized();
    if (!mounted || initialRequest != _requestId) return;
    final point = position == null
        ? LatLng(_pickup.latitude + 0.008, _pickup.longitude + 0.006)
        : LatLng(position.latitude, position.longitude);
    _currentPosition = position == null ? null : point;
    _map.move(point, 15);
    await _refresh(fitRoute: true);
  }

  Future<void> _locate() async {
    if (_locating) return;
    final selectionVersion = _requestId;
    setState(() => _locating = true);
    try {
      final position = await TajGoScope.of(
        context,
      ).locationService.determineCurrentPosition();
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _currentPosition = point);
      if (selectionVersion != _requestId) return;
      _map.move(point, 16);
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

  void _scheduleRefresh() {
    _moveDebounce?.cancel();
    _requestId++;
    setState(() {
      _loading = true;
      _overview = false;
      _route = null;
    });
    _moveDebounce = Timer(const Duration(milliseconds: 450), _refresh);
  }

  Future<void> _searchAddress() async {
    final selected = await showPlaceSearchSheet(
      context: context,
      service: _places,
      title: 'Найти адрес доставки',
      near: _map.camera.center,
      recentType: 'marketplaceDelivery',
    );
    if (selected == null || !mounted) return;
    _map.move(selected.point, 16);
    await _refresh(selected: selected);
  }

  Future<void> _refresh({
    bool fitRoute = false,
    PlaceSuggestion? selected,
  }) async {
    _moveDebounce?.cancel();
    final request = ++_requestId;
    final point = _map.camera.center;
    setState(() {
      _loading = true;
      _overview = false;
      _route = null;
      _address = 'Определяем адрес…';
    });
    final results = await Future.wait([
      selected == null ? _places.reverse(point) : Future.value(selected),
      TajGoScope.of(context).routeService.buildRoute(
        from: _pickup,
        to: point,
        mode: RouteMode.bicycle,
      ),
    ]);
    if (!mounted || request != _requestId) return;
    final place = results[0] as PlaceSuggestion;
    final route = results[1] as TajGoRoute;
    setState(() {
      _address = place.address;
      _selectedPoint = point;
      _route = route;
      _loading = false;
    });
    if (fitRoute && route.points.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || request != _requestId) return;
        setState(() => _overview = true);
        _map.fitCamera(
          CameraFit.coordinates(
            coordinates: route.points,
            padding: const EdgeInsets.fromLTRB(44, 90, 44, 280),
          ),
        );
      });
    }
  }

  void _showEntireRoute() {
    final points = _route?.points;
    if (points == null || points.length < 2) return;
    setState(() => _overview = true);
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(44, 90, 44, 280),
      ),
    );
  }

  Future<bool> _editAddress({bool needsAddress = false}) async {
    if (_loading || _selectedPoint == null) return false;
    final request = _requestId;
    final label = await showAddressDetailsDialog(
      context: context,
      initialAddress: _address,
      needsAddress: needsAddress,
    );
    if (!mounted || label == null || request != _requestId) return false;
    setState(() => _address = label);
    return true;
  }

  Future<void> _confirm() async {
    final route = _route;
    if (route == null || _loading || _selectedPoint == null) return;
    if (_address == 'Точка на карте' &&
        !await _editAddress(needsAddress: true)) {
      return;
    }
    if (!mounted || _loading || _selectedPoint == null) return;
    final point = _selectedPoint!;
    Navigator.pop(
      context,
      MarketplaceDeliverySelection(
        destination: TajGoMapLocation(
          latitude: point.latitude,
          longitude: point.longitude,
          address: _address,
        ),
        distanceKm: route.distanceKm,
        etaMinutes: route.etaMinutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Куда доставить?'),
      actions: [
        IconButton(
          onPressed: _searchAddress,
          tooltip: 'Найти адрес',
          icon: const Icon(Icons.search_rounded),
        ),
      ],
    ),
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
                if (event.source == MapEventSource.fitCamera ||
                    event.source == MapEventSource.mapController ||
                    event.source == MapEventSource.nonRotatedSizeChange) {
                  return;
                }
                if (event is MapEventMoveStart ||
                    event is MapEventFlingAnimationStart ||
                    event is MapEventDoubleTapZoomStart) {
                  _requestId++;
                  _moveDebounce?.cancel();
                  setState(() {
                    _loading = true;
                    _overview = false;
                    _route = null;
                  });
                }
                if (event is MapEventMoveEnd ||
                    event is MapEventFlingAnimationEnd ||
                    event is MapEventDoubleTapZoomEnd ||
                    event is MapEventScrollWheelZoom) {
                  _scheduleRefresh();
                }
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
                  if (_overview && _selectedPoint != null)
                    Marker(
                      point: _selectedPoint!,
                      width: 44,
                      height: 44,
                      child: const _MapPoint(label: 'B'),
                    ),
                  Marker(
                    point: _pickup,
                    width: 44,
                    height: 44,
                    child: const _MapPoint(label: 'A'),
                  ),
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 44,
                      height: 44,
                      child: const TajGoCurrentLocationMarker(),
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
        if (!_overview)
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
          bottom: 240,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Уточнить адрес',
                          onPressed: _loading ? null : _editAddress,
                          icon: const Icon(Icons.edit_location_alt_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TajGoRouteSummaryCard(
                      route: _route,
                      loading: _loading,
                      onShowEntireRoute: _showEntireRoute,
                    ),
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
