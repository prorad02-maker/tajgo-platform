import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_courier.dart';
import '../../core/models/courier_offer.dart';
import '../../core/models/tajgo_order.dart';
import '../../core/services/pricing.dart' as pricing;
import '../../shared/widgets/tajgo_action_button.dart';
import '../../shared/widgets/tajgo_confirmation_code.dart';
import '../../shared/widgets/tajgo_courier_banner.dart';
import '../../shared/widgets/tajgo_order_progress.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../../shared/widgets/tajgo_status_header.dart';
import '../map/services/tajgo_map_camera.dart';
import '../map/models/tajgo_route.dart';
import '../map/widgets/tajgo_location_widgets.dart';
import '../map/widgets/tajgo_map_action_buttons.dart';
import '../map/widgets/tajgo_route_summary_card.dart';

/// Экран отслеживания заказа клиентом: карта с точками A/B, живой маркер
/// курьера и статусная панель со всеми шагами доставки.
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  static const _khujand = LatLng(40.2833, 69.6222);
  final _mapController = MapController();
  final _camera = TajGoMapCamera();
  LatLng? _currentPosition;
  bool _fitted = false;
  bool _busy = false;
  bool _locating = false;
  bool _showBanner = false;
  bool _popScheduled = false;
  OrderStatus? _lastStatus;
  Timer? _bannerTimer;
  Timer? _completedTimer;
  TajGoRoute? _route;
  String? _routeKey;
  bool _routeLoading = false;
  TajGoRoute? _liveRoute;
  String? _liveRouteKey;

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
        controller: _mapController,
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

  @override
  void dispose() {
    _camera.stop();
    _bannerTimer?.cancel();
    _completedTimer?.cancel();
    super.dispose();
  }

  void _onOrderUpdate(TajGoOrder order) {
    if (!mounted || _lastStatus == order.status) {
      return;
    }
    final previous = _lastStatus;
    _lastStatus = order.status;
    if (order.status == OrderStatus.accepted &&
        previous == OrderStatus.waiting) {
      setState(() => _showBanner = true);
      _bannerTimer?.cancel();
      _bannerTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showBanner = false);
        }
      });
    }
    if ((order.status == OrderStatus.completed ||
            order.status == OrderStatus.cancelled) &&
        !_popScheduled) {
      _popScheduled = true;
      final delay = order.status == OrderStatus.completed
          ? const Duration(seconds: 3)
          : Duration.zero;
      _completedTimer = Timer(delay, () {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reportNotReceived(TajGoOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Вы уверены?'),
        content: const Text(
          'Сообщить, что заказ не был получен? Мы проверим доставку.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Не получил'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(
        () =>
            TajGoScope.of(context).orderRepository.reportNotReceived(order.id),
      );
    }
  }

  void _fitMap(LatLng? from, LatLng? to) {
    if (_fitted || from == null || to == null) {
      return;
    }
    _fitted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: [from, to],
            padding: const EdgeInsets.fromLTRB(50, 70, 50, 50),
          ),
        );
      }
    });
  }

  void _ensureRoute(LatLng from, LatLng to) {
    final key =
        '${from.latitude},${from.longitude}:${to.latitude},${to.longitude}';
    if (_routeKey == key) return;
    _routeKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _routeLoading = true);
      final route = await TajGoScope.of(
        context,
      ).routeService.buildRoute(from: from, to: to, mode: RouteMode.bicycle);
      if (mounted && _routeKey == key) {
        setState(() {
          _route = route;
          _routeLoading = false;
        });
      }
    });
  }

  void _showEntireRoute(LatLng? from, LatLng? to) {
    final points = _route?.points ?? <LatLng>[?from, ?to];
    if (points.length < 2) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(50, 80, 50, 50),
      ),
    );
  }

  void _ensureLiveRoute(LatLng? courier, LatLng? target) {
    if (courier == null || target == null) return;
    final key =
        '${courier.latitude.toStringAsFixed(3)},${courier.longitude.toStringAsFixed(3)}:'
        '${target.latitude.toStringAsFixed(4)},${target.longitude.toStringAsFixed(4)}';
    if (_liveRouteKey == key) return;
    _liveRouteKey = key;
    _liveRoute = null;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final route = await TajGoScope.of(context).routeService.buildRoute(
        from: courier,
        to: target,
        mode: RouteMode.bicycle,
      );
      if (mounted && _liveRouteKey == key) {
        setState(() => _liveRoute = route);
      }
    });
  }

  int _step(TajGoOrder order) => switch (order.status) {
    OrderStatus.waiting => 0,
    OrderStatus.accepted => 1,
    OrderStatus.pickedUp => 2,
    _ => 3,
  };

  String _title(TajGoOrder order, {required bool courierNearby}) =>
      switch (order.status) {
        OrderStatus.waiting => '🔎 Ищем курьера…',
        OrderStatus.accepted when order.arrivedAtPickupAt != null =>
          '📍 Курьер забирает заказ',
        OrderStatus.accepted => '🚴 Курьер едет за заказом',
        OrderStatus.pickedUp when courierNearby => '📍 Курьер рядом',
        OrderStatus.pickedUp => '📦 Заказ у курьера',
        OrderStatus.delivered => 'Курьер передал заказ?',
        OrderStatus.completed => '✅ Доставлено. Спасибо!',
        OrderStatus.disputed => '⚠️ Мы разбираемся',
        OrderStatus.cancelled => 'Заказ отменён',
      };

  String? _subtitle(TajGoOrder order, {required bool courierNearby}) =>
      switch (order.status) {
        OrderStatus.waiting => 'Обычно это занимает пару минут',
        OrderStatus.accepted when order.arrivedAtPickupAt != null =>
          'Курьер забирает заказ',
        OrderStatus.accepted when order.arrivedAtPickupAt == null =>
          'Курьер едет за заказом',
        OrderStatus.pickedUp when courierNearby => 'Курьер уже близко к вам',
        OrderStatus.pickedUp => 'Курьер едет к вам',
        OrderStatus.delivered => 'Подтвердите получение',
        OrderStatus.disputed =>
          'Заказ помечен как неполученный. Мы свяжемся с вами.',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    return Scaffold(
      body: StreamBuilder<TajGoOrder?>(
        stream: scope.orderRepository.orderStream(widget.orderId),
        builder: (context, snapshot) {
          final order = snapshot.data;
          if (order == null) {
            return const Center(child: CircularProgressIndicator());
          }
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _onOrderUpdate(order),
          );
          final courierVisible =
              order.courierId != null &&
              const {
                OrderStatus.accepted,
                OrderStatus.pickedUp,
                OrderStatus.delivered,
              }.contains(order.status);
          if (!courierVisible) {
            return _buildBody(order, null);
          }
          return StreamBuilder<TajGoCourier?>(
            stream: scope.courierRepository.publicCourierStream(
              order.courierId!,
            ),
            builder: (context, courierSnapshot) =>
                _buildBody(order, courierSnapshot.data),
          );
        },
      ),
    );
  }

  Widget _buildBody(TajGoOrder order, TajGoCourier? courier) {
    final from = order.fromLocation == null
        ? null
        : LatLng(order.fromLocation!.latitude, order.fromLocation!.longitude);
    final to = order.toLocation == null
        ? null
        : LatLng(order.toLocation!.latitude, order.toLocation!.longitude);
    if (from != null && to != null) _ensureRoute(from, to);
    final courierPoint = courier?.location == null
        ? null
        : LatLng(courier!.location!.latitude, courier.location!.longitude);
    final liveTarget = order.status == OrderStatus.accepted ? from : to;
    final liveDistance = courierPoint != null && liveTarget != null
        ? pricing.haversineDistanceKm(courierPoint, liveTarget)
        : null;
    _ensureLiveRoute(courierPoint, liveTarget);
    final liveEta = courierPoint == null
        ? null
        : _liveRoute?.etaMinutes ??
              (liveDistance == null
                  ? null
                  : pricing.courierNavigationEtaMinutes(liveDistance));
    final courierNearby = liveDistance != null && liveDistance <= 0.12;
    _fitMap(from, to);
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: from ?? to ?? _khujand,
                  initialZoom: 13,
                  minZoom: 3,
                  maxZoom: 19,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'tj.tajgo.app',
                    maxZoom: 19,
                  ),
                  if (from != null && to != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _route?.points ?? [from, to],
                          color: _route?.routeQuality == RouteQuality.road
                              ? TajGoColors.green
                              : TajGoColors.warning,
                          strokeWidth: _route?.routeQuality == RouteQuality.road
                              ? 4
                              : 3,
                          pattern: _route?.routeQuality == RouteQuality.road
                              ? const StrokePattern.solid()
                              : StrokePattern.dashed(segments: const [8, 8]),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (from != null)
                        Marker(
                          point: from,
                          width: 48,
                          height: 48,
                          child: const _AddressPin(
                            label: 'A',
                            color: TajGoColors.darkGreen,
                          ),
                        ),
                      if (to != null)
                        Marker(
                          point: to,
                          width: 48,
                          height: 48,
                          child: const _AddressPin(
                            label: 'B',
                            color: Colors.blue,
                          ),
                        ),
                      if (courierPoint != null)
                        Marker(
                          point: courierPoint,
                          width: 22,
                          height: 22,
                          child: const _CourierDot(),
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
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 5,
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                ),
              ),
              if (_showBanner && courier != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TajGoCourierBanner(
                          name: courier.name,
                          rating: courier.rating,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                bottom: 12,
                child: TajGoMapActionButtons(
                  heroPrefix: 'tracking',
                  locating: _locating,
                  onLocate: _locate,
                  onShowRoute: from == null || to == null
                      ? null
                      : () => _showEntireRoute(from, to),
                ),
              ),
            ],
          ),
        ),
        _StatusPanel(
          order: order,
          courier: courier,
          busy: _busy,
          onCancel: () => _run(
            () => TajGoScope.of(context).orderRepository.cancelOrder(order.id),
          ),
          onConfirm: () => _run(
            () => TajGoScope.of(
              context,
            ).orderRepository.confirmReceived(order.id),
          ),
          onNotReceived: () => _reportNotReceived(order),
          onDone: () => Navigator.maybePop(context),
          step: _step(order),
          title: _title(order, courierNearby: courierNearby),
          subtitle: _subtitle(order, courierNearby: courierNearby),
          route: _route,
          routeLoading: _routeLoading,
          liveEtaMinutes: liveEta,
          courierNearby: courierNearby,
          onShowRoute: from == null || to == null
              ? null
              : () => _showEntireRoute(from, to),
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.order,
    required this.courier,
    required this.busy,
    required this.onCancel,
    required this.onConfirm,
    required this.onNotReceived,
    required this.onDone,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.routeLoading,
    required this.liveEtaMinutes,
    required this.courierNearby,
    required this.onShowRoute,
  });

  final TajGoOrder order;
  final TajGoCourier? courier;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final VoidCallback onNotReceived;
  final VoidCallback onDone;
  final int step;
  final String title;
  final String? subtitle;
  final TajGoRoute? route;
  final bool routeLoading;
  final int? liveEtaMinutes;
  final bool courierNearby;
  final VoidCallback? onShowRoute;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    child: SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TajGoOrderProgress(
                currentStep: step,
                labels: const ['Поиск', 'Принят', 'Забрал', 'Доставлено'],
              ),
              const SizedBox(height: 14),
              TajGoStatusHeader(title: title, subtitle: subtitle),
              if (courierNearby) ...[
                const SizedBox(height: 4),
                const Text(
                  'Курьер рядом',
                  style: TextStyle(
                    color: TajGoColors.darkGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ] else if (liveEtaMinutes != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Осталось примерно $liveEtaMinutes мин',
                  style: const TextStyle(
                    color: TajGoColors.darkGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (courier != null &&
                  order.status != OrderStatus.completed &&
                  order.status != OrderStatus.disputed) ...[
                const SizedBox(height: 8),
                Text(
                  '🚴 ${courier!.name} · ⭐ ${courier!.rating}',
                  style: const TextStyle(color: TajGoColors.muted),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                '${order.fromText} → ${order.toText}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                [
                  '${order.price} ${order.currency}',
                  if (order.distanceKm != null) '${order.distanceKm} км',
                  if (order.etaMinutes != null) '~${order.etaMinutes} мин',
                ].join(' · '),
                style: const TextStyle(color: TajGoColors.muted, fontSize: 13),
              ),
              if (order.fromLocation != null && order.toLocation != null) ...[
                const SizedBox(height: 8),
                TajGoRouteSummaryCard(
                  route: route,
                  loading: routeLoading,
                  onShowEntireRoute: onShowRoute,
                  compact: true,
                ),
              ],
              if ((order.comment ?? '').isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  '💬 ${order.comment}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TajGoColors.muted,
                    fontSize: 13,
                  ),
                ),
              ],
              if (order.status == OrderStatus.waiting) ...[
                const SizedBox(height: 12),
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(99)),
                  child: SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      color: TajGoColors.green,
                      backgroundColor: Color(0xFFDFEDD8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _OffersSection(order: order, onShowMap: onShowRoute),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: busy ? null : onCancel,
                    child: const Text('Отменить заказ'),
                  ),
                ),
              ],
              if (order.status == OrderStatus.pickedUp &&
                  order.confirmationCode != null) ...[
                const SizedBox(height: 14),
                TajGoConfirmationCode(code: order.confirmationCode!),
              ],
              if (order.status == OrderStatus.delivered) ...[
                const SizedBox(height: 14),
                TajGoActionButton(
                  label: '✅ Получил',
                  busy: busy,
                  onPressed: onConfirm,
                ),
                Center(
                  child: TextButton(
                    onPressed: busy ? null : onNotReceived,
                    child: const Text(
                      'Не получил',
                      style: TextStyle(color: TajGoColors.error),
                    ),
                  ),
                ),
              ],
              if (order.status == OrderStatus.completed) ...[
                const SizedBox(height: 14),
                TajGoActionButton(label: 'На главную', onPressed: onDone),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _OffersSection extends StatelessWidget {
  const _OffersSection({required this.order, required this.onShowMap});

  final TajGoOrder order;
  final VoidCallback? onShowMap;

  Future<void> _select(BuildContext context, CourierOffer offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выбрать курьера?'),
        content: Text(
          '${offer.courierName} доставит заказ за ${offer.proposedPrice} TJS. После выбора заказ будет закреплён за этим курьером.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Выбрать курьера'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final scope = TajGoScope.of(context);
    try {
      await scope.courierOfferRepository.selectCourierOffer(
        orderId: order.id,
        offerId: offer.id,
        customerId: scope.authService.currentUser!.uid,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _reject(BuildContext context, CourierOffer offer) async {
    final scope = TajGoScope.of(context);
    try {
      await scope.courierOfferRepository.rejectCourierOffer(
        orderId: order.id,
        offerId: offer.id,
        customerId: scope.authService.currentUser!.uid,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<CourierOffer>>(
    stream: TajGoScope.of(
      context,
    ).courierOfferRepository.offersStream(order.id),
    builder: (context, snapshot) {
      final offers = (snapshot.data ?? const <CourierOffer>[])
          .where((offer) => offer.isActive)
          .toList(growable: false);
      if (offers.isEmpty) {
        return const Text(
          'Ждём предложения курьеров',
          style: TextStyle(
            color: TajGoColors.darkGreen,
            fontWeight: FontWeight.w800,
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Предложения · ${offers.length}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          ...offers.map(
            (offer) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: TajGoColors.mint,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${offer.courierName} · ⭐ ${offer.courierRating.toStringAsFixed(1)}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '${offer.proposedPrice} TJS',
                          style: const TextStyle(
                            color: TajGoColors.darkGreen,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${offer.courierTransport} · ${offer.courierDistanceMeters.round()} м до A · ~${(offer.courierDistanceMeters / 300).ceil().clamp(1, 99)} мин',
                      style: const TextStyle(color: TajGoColors.muted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: onShowMap,
                          child: const Text('На карте'),
                        ),
                        TextButton(
                          onPressed: () => _reject(context, offer),
                          child: const Text('Отклонить'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => _select(context, offer),
                          child: const Text('Выбрать'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _AddressPin extends StatelessWidget {
  const _AddressPin({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Icon(Icons.location_pin, size: 48, color: color),
      Positioned(
        top: 9,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}

class _CourierDot extends StatelessWidget {
  const _CourierDot();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: TajGoColors.green,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
    ),
  );
}
