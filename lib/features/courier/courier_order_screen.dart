import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_order.dart';
import '../../core/services/pricing.dart' as pricing;
import '../../shared/widgets/tajgo_action_button.dart';
import '../../shared/widgets/tajgo_order_progress.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../map/services/tajgo_location_service.dart';
import '../map/services/tajgo_map_camera.dart';
import '../map/widgets/tajgo_location_widgets.dart';

class CourierOrderScreen extends StatefulWidget {
  const CourierOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<CourierOrderScreen> createState() => _CourierOrderScreenState();
}

class _CourierOrderScreenState extends State<CourierOrderScreen>
    with WidgetsBindingObserver {
  static const _khujand = LatLng(40.2833, 69.6222);
  final _mapController = MapController();
  final _camera = TajGoMapCamera();
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _position;
  double? _heading;
  double? _accuracy;
  bool _followCourier = true;
  bool _locationStarting = false;
  bool _busy = false;
  bool _fitted = false;
  OrderStatus? _lastNavigationStatus;
  TajGoLocationException? _locationIssue;
  String? _geoError;

  String get _uid => TajGoScope.of(context).authService.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLocation());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _positionSubscription == null) {
      _startLocation();
    }
  }

  Future<void> _startLocation() async {
    if (_locationStarting || _positionSubscription != null) {
      return;
    }
    setState(() {
      _locationStarting = true;
      _geoError = null;
    });
    try {
      final service = TajGoScope.of(context).locationService;
      final initial = await service.determineCurrentPosition();
      if (!mounted) {
        return;
      }
      setState(() {
        _position = LatLng(initial.latitude, initial.longitude);
        _heading = initial.heading;
        _accuracy = initial.accuracy;
        _locationIssue = null;
        _geoError = null;
      });
      await _publishPosition(initial, force: true);
      _positionSubscription = service.positionStream().listen(
        (position) async {
          if (mounted) {
            setState(() {
              _position = LatLng(position.latitude, position.longitude);
              _heading = position.heading;
              _accuracy = position.accuracy;
              _locationIssue = null;
              _geoError = null;
            });
            if (_followCourier) {
              unawaited(
                _camera.animateTo(
                  controller: _mapController,
                  target: _position!,
                  zoom: TajGoMapCamera.navigationZoom,
                  duration: const Duration(milliseconds: 300),
                ),
              );
            }
          }
          await _publishPosition(position);
        },
        onError: (Object error) async {
          await _positionSubscription?.cancel();
          _positionSubscription = null;
          if (mounted) {
            setState(() {
              if (error is TajGoLocationException) {
                _locationIssue = error;
              }
              _geoError = '$error';
            });
          }
        },
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          if (error is TajGoLocationException) {
            _locationIssue = error;
          }
          _geoError = '$error';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _locationStarting = false);
      }
    }
  }

  Future<void> _publishPosition(Position position, {bool force = false}) async {
    try {
      await TajGoScope.of(context).courierRepository.updateLocation(
        uid: _uid,
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
        speed: position.speed,
        accuracy: position.accuracy,
        force: force,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _geoError = 'Позиция видна на карте, но не отправлена: $error',
        );
      }
    }
  }

  Future<void> _openLocationSettings() async {
    final issue = _locationIssue;
    if (issue == null) {
      await _startLocation();
      return;
    }
    await TajGoScope.of(context).locationService.openSettingsFor(issue.issue);
  }

  void _centerOnCourier() {
    final position = _position;
    if (position == null) {
      _startLocation();
      return;
    }
    setState(() => _followCourier = true);
    unawaited(
      _camera.animateTo(
        controller: _mapController,
        target: position,
        zoom: TajGoMapCamera.navigationZoom,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.stop();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
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

  double? _distanceTo(LatLng? target) {
    if (_position == null || target == null) {
      return null;
    }
    return pricing.haversineDistanceKm(_position!, target);
  }

  int? _etaMinutes(double? distanceKm) => distanceKm == null
      ? null
      : pricing.courierNavigationEtaMinutes(distanceKm);

  double? _bearingTo(LatLng? target) {
    final position = _position;
    if (position == null || target == null) return null;
    return Geolocator.bearingBetween(
      position.latitude,
      position.longitude,
      target.latitude,
      target.longitude,
    );
  }

  Future<void> _openNavigator(LatLng target) async {
    final latitude = target.latitude;
    final longitude = target.longitude;
    final native = defaultTargetPlatform == TargetPlatform.iOS
        ? Uri.parse('https://maps.apple.com/?daddr=$latitude,$longitude')
        : Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude(TajGo)');
    final fallback = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );
    try {
      final opened = await launchUrl(
        native,
        mode: LaunchMode.externalApplication,
      );
      if (!opened &&
          !await launchUrl(fallback, mode: LaunchMode.externalApplication)) {
        throw StateError('Не удалось открыть навигатор.');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть навигатор: $error')),
        );
      }
    }
  }

  Future<void> _showCompletionDialog(TajGoOrder order, double distance) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Передать заказ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Код клиента',
            hintText: '0000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _run(
                () => TajGoScope.of(context).courierRepository.markDelivered(
                  orderId: order.id,
                  courierId: _uid,
                  distanceToPointKm: distance,
                ),
              );
            },
            child: const Text('Клиент не может назвать код'),
          ),
          FilledButton(
            onPressed: () {
              final code = controller.text.trim();
              if (!RegExp(r'^\d{4}$').hasMatch(code)) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Введите четыре цифры.')),
                );
                return;
              }
              Navigator.pop(dialogContext);
              _run(
                () => TajGoScope.of(context).courierRepository.completeWithCode(
                  orderId: order.id,
                  courierId: _uid,
                  code: code,
                  distanceToPointKm: distance,
                ),
              );
            },
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  void _fitMap(List<LatLng> points) {
    if (_fitted || points.length < 2) {
      return;
    }
    _fitted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _centerRoute(points);
      }
    });
  }

  void _centerRoute(List<LatLng> points) {
    if (points.isEmpty) {
      return;
    }
    setState(() => _followCourier = false);
    if (points.length == 1) {
      _mapController.move(points.single, 16);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(48, 90, 48, 48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = TajGoScope.of(context).courierRepository;
    return Scaffold(
      body: StreamBuilder<TajGoOrder?>(
        stream: repository.orderStream(widget.orderId),
        builder: (context, snapshot) {
          final order = snapshot.data;
          if (order == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final from = order.fromLocation == null
              ? null
              : LatLng(
                  order.fromLocation!.latitude,
                  order.fromLocation!.longitude,
                );
          final to = order.toLocation == null
              ? null
              : LatLng(order.toLocation!.latitude, order.toLocation!.longitude);
          final orderRoute = from != null && to != null
              ? TajGoScope.of(
                  context,
                ).routeService.directRoute(from: from, to: to)
              : null;
          final target = switch (order.status) {
            OrderStatus.accepted => from,
            OrderStatus.pickedUp => to,
            _ => null,
          };
          final targetDistance = _distanceTo(target);
          final etaMinutes = _etaMinutes(targetDistance);
          final targetBearing = _bearingTo(target);
          final fitPoints = <LatLng>[?_position, ?from, ?to];
          if (_lastNavigationStatus != order.status) {
            _lastNavigationStatus = order.status;
            _fitted = false;
          }
          _fitMap(fitPoints);
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
                        onPositionChanged: (_, hasGesture) {
                          if (hasGesture && _followCourier) {
                            setState(() => _followCourier = false);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'tj.tajgo.app',
                          maxZoom: 19,
                        ),
                        PolylineLayer(
                          polylines: [
                            if (from != null && to != null)
                              Polyline(
                                points: orderRoute!.polylinePoints,
                                color: TajGoColors.green,
                                strokeWidth: 4,
                              ),
                            if (_position != null && target != null)
                              Polyline(
                                points: [_position!, target],
                                color: TajGoColors.muted,
                                strokeWidth: 3,
                                pattern: StrokePattern.dashed(
                                  segments: const [8, 8],
                                ),
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
                                  color: TajGoColors.lime,
                                ),
                              ),
                            if (_position != null)
                              Marker(
                                point: _position!,
                                width: 46,
                                height: 46,
                                child: _CourierDirectionMarker(
                                  heading: _heading,
                                  accuracy: _accuracy,
                                ),
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
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'centerRoute',
                            onPressed: () => _centerRoute(fitPoints),
                            backgroundColor: Colors.white,
                            foregroundColor: TajGoColors.darkGreen,
                            tooltip: 'Центрировать маршрут',
                            child: const Icon(Icons.route_rounded),
                          ),
                          const SizedBox(height: 8),
                          TajGoLocateButton(
                            heroTag: 'centerCourier',
                            onPressed: _centerOnCourier,
                            loading: _locationStarting,
                            following: _followCourier && _position != null,
                          ),
                        ],
                      ),
                    ),
                    if (target != null)
                      Positioned(
                        left: 64,
                        right: 64,
                        top: MediaQuery.paddingOf(context).top + 12,
                        child: _NavigationInstruction(
                          status: order.status,
                          bearing: targetBearing,
                          distanceKm: targetDistance,
                          etaMinutes: etaMinutes,
                        ),
                      ),
                  ],
                ),
              ),
              _OrderPanel(
                order: order,
                target: target,
                distance: targetDistance,
                etaMinutes: etaMinutes,
                geoAvailable: _position != null && target != null,
                geoError: _geoError,
                onFixLocation: _openLocationSettings,
                busy: _busy,
                onNavigate: target == null
                    ? null
                    : () => _openNavigator(target),
                onClient: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Звонки появятся с телефонной авторизацией'),
                  ),
                ),
                onPrimary: () {
                  if (order.status == OrderStatus.accepted &&
                      order.arrivedAtPickupAt == null) {
                    _run(
                      () => repository.markArrived(
                        orderId: order.id,
                        courierId: _uid,
                        distanceToPointKm: targetDistance,
                      ),
                    );
                  } else if (order.status == OrderStatus.accepted) {
                    _run(
                      () => repository.markPickedUp(
                        orderId: order.id,
                        courierId: _uid,
                        distanceToPointKm: targetDistance,
                      ),
                    );
                  } else if (order.status == OrderStatus.pickedUp &&
                      targetDistance != null) {
                    _showCompletionDialog(order, targetDistance);
                  } else if (order.status == OrderStatus.completed) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderPanel extends StatelessWidget {
  const _OrderPanel({
    required this.order,
    required this.target,
    required this.distance,
    required this.etaMinutes,
    required this.geoAvailable,
    required this.geoError,
    required this.onFixLocation,
    required this.busy,
    required this.onNavigate,
    required this.onClient,
    required this.onPrimary,
  });

  final TajGoOrder order;
  final LatLng? target;
  final double? distance;
  final int? etaMinutes;
  final bool geoAvailable;
  final String? geoError;
  final VoidCallback onFixLocation;
  final bool busy;
  final VoidCallback? onNavigate;
  final VoidCallback onClient;
  final VoidCallback onPrimary;

  int get _step {
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.delivered ||
        order.status == OrderStatus.disputed) {
      return 4;
    }
    if (order.status == OrderStatus.pickedUp) {
      return 3;
    }
    return order.arrivedAtPickupAt == null ? 0 : 1;
  }

  String get _title => switch (order.status) {
    OrderStatus.accepted when order.arrivedAtPickupAt == null =>
      'Еду к точке забора',
    OrderStatus.accepted => 'Вы на месте',
    OrderStatus.pickedUp => 'Доставляю',
    OrderStatus.delivered => '⏳ Ждём подтверждения клиента',
    OrderStatus.completed => '✅ Доставлено! +${order.price} TJS',
    OrderStatus.disputed => '⚠️ Клиент сообщил, что не получил заказ',
    _ => 'Заказ',
  };

  String? get _primaryLabel => switch (order.status) {
    OrderStatus.accepted when order.arrivedAtPickupAt == null => 'Я на месте',
    OrderStatus.accepted => 'Забрал заказ',
    OrderStatus.pickedUp => 'Передал заказ',
    OrderStatus.completed => 'К заказам',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final tooFar = distance != null && !pricing.withinActionRadius(distance!);
    final needsGeo =
        order.status == OrderStatus.accepted ||
        order.status == OrderStatus.pickedUp;
    final primaryEnabled =
        _primaryLabel != null && (!needsGeo || (geoAvailable && !tooFar));
    final address = order.status == OrderStatus.accepted
        ? order.fromText
        : order.toText;
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TajGoOrderProgress(currentStep: _step),
              const SizedBox(height: 14),
              Text(
                _title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(address, style: const TextStyle(color: TajGoColors.muted)),
              const SizedBox(height: 3),
              Text(
                'Ваш доход за заказ: ${order.price} TJS.',
                style: const TextStyle(
                  color: TajGoColors.darkGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (order.fromLocation != null && order.toLocation != null)
                const Text(
                  'Маршрут предварительный — показана прямая линия.',
                  style: TextStyle(color: TajGoColors.warning, fontSize: 12),
                ),
              if ((order.comment ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '💬 ${order.comment}',
                  style: const TextStyle(color: TajGoColors.muted),
                ),
              ],
              if (distance != null) ...[
                const SizedBox(height: 7),
                Text(
                  'До точки: ${distance!.toStringAsFixed(1)} км'
                  '${etaMinutes == null ? '' : ' · ≈ $etaMinutes мин'}',
                  style: const TextStyle(color: TajGoColors.muted),
                ),
              ],
              if (needsGeo && geoAvailable) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: tooFar ? const Color(0xFFFFF7E6) : TajGoColors.mint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tooFar
                        ? 'Подойдите ближе, чтобы подтвердить действие'
                        : 'Можно подтвердить действие',
                    style: TextStyle(
                      color: tooFar
                          ? TajGoColors.warning
                          : TajGoColors.darkGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              if (needsGeo && !geoAvailable) ...[
                const SizedBox(height: 7),
                Text(
                  geoError == null
                      ? 'Ищем GPS...'
                      : 'Разрешите геолокацию для работы курьером',
                  style: const TextStyle(
                    color: TajGoColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (geoError != null)
                  TextButton(
                    onPressed: onFixLocation,
                    child: const Text('Открыть настройки'),
                  ),
              ],
              if (order.status == OrderStatus.delivered)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Пока клиент не подтвердит получение, новые заказы недоступны.',
                    style: TextStyle(color: TajGoColors.muted),
                  ),
                ),
              if (order.status == OrderStatus.disputed)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'С вами свяжутся для проверки доставки.',
                    style: TextStyle(color: TajGoColors.error),
                  ),
                ),
              if (_primaryLabel != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Клиент',
                      onPressed: onClient,
                      icon: const Icon(Icons.phone_outlined),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: onNavigate,
                      child: const Text('Навигатор'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TajGoActionButton(
                        label: _primaryLabel!,
                        busy: busy,
                        onPressed: primaryEnabled ? onPrimary : null,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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

class _CourierDirectionMarker extends StatelessWidget {
  const _CourierDirectionMarker({
    required this.heading,
    required this.accuracy,
  });

  final double? heading;
  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    final direction = heading != null && heading!.isFinite && heading! >= 0
        ? heading! * 3.141592653589793 / 180
        : 0.0;
    return Tooltip(
      message: accuracy == null
          ? 'Текущая позиция'
          : 'Точность GPS: ±${accuracy!.round()} м',
      child: Transform.rotate(
        angle: direction,
        child: Container(
          decoration: BoxDecoration(
            color: TajGoColors.darkGreen,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 10),
            ],
          ),
          child: const Icon(
            Icons.navigation_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _NavigationInstruction extends StatelessWidget {
  const _NavigationInstruction({
    required this.status,
    required this.bearing,
    required this.distanceKm,
    required this.etaMinutes,
  });

  final OrderStatus status;
  final double? bearing;
  final double? distanceKm;
  final int? etaMinutes;

  String get _targetLabel =>
      status == OrderStatus.accepted ? 'Едем к точке забора' : 'Везём клиенту';

  String get _direction {
    final value = bearing;
    if (value == null) return 'Определяем направление';
    const labels = [
      'на север',
      'на северо-восток',
      'на восток',
      'на юго-восток',
      'на юг',
      'на юго-запад',
      'на запад',
      'на северо-запад',
    ];
    final normalized = (value + 360) % 360;
    return labels[((normalized + 22.5) ~/ 45) % 8];
  }

  @override
  Widget build(BuildContext context) {
    final angle = ((bearing ?? 0) * 3.141592653589793) / 180;
    return Material(
      color: TajGoColors.ink.withValues(alpha: 0.92),
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Transform.rotate(
              angle: angle,
              child: const Icon(
                Icons.navigation_rounded,
                color: TajGoColors.lime,
                size: 30,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _targetLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$_direction'
                    '${distanceKm == null ? '' : ' · ${distanceKm!.toStringAsFixed(1)} км'}'
                    '${etaMinutes == null ? '' : ' · ≈ $etaMinutes мин'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
