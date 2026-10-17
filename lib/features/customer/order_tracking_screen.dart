import '../../core/design/tajgo_money.dart';
import '../../shared/widgets/tajgo_map_attribution.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/config/map_provider_config.dart';
import '../../core/models/tajgo_courier.dart';
import '../../core/models/courier_offer.dart';
import '../../core/models/tajgo_order.dart';
import '../../core/services/pricing.dart' as pricing;
import '../../shared/delivery/delivery_widgets.dart';
import '../../shared/widgets/tajgo_confirmation_code.dart';
import '../../shared/widgets/tajgo_courier_banner.dart';
import '../../shared/widgets/tajgo_order_progress.dart';
import '../../shared/widgets/order_details_load_state.dart';
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
  int _orderStreamAttempt = 0;

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
      try {
        final route = await TajGoScope.of(
          context,
        ).routeService.buildRoute(from: from, to: to, mode: RouteMode.bicycle);
        if (mounted && _routeKey == key) setState(() => _route = route);
      } catch (_) {
        if (mounted && _routeKey == key) setState(() => _route = null);
      } finally {
        if (mounted && _routeKey == key) setState(() => _routeLoading = false);
      }
    });
  }

  void _showEntireRoute(LatLng? from, LatLng? to) {
    final points = <LatLng>{
      ...?_route?.points,
      ...?_liveRoute?.points,
      ?from,
      ?to,
    }.toList(growable: false);
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
      try {
        final route = await TajGoScope.of(context).routeService.buildRoute(
          from: courier,
          to: target,
          mode: RouteMode.bicycle,
        );
        if (mounted && _liveRouteKey == key) {
          setState(() => _liveRoute = route);
        }
      } catch (_) {
        if (mounted && _liveRouteKey == key) setState(() => _liveRoute = null);
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
        OrderStatus.unknown => 'Статус заказа недоступен',
        OrderStatus.waiting => 'Ищем курьера',
        OrderStatus.accepted when order.arrivedAtPickupAt != null =>
          'Курьер забирает заказ',
        OrderStatus.accepted => 'Курьер едет за заказом',
        OrderStatus.pickedUp when courierNearby => 'Курьер рядом',
        OrderStatus.pickedUp => 'Заказ у курьера',
        OrderStatus.delivered => 'Курьер передал заказ?',
        OrderStatus.completed => 'Доставлено. Спасибо!',
        OrderStatus.disputed => 'Проверяем доставку',
        OrderStatus.cancelled => 'Заказ отменён',
      };

  String? _subtitle(TajGoOrder order, {required bool courierNearby}) =>
      switch (order.status) {
        OrderStatus.waiting =>
          'Покажем предложения, как только курьеры откликнутся',
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
        key: ValueKey('customer-order-${widget.orderId}-$_orderStreamAttempt'),
        stream: scope.orderRepository.orderStream(widget.orderId),
        builder: (context, snapshot) {
          final state = resolveOrderDetailsLoadState(snapshot);
          if (state == OrderDetailsLoadState.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state == OrderDetailsLoadState.error ||
              state == OrderDetailsLoadState.notFound) {
            return OrderDetailsTerminalView(
              notFound: state == OrderDetailsLoadState.notFound,
              onRetry: () => setState(() => _orderStreamAttempt++),
              onBack: () => Navigator.of(context).maybePop(),
            );
          }
          final order = snapshot.data!;
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
    final liveEta = courierPoint == null ? null : _liveRoute?.etaMinutes;
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
                    urlTemplate: MapProviderConfig.current.tileUrlTemplate,
                    userAgentPackageName:
                        MapProviderConfig.current.userAgentPackageName,
                    maxZoom: 19,
                  ),
                  if (_route?.routeQuality == RouteQuality.road)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _route!.points,
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
                  if (_liveRoute != null && courierPoint != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _liveRoute!.points,
                          color: Colors.blue,
                          strokeWidth: 5,
                          borderColor: Colors.white,
                          borderStrokeWidth: 2,
                          pattern: _liveRoute!.isFallback
                              ? StrokePattern.dashed(segments: const [9, 7])
                              : const StrokePattern.solid(),
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
                  const TajGoMapAttribution(),
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
        DeliveryTrackingPanel(
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
          liveDistanceKm: liveDistance,
          liveEtaMinutes: liveEta,
          courierLocationUpdatedAt: courier?.locationUpdatedAt,
          courierNearby: courierNearby,
          onShowRoute: from == null || to == null
              ? null
              : () => _showEntireRoute(from, to),
          onRetryRoute: from == null || to == null
              ? null
              : () {
                  setState(() {
                    _routeKey = null;
                    _liveRouteKey = null;
                  });
                  _ensureRoute(from, to);
                },
        ),
      ],
    );
  }
}

class DeliveryTrackingPanel extends StatelessWidget {
  const DeliveryTrackingPanel({
    super.key,
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
    required this.liveDistanceKm,
    required this.liveEtaMinutes,
    required this.courierLocationUpdatedAt,
    required this.courierNearby,
    required this.onShowRoute,
    this.onRetryRoute,
  });
  final TajGoOrder order;
  final TajGoCourier? courier;
  final bool busy;
  final VoidCallback onCancel, onConfirm, onNotReceived, onDone;
  final int step;
  final String title;
  final String? subtitle;
  final TajGoRoute? route;
  final bool routeLoading;
  final double? liveDistanceKm;
  final int? liveEtaMinutes;
  final DateTime? courierLocationUpdatedAt;
  final bool courierNearby;
  final VoidCallback? onShowRoute, onRetryRoute;

  @override
  Widget build(BuildContext context) => DeliverySheet(
    footer: switch (order.status) {
      OrderStatus.waiting => OutlinedButton(
        onPressed: busy ? null : onCancel,
        child: const Text('Отменить заказ'),
      ),
      OrderStatus.delivered => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DeliveryPrimaryAction(
            label: 'Подтвердить получение',
            busy: busy,
            onPressed: onConfirm,
            icon: Icons.check_rounded,
          ),
          TextButton(
            onPressed: busy ? null : onNotReceived,
            child: const Text(
              'Не получил',
              style: TextStyle(color: TajGoColors.error),
            ),
          ),
        ],
      ),
      OrderStatus.completed => DeliveryPrimaryAction(
        label: 'На главную',
        onPressed: onDone,
        icon: Icons.check_rounded,
      ),
      _ => null,
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TajGoOrderProgress(
          currentStep: step,
          labels: const ['Поиск', 'Принят', 'Забрал', 'Доставлено'],
        ),
        const SizedBox(height: 16),
        TajGoStatusHeader(title: title, subtitle: subtitle),
        if (courierNearby || liveEtaMinutes != null) ...[
          const SizedBox(height: 12),
          DeliveryPill(
            icon: Icons.schedule_rounded,
            label: courierNearby
                ? 'Курьер рядом'
                : 'До цели ${_liveDistanceLabel(liveDistanceKm)} · ≈ $liveEtaMinutes мин',
          ),
        ],
        if (courier != null && courierLocationUpdatedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _gpsFreshness(courierLocationUpdatedAt!),
              style: TextStyle(
                color:
                    DateTime.now().difference(courierLocationUpdatedAt!) >
                        const Duration(minutes: 2)
                    ? const Color(0xFF805C13)
                    : TajGoColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (courier != null &&
            order.status != OrderStatus.completed &&
            order.status != OrderStatus.disputed) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: TajGoColors.mint,
                foregroundColor: TajGoColors.deepGreen,
                child: Icon(Icons.delivery_dining_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courier!.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Ваш курьер · рейтинг ${courier!.rating}',
                      style: const TextStyle(
                        color: TajGoColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        DeliveryRouteStops(
          from: order.fromText,
          to: order.toText,
          maxLines: null,
        ),
        const SizedBox(height: 16),
        const Text(
          'Стоимость доставки',
          style: TextStyle(color: TajGoColors.muted, fontSize: 12),
        ),
        Text(
          TajGoMoney.format(order.effectivePrice),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: TajGoColors.deepGreen,
          ),
        ),
        if (order.orderType == 'catalogOrder' && order.items.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CatalogOrderSummary(order: order),
        ],
        if (order.fromLocation != null && order.toLocation != null) ...[
          const SizedBox(height: 12),
          TajGoRouteSummaryCard(
            route: route,
            loading: routeLoading,
            onRetry: onRetryRoute,
            onShowEntireRoute: onShowRoute,
            compact: true,
          ),
        ],
        if ((order.comment ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              order.comment!,
              style: const TextStyle(
                color: TajGoColors.muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        if (order.status == OrderStatus.waiting) ...[
          const SizedBox(height: 16),
          _OffersSection(order: order, onShowMap: onShowRoute),
        ],
        if (order.status == OrderStatus.pickedUp) ...[
          const SizedBox(height: 16),
          StreamBuilder<String?>(
            stream: TajGoScope.of(context).orderRepository
                .customerDeliveryCodeStream(
                  order.id,
                  serverV1: order.commandVersion == 'server-v1',
                ),
            builder: (context, snapshot) {
              final code = snapshot.data ?? order.confirmationCode;
              if (code == null) {
                return const Text(
                  'Код недоступен. Проверьте интернет и обновите экран.',
                  style: TextStyle(color: TajGoColors.muted),
                );
              }
              return TajGoConfirmationCode(code: code);
            },
          ),
        ],
      ],
    ),
  );
}

class _CatalogOrderSummary extends StatelessWidget {
  const _CatalogOrderSummary({required this.order});

  final TajGoOrder order;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: TajGoColors.mint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.partnerName ?? 'Заказ у партнёра',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        for (final item in order.items.take(3))
          Text(
            '${item.name} × ${_catalogQuantity(item.quantity)} · '
            '${TajGoMoney.format(item.lineTotal)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        if (order.items.length > 3)
          Text(
            'Ещё позиций: ${order.items.length - 3}',
            style: const TextStyle(fontSize: 13, color: TajGoColors.muted),
          ),
        const SizedBox(height: 5),
        Text(
          'Товары ${order.subtotal ?? 0} + доставка '
          '${order.deliveryFee ?? order.price} = ${TajGoMoney.format(order.total ?? 0)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

String _catalogQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

String _liveDistanceLabel(double? distanceKm) {
  if (distanceKm == null) return '—';
  if (distanceKm < 1) {
    return '${(distanceKm * 1000).round()} м';
  }
  return '${distanceKm.toStringAsFixed(1)} км';
}

String _gpsFreshness(DateTime updatedAt) {
  final age = DateTime.now().difference(updatedAt);
  if (age < const Duration(seconds: 45)) {
    return 'GPS курьера обновлён сейчас';
  }
  if (age < const Duration(minutes: 2)) {
    return 'GPS курьера обновлён минуту назад';
  }
  return 'Позиция курьера временно не обновляется';
}

class _OffersSection extends StatefulWidget {
  const _OffersSection({required this.order, required this.onShowMap});

  final TajGoOrder order;
  final VoidCallback? onShowMap;

  @override
  State<_OffersSection> createState() => _OffersSectionState();
}

class _OffersSectionState extends State<_OffersSection> {
  Stream<List<CourierOffer>>? _offers;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _offers ??= TajGoScope.of(
      context,
    ).courierOfferRepository.offersStream(widget.order.id);
  }

  @override
  void didUpdateWidget(covariant _OffersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id) {
      _offers = TajGoScope.of(
        context,
      ).courierOfferRepository.offersStream(widget.order.id);
    }
  }

  Future<void> _select(BuildContext context, CourierOffer offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выбрать курьера?'),
        content: Text(
          '${offer.courierName} доставит заказ за ${TajGoMoney.format(offer.proposedPrice)}. После выбора заказ будет закреплён за этим курьером.',
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
        orderId: widget.order.id,
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
        orderId: widget.order.id,
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
    stream: _offers,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Не удалось загрузить предложения',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                _offers = TajGoScope.of(
                  context,
                ).courierOfferRepository.offersStream(widget.order.id);
              }),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        );
      }
      final offers = (snapshot.data ?? const <CourierOffer>[])
          .where((offer) => offer.isActive)
          .toList(growable: false);
      if (offers.isEmpty) {
        return Text(
          snapshot.connectionState == ConnectionState.waiting
              ? 'Загружаем предложения…'
              : 'Ждём предложения курьеров',
          style: const TextStyle(
            color: TajGoColors.deepGreen,
            fontWeight: FontWeight.w700,
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Предложения · ${offers.length}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final offer in offers)
            DeliveryCourierOfferCard(
              offer: offer,
              onShowMap: widget.onShowMap,
              onSelect: () => _select(context, offer),
              onReject: () => _reject(context, offer),
            ),
        ],
      );
    },
  );
}

class DeliveryCourierOfferCard extends StatelessWidget {
  const DeliveryCourierOfferCard({
    super.key,
    required this.offer,
    required this.onSelect,
    required this.onReject,
    this.onShowMap,
  });
  final CourierOffer offer;
  final VoidCallback onSelect, onReject;
  final VoidCallback? onShowMap;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F7F4),
      border: Border.all(color: const Color(0xFFDEE8E0)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              foregroundColor: TajGoColors.deepGreen,
              child: Icon(Icons.delivery_dining_rounded),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.courierName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Рейтинг ${offer.courierRating.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: TajGoColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            DeliveryPill(
              label: switch (offer.courierTransport) {
                'bicycle' => 'Велосипед',
                'scooter' => 'Самокат',
                'car' => 'Автомобиль',
                'walking' => 'Пешком',
                _ => offer.courierTransport,
              },
              icon: Icons.delivery_dining_outlined,
            ),
            DeliveryPill(
              label: '${offer.courierDistanceMeters.round()} м до точки A',
              icon: Icons.near_me_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          TajGoMoney.format(offer.proposedPrice),
          style: const TextStyle(
            color: TajGoColors.deepGreen,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        DeliveryPrimaryAction(label: 'Выбрать курьера', onPressed: onSelect),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: onShowMap,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('На карте'),
            ),
            TextButton(onPressed: onReject, child: const Text('Отклонить')),
          ],
        ),
      ],
    ),
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
