import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_order.dart';
import '../../core/services/external_navigator_service.dart';
import '../../core/services/pricing.dart' as pricing;
import '../../shared/widgets/tajgo_action_button.dart';
import '../../shared/widgets/tajgo_order_progress.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../map/services/tajgo_location_service.dart';
import '../map/services/tajgo_map_camera.dart';
import '../map/models/navigation_state.dart';
import '../map/models/tajgo_route.dart';
import '../map/models/tajgo_route_progress.dart';
import '../map/utils/route_display_formatter.dart';
import '../map/services/navigation_camera_controller.dart';
import '../map/services/navigation_instruction_formatter.dart';
import '../map/services/route_progress_service.dart';
import '../map/widgets/tajgo_map_action_buttons.dart';

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
  late final NavigationCameraController _navigationCamera;
  static const _progressService = RouteProgressService();
  static const _instructionFormatter = NavigationInstructionFormatter();
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _position;
  double? _heading;
  double? _accuracy;
  double _speedMps = 0;
  NavigationCameraMode _cameraMode = NavigationCameraMode.follow;
  bool _locationStarting = false;
  bool _busy = false;
  bool _fitted = false;
  OrderStatus? _lastNavigationStatus;
  TajGoLocationException? _locationIssue;
  String? _geoError;
  TajGoRoute? _navigationRoute;
  LatLng? _activeTarget;
  LatLng? _lastRouteOrigin;
  DateTime? _lastRouteAt;
  bool _routeLoading = false;
  bool _offRoute = false;
  bool _routeUpdated = false;
  DateTime? _lastProgressAt;
  DateTime? _offRouteCandidateAt;
  TajGoRouteProgress? _routeProgress;
  Timer? _routeUpdatedTimer;

  String get _uid => TajGoScope.of(context).authService.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _navigationCamera = NavigationCameraController(
      mapController: _mapController,
      camera: _camera,
      onModeChanged: (mode) {
        if (mounted && mode != _cameraMode) setState(() => _cameraMode = mode);
      },
    );
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
        _speedMps = initial.speed.isFinite ? initial.speed : 0;
        _locationIssue = null;
        _geoError = null;
      });
      unawaited(
        _navigationCamera.followPosition(_position!, speedMps: _speedMps),
      );
      await _publishPosition(initial, force: true);
      _positionSubscription = service.positionStream().listen(
        (position) async {
          if (mounted) {
            setState(() {
              _position = LatLng(position.latitude, position.longitude);
              _heading = position.heading;
              _accuracy = position.accuracy;
              _speedMps = position.speed.isFinite ? position.speed : 0;
              _locationIssue = null;
              _geoError = null;
            });
            _updateRouteProgress(_position!);
            if (_cameraMode == NavigationCameraMode.follow) {
              unawaited(
                _navigationCamera.followPosition(
                  _position!,
                  speedMps: _speedMps,
                ),
              );
            }
            unawaited(_maybeRebuildRoute(_position!));
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
    unawaited(_navigationCamera.followPosition(position, speedMps: _speedMps));
  }

  void _setActiveTarget(LatLng? target) {
    final previous = _activeTarget;
    final changed =
        target == null ||
        previous == null ||
        const Distance().as(LengthUnit.Meter, previous, target) > 5;
    if (!changed) return;
    _activeTarget = target;
    _navigationRoute = null;
    _lastRouteAt = null;
    _offRoute = false;
    _offRouteCandidateAt = null;
    _routeProgress = null;
    final position = _position;
    if (position != null && target != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _rebuildRoute(position, target, force: true),
      );
    }
  }

  Future<void> _maybeRebuildRoute(LatLng position) async {
    final target = _activeTarget;
    if (target == null || _routeLoading) return;
    final now = DateTime.now();
    final elapsed = now.difference(
      _lastRouteAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
    final moved = _lastRouteOrigin == null
        ? double.infinity
        : const Distance().as(LengthUnit.Meter, _lastRouteOrigin!, position);
    final route = _navigationRoute;
    final shouldRefresh =
        route == null ||
        (!route.isFallback &&
            elapsed >= const Duration(seconds: 25) &&
            (moved >= 150 || _offRoute)) ||
        (route.isFallback &&
            elapsed >= const Duration(seconds: 60) &&
            moved >= 150);
    if (shouldRefresh) {
      await _rebuildRoute(position, target, force: _offRoute);
    }
  }

  Future<void> _rebuildRoute(
    LatLng from,
    LatLng target, {
    required bool force,
  }) async {
    if (_routeLoading || !mounted) return;
    setState(() => _routeLoading = true);
    final route = await TajGoScope.of(context).routeService.buildRoute(
      from: from,
      to: target,
      mode: RouteMode.bicycle,
      forceRefresh: force,
    );
    if (!mounted) return;
    if (_activeTarget != target) {
      setState(() => _routeLoading = false);
      return;
    }
    final wasExisting = _navigationRoute != null;
    final progress = _progressService.calculateProgress(route, from);
    setState(() {
      _navigationRoute = route;
      _routeProgress = progress;
      _lastRouteOrigin = from;
      _lastRouteAt = DateTime.now();
      _routeLoading = false;
      _offRoute = false;
      _offRouteCandidateAt = null;
      _routeUpdated = wasExisting;
    });
    if (wasExisting) {
      _routeUpdatedTimer?.cancel();
      _routeUpdatedTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _routeUpdated = false);
      });
    }
  }

  void _updateRouteProgress(LatLng position) {
    final route = _navigationRoute;
    if (route == null) return;
    final now = DateTime.now();
    if (_lastProgressAt != null &&
        now.difference(_lastProgressAt!) < const Duration(milliseconds: 750)) {
      return;
    }
    _lastProgressAt = now;
    final progress = _progressService.calculateProgress(route, position);
    var persistentOffRoute = false;
    if (progress.isOffRoute && !route.isFallback) {
      _offRouteCandidateAt ??= now;
      persistentOffRoute =
          now.difference(_offRouteCandidateAt!) >= const Duration(seconds: 10);
    } else {
      _offRouteCandidateAt = null;
    }
    if (mounted) {
      setState(() {
        _routeProgress = progress;
        _offRoute = persistentOffRoute;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.stop();
    _positionSubscription?.cancel();
    _routeUpdatedTimer?.cancel();
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

  Future<void> _openNavigator(LatLng target) async {
    final service = TajGoScope.of(context).externalNavigatorService;
    final preference = await service.load();
    var selected = preference.navigator;
    if (preference.askEveryTime && mounted) {
      selected =
          await showModalBottomSheet<ExternalNavigator>(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: ExternalNavigator.values
                    .map(
                      (value) => ListTile(
                        title: Text(_navigatorLabel(value)),
                        onTap: () => Navigator.pop(context, value),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ) ??
          selected;
    }
    if (selected == ExternalNavigator.tajgo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Навигация TajGo уже открыта.')),
        );
      }
      return;
    }
    try {
      if (!await service.open(navigator: selected, destination: target)) {
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

  String _navigatorLabel(ExternalNavigator value) => switch (value) {
    ExternalNavigator.tajgo => 'TajGo',
    ExternalNavigator.yandex => 'Яндекс Навигатор',
    ExternalNavigator.google => 'Google Maps',
    ExternalNavigator.twoGis => '2GIS',
    ExternalNavigator.system => 'Системный навигатор',
  };

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
        final position = _position;
        if (position == null) {
          _centerRoute(points);
        } else {
          unawaited(
            _navigationCamera.followPosition(position, speedMps: _speedMps),
          );
        }
      }
    });
  }

  void _centerRoute(List<LatLng> points) {
    if (points.isEmpty) {
      return;
    }
    _navigationCamera.showOverview(points);
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
          final target = switch (order.status) {
            OrderStatus.accepted => from,
            OrderStatus.pickedUp => to,
            _ => null,
          };
          _setActiveTarget(target);
          final targetDistance = _distanceTo(target);
          final progress = _routeProgress;
          final navigationDistance =
              progress?.remainingDistanceKm ?? targetDistance;
          final etaMinutes =
              progress?.remainingEtaMinutes ?? _etaMinutes(targetDistance);
          final isNearTarget = targetDistance != null && targetDistance <= 0.12;
          final navigationTarget = order.status == OrderStatus.pickedUp
              ? NavigationTarget.dropoff
              : NavigationTarget.pickup;
          final instruction = isNearTarget
              ? navigationTarget == NavigationTarget.pickup
                    ? 'Вы рядом с точкой забора'
                    : 'Вы рядом с клиентом'
              : progress?.nextStep?.instructionRu ??
                    _instructionFormatter.fallback(target: navigationTarget);
          final fitPoints =
              _navigationRoute?.points ?? <LatLng>[?_position, ?target];
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
                          if (hasGesture &&
                              _cameraMode != NavigationCameraMode.free) {
                            _navigationCamera.setFree();
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
                            if (_navigationRoute != null)
                              Polyline(
                                points: _navigationRoute!.points,
                                color:
                                    _navigationRoute!.routeQuality ==
                                        RouteQuality.road
                                    ? TajGoColors.green
                                    : TajGoColors.warning,
                                strokeWidth:
                                    _navigationRoute!.routeQuality ==
                                        RouteQuality.road
                                    ? 5
                                    : 3,
                                pattern:
                                    _navigationRoute!.routeQuality ==
                                        RouteQuality.road
                                    ? const StrokePattern.solid()
                                    : StrokePattern.dashed(
                                        segments: const [8, 8],
                                      ),
                              ),
                            if (_navigationRoute == null &&
                                _position != null &&
                                target != null)
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
                                child: _AddressPin(
                                  label: 'A',
                                  color: order.status == OrderStatus.accepted
                                      ? TajGoColors.darkGreen
                                      : TajGoColors.muted.withValues(
                                          alpha: 0.55,
                                        ),
                                ),
                              ),
                            if (to != null)
                              Marker(
                                point: to,
                                width: 48,
                                height: 48,
                                child: _AddressPin(
                                  label: 'B',
                                  color: order.status == OrderStatus.pickedUp
                                      ? Colors.blue
                                      : TajGoColors.muted.withValues(
                                          alpha: 0.55,
                                        ),
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
                            if (_navigationRoute?.isFallback == false &&
                                progress?.nextStep != null)
                              Marker(
                                point: progress!.nextStep!.location,
                                width: 34,
                                height: 34,
                                child: const _ManeuverMarker(),
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
                      child: TajGoMapActionButtons(
                        heroPrefix: 'courierOrder',
                        onShowRoute: () => _centerRoute(fitPoints),
                        onLocate: _centerOnCourier,
                        locating: _locationStarting,
                        following:
                            _cameraMode == NavigationCameraMode.follow &&
                            _position != null,
                      ),
                    ),
                    if (target != null)
                      Positioned(
                        left: 64,
                        right: 64,
                        top: MediaQuery.paddingOf(context).top + 12,
                        child: _NavigationInstruction(
                          status: order.status,
                          instruction: instruction,
                          distanceKm: navigationDistance,
                          etaMinutes: etaMinutes,
                          route: _navigationRoute,
                          rebuilding: _routeLoading,
                          offRoute: _offRoute,
                          gpsWeak: (_accuracy ?? 0) > 50,
                          routeUpdated: _routeUpdated,
                        ),
                      ),
                  ],
                ),
              ),
              _OrderPanel(
                order: order,
                target: target,
                distance: navigationDistance,
                directDistance: targetDistance,
                etaMinutes: etaMinutes,
                geoAvailable: _position != null && target != null,
                geoError: _geoError,
                route: _navigationRoute,
                routeLoading: _routeLoading,
                offRoute: _offRoute,
                isNearTarget: isNearTarget,
                gpsWeak: (_accuracy ?? 0) > 50,
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
    required this.directDistance,
    required this.etaMinutes,
    required this.geoAvailable,
    required this.geoError,
    required this.route,
    required this.routeLoading,
    required this.offRoute,
    required this.isNearTarget,
    required this.gpsWeak,
    required this.onFixLocation,
    required this.busy,
    required this.onNavigate,
    required this.onClient,
    required this.onPrimary,
  });

  final TajGoOrder order;
  final LatLng? target;
  final double? distance;
  final double? directDistance;
  final int? etaMinutes;
  final bool geoAvailable;
  final String? geoError;
  final TajGoRoute? route;
  final bool routeLoading;
  final bool offRoute;
  final bool isNearTarget;
  final bool gpsWeak;
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
      'Едем к точке забора',
    OrderStatus.accepted => 'Вы на месте',
    OrderStatus.pickedUp => 'Везём клиенту',
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
    final tooFar =
        directDistance != null && !pricing.withinActionRadius(directDistance!);
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
                Text(
                  routeLoading
                      ? 'Перестраиваем маршрут…'
                      : formatRouteQuality(route),
                  style: TextStyle(
                    color: route?.isFallback == false
                        ? TajGoColors.darkGreen
                        : TajGoColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (offRoute)
                const Text(
                  'Вы отклонились от маршрута. Перестраиваем…',
                  style: TextStyle(
                    color: TajGoColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if ((order.comment ?? '').isNotEmpty ||
                  order.status == OrderStatus.pickedUp) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.status == OrderStatus.pickedUp
                            ? 'Точка доставки'
                            : 'Точка забора',
                        style: const TextStyle(
                          color: TajGoColors.darkGreen,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if ((order.comment ?? '').isNotEmpty)
                        Text(
                          'Ориентир / комментарий: ${order.comment}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (order.status == OrderStatus.pickedUp)
                        const Text('Код получения: спросите у клиента'),
                    ],
                  ),
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
                    gpsWeak
                        ? 'GPS слабый — точка может быть неточной'
                        : isNearTarget
                        ? 'Вы рядом с точкой'
                        : tooFar
                        ? '⚠ Подойдите ближе, чтобы подтвердить'
                        : 'Можно подтверждать — вы у точки',
                    style: TextStyle(
                      color: tooFar || gpsWeak
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
                      ? 'Ищем точную геолокацию'
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
                      child: const Text('Открыть в навигаторе'),
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

class _ManeuverMarker extends StatelessWidget {
  const _ManeuverMarker();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: TajGoColors.lime,
      shape: BoxShape.circle,
      border: Border.all(color: TajGoColors.ink, width: 2),
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 7)],
    ),
    child: const Icon(
      Icons.turn_right_rounded,
      color: TajGoColors.ink,
      size: 22,
    ),
  );
}

class _NavigationInstruction extends StatelessWidget {
  const _NavigationInstruction({
    required this.status,
    required this.instruction,
    required this.distanceKm,
    required this.etaMinutes,
    required this.route,
    required this.rebuilding,
    required this.offRoute,
    required this.gpsWeak,
    required this.routeUpdated,
  });

  final OrderStatus status;
  final String instruction;
  final double? distanceKm;
  final int? etaMinutes;
  final TajGoRoute? route;
  final bool rebuilding;
  final bool offRoute;
  final bool gpsWeak;
  final bool routeUpdated;

  String get _targetLabel =>
      status == OrderStatus.accepted ? 'До точки забора' : 'До клиента';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TajGoColors.ink.withValues(alpha: 0.92),
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.assistant_direction_rounded,
              color: TajGoColors.lime,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    instruction,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$_targetLabel'
                    '${distanceKm == null ? '' : ' · ${formatRouteDistance(distanceKm!)}'}'
                    '${etaMinutes == null ? '' : ' · ${formatRouteEta(etaMinutes!)}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    offRoute
                        ? 'Перестраиваем маршрут…'
                        : rebuilding
                        ? 'Перестраиваем маршрут…'
                        : routeUpdated
                        ? 'Маршрут обновлён'
                        : gpsWeak
                        ? 'GPS слабый — точка может быть неточной'
                        : formatRouteQuality(route),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: offRoute || rebuilding || gpsWeak
                          ? const Color(0xFFFFD166)
                          : const Color(0xFFB8F7C9),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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
