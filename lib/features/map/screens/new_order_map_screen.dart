import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/tajgo_colors.dart';
import '../../../core/models/tajgo_courier.dart';
import '../../../core/services/pricing.dart' as pricing;
import '../../../shared/widgets/tajgo_scope.dart';
import '../../customer/order_tracking_screen.dart';
import '../models/place_suggestion.dart';
import '../models/tajgo_map_location.dart';
import '../models/tajgo_route.dart';
import '../services/place_search_service.dart';
import '../services/tajgo_map_camera.dart';
import '../services/tajgo_location_service.dart';
import '../widgets/tajgo_location_widgets.dart';
import '../widgets/tajgo_place_search_sheet.dart';
import '../widgets/tajgo_route_summary_card.dart';
import '../utils/map_address_formatter.dart';
import '../utils/new_order_map_layout.dart';

enum _Stage { pickFrom, pickTo, details }

class NewOrderMapScreen extends StatefulWidget {
  const NewOrderMapScreen({super.key, this.initialType = 'package'});
  final String initialType;
  @override
  State<NewOrderMapScreen> createState() => _NewOrderMapScreenState();
}

class _NewOrderMapScreenState extends State<NewOrderMapScreen> {
  static const _center = LatLng(40.2833, 69.6222);
  static const _types = {
    'package': 'Посылка',
    'food': 'Еда',
    'shops': 'Магазины',
    'pharmacy': 'Аптеки',
    'flowers': 'Цветы',
    'docs': 'Документы',
  };
  final _map = MapController();
  final _camera = TajGoMapCamera();
  final _price = TextEditingController();
  final _comment = TextEditingController();
  late final PlaceSearchService _placeSearch;
  _Stage _stage = _Stage.pickFrom;
  late String _type = widget.initialType;
  TajGoMapLocation? _from, _to;
  PlaceSuggestion? _pendingPlace;
  TajGoRoute? _route;
  bool _routeLoading = false;
  int _routeRequestId = 0;
  int _reverseRequestId = 0;
  LatLng? _current;
  String _address = 'Определяем адрес...';
  bool _resolving = false, _locating = false, _busy = false;
  bool _cameraMoving = false;
  bool _gestureMoving = false;
  bool _mapLoading = true;
  bool _showLocateHint = false;
  bool _showYouAreHere = false;
  bool _gpsWeak = false;
  Timer? _youAreHereTimer;

  bool get _selectionMoving => _cameraMoving || _gestureMoving;

  @override
  void initState() {
    super.initState();
    _placeSearch = PlaceSearchService();
    unawaited(_loadLocateHint());
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareMap());
  }

  Future<void> _loadLocateHint() async {
    final preferences = SharedPreferencesAsync();
    final seen = await preferences.getBool('new_order_locate_hint_seen_v1');
    if (mounted) setState(() => _showLocateHint = seen != true);
  }

  Future<void> _prepareMap() async {
    final position = await TajGoScope.of(
      context,
    ).locationService.currentPositionIfAuthorized();
    if (!mounted) {
      return;
    }
    if (position == null) {
      await _resolveCenter();
      return;
    }
    final point = LatLng(position.latitude, position.longitude);
    setState(() {
      _current = point;
      _gpsWeak = position.accuracy > 50;
    });
    await _moveToCurrent(point);
    await _resolveCenter();
  }

  Future<void> _moveToCurrent(LatLng point) async {
    if (mounted) {
      setState(() => _cameraMoving = true);
    }
    await _camera.animateTo(
      controller: _map,
      target: point,
      zoom: TajGoMapCamera.cityZoom,
    );
    if (mounted) {
      setState(() => _cameraMoving = false);
    }
  }

  Future<void> _showLocationError(Object error) async {
    final service = TajGoScope.of(context).locationService;
    final issue = service.userFacingException(error);
    final action = switch (issue.issue) {
      TajGoLocationIssue.serviceDisabled => SnackBarAction(
        label: 'Включить',
        onPressed: () => service.openSettingsFor(issue.issue),
      ),
      TajGoLocationIssue.denied => SnackBarAction(
        label: 'Разрешить',
        onPressed: _locate,
      ),
      TajGoLocationIssue.deniedForever => SnackBarAction(
        label: 'Открыть настройки',
        onPressed: () => service.openSettingsFor(issue.issue),
      ),
      TajGoLocationIssue.unavailable => null,
    };
    final message = switch (issue.issue) {
      TajGoLocationIssue.serviceDisabled =>
        'Включите геолокацию, чтобы показать ваше положение.',
      TajGoLocationIssue.denied => 'Разрешите TajGo доступ к геолокации.',
      TajGoLocationIssue.deniedForever => 'Геолокация запрещена в настройках.',
      TajGoLocationIssue.unavailable => issue.message,
    };
    final panelHeight = _panelHeight(MediaQuery.sizeOf(context));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 16, 16, panelHeight + 16),
      ),
    );
  }

  @override
  void dispose() {
    _camera.stop();
    _youAreHereTimer?.cancel();
    _price.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _showAddressSearch(_Stage stage) async {
    if (stage == _Stage.pickTo && _from == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите точку «Откуда».')),
      );
      return;
    }
    if (_stage != stage) {
      setState(() => _stage = stage);
    }
    final selected = await showPlaceSearchSheet(
      context: context,
      service: _placeSearch,
      title: stage == _Stage.pickFrom
          ? 'Найти точку забора'
          : 'Найти точку доставки',
      near: _current,
      recentType: stage == _Stage.pickFrom ? 'pickup' : 'dropoff',
    );
    if (!mounted || selected == null) return;
    setState(() {
      _pendingPlace = selected;
      _address = selected.address;
      _cameraMoving = true;
    });
    await _camera.animateTo(controller: _map, target: selected.point, zoom: 17);
    if (!mounted) return;
    setState(() => _cameraMoving = false);
  }

  Future<void> _resolveCenter() async {
    if (_stage == _Stage.details) {
      return;
    }
    setState(() {
      _resolving = true;
      _address = 'Определяем адрес...';
    });
    final point = _map.camera.center;
    final requestId = ++_reverseRequestId;
    final result = await _placeSearch.reverse(point);
    if (mounted && requestId == _reverseRequestId) {
      setState(() {
        _address = result.address;
        _pendingPlace = result;
        _resolving = false;
      });
    }
  }

  Future<void> _locate() async {
    if (_locating) {
      return;
    }
    setState(() {
      _locating = true;
      _showLocateHint = false;
    });
    unawaited(
      SharedPreferencesAsync().setBool('new_order_locate_hint_seen_v1', true),
    );
    try {
      final position = await TajGoScope.of(
        context,
      ).locationService.determineCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) {
        return;
      }
      setState(() {
        _current = point;
        _gpsWeak = position.accuracy > 50;
      });
      await _moveToCurrent(point);
      await _resolveCenter();
      if (mounted) {
        _youAreHereTimer?.cancel();
        setState(() => _showYouAreHere = true);
        _youAreHereTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showYouAreHere = false);
        });
      }
    } catch (error) {
      if (mounted) {
        await _showLocationError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _confirmPoint() async {
    if (_resolving || _selectionMoving) {
      return;
    }
    final point = _map.camera.center;
    final location = TajGoMapLocation(
      latitude: point.latitude,
      longitude: point.longitude,
      address: _address,
    );
    final recentPlace = PlaceSuggestion(
      id: 'selected_${point.latitude}_${point.longitude}',
      title: _pendingPlace?.title ?? _address,
      subtitle: _pendingPlace?.subtitle ?? _address,
      shortTitle: _pendingPlace?.shortTitle ?? _address.split(',').first,
      address: _address,
      lat: point.latitude,
      lng: point.longitude,
      source: _pendingPlace?.source ?? 'manual',
      confidence: _pendingPlace?.confidence ?? 0.5,
      category: _pendingPlace?.category ?? 'mapPoint',
    );
    if (_stage == _Stage.pickFrom) {
      try {
        await _placeSearch.recentPlaces.save(recentPlace, type: 'pickup');
      } catch (_) {}
      setState(() {
        _from = location;
        _stage = _Stage.pickTo;
        _pendingPlace = null;
        _address = 'Определяем адрес...';
      });
      await _resolveCenter();
    } else {
      try {
        await _placeSearch.recentPlaces.save(recentPlace, type: 'dropoff');
      } catch (_) {}
      setState(() {
        _to = location;
        _stage = _Stage.details;
        _pendingPlace = null;
      });
      final km = pricing.distanceKm(_from!.toLatLng(), location.toLatLng());
      _price.text = pricing.suggestedPrice(km).toString();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _map.fitCamera(
          CameraFit.coordinates(
            coordinates: [_from!.toLatLng(), location.toLatLng()],
            padding: const EdgeInsets.all(60),
          ),
        ),
      );
      await _buildOrderRoute();
    }
  }

  Future<void> _buildOrderRoute() async {
    final from = _from?.toLatLng();
    final to = _to?.toLatLng();
    if (from == null || to == null) return;
    final requestId = ++_routeRequestId;
    setState(() => _routeLoading = true);
    final route = await TajGoScope.of(
      context,
    ).routeService.buildRoute(from: from, to: to, mode: RouteMode.bicycle);
    if (!mounted || requestId != _routeRequestId) return;
    setState(() {
      _route = route;
      _routeLoading = false;
      _price.text = pricing.suggestedPrice(route.distanceKm).toString();
    });
  }

  void _showEntireRoute() {
    final points =
        _route?.points ?? <LatLng>[?_from?.toLatLng(), ?_to?.toLatLng()];
    if (points.length < 2) return;
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  double _panelHeight(Size size) {
    return NewOrderMapLayout.panelHeight(
      size,
      details: _stage == _Stage.details,
    );
  }

  bool get _pickupMatchesCurrent {
    if (_stage != _Stage.pickFrom || _current == null) return false;
    return const Distance().as(
          LengthUnit.Meter,
          _map.camera.center,
          _current!,
        ) <
        25;
  }

  void _edit(_Stage stage) {
    setState(() {
      _stage = stage;
      _pendingPlace = null;
      _address = stage == _Stage.pickFrom ? _from!.address : _to!.address;
    });
    final location = stage == _Stage.pickFrom ? _from! : _to!;
    _map.move(location.toLatLng(), 16);
  }

  Future<void> _createOrder() async {
    final amount = num.tryParse(_price.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите положительную цену.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final scope = TajGoScope.of(context);
      final user = scope.authService.currentUser!;
      final profile = await scope.userRepository.getUser(user.uid);
      final km =
          _route?.distanceKm ??
          pricing.distanceKm(_from!.toLatLng(), _to!.toLatLng());
      final orderId = await scope.orderRepository.createOrder(
        customerId: user.uid,
        customerName: profile?.name ?? 'Клиент',
        fromText: _from!.address,
        toText: _to!.address,
        type: _type,
        price: amount,
        fromLocation: _from!.toGeoPoint(),
        toLocation: _to!.toGeoPoint(),
        distanceKm: km,
        etaMinutes: pricing.etaMinutes(km),
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: orderId),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final repo = TajGoScope.of(context).courierRepository;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      body: StreamBuilder<List<TajGoCourier>>(
        stream: repo.onlineCouriersStream(),
        builder: (context, snapshot) {
          final couriers = snapshot.data ?? const <TajGoCourier>[];
          return LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final panelHeight = _panelHeight(size);
              final selecting = _stage != _Stage.details;
              return NewOrderMapStack(
                key: const ValueKey('new-order-map-screen'),
                children: [
                  Positioned.fill(
                    key: const ValueKey('new-order-map-viewport'),
                    child: FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: 13,
                        minZoom: 3,
                        maxZoom: 19,
                        onMapReady: () {
                          if (mounted) setState(() => _mapLoading = false);
                        },
                        onMapEvent: (event) {
                          if (!selecting || _cameraMoving) return;
                          if (event is MapEventMoveStart && !_gestureMoving) {
                            setState(() => _gestureMoving = true);
                          }
                          if (event is MapEventMoveEnd) {
                            if (_gestureMoving) {
                              setState(() => _gestureMoving = false);
                            }
                            _resolveCenter();
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
                        if (_stage == _Stage.details)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points:
                                    _route?.points ??
                                    [_from!.toLatLng(), _to!.toLatLng()],
                                color: _route?.routeQuality == RouteQuality.road
                                    ? TajGoColors.green
                                    : TajGoColors.warning,
                                strokeWidth:
                                    _route?.routeQuality == RouteQuality.road
                                    ? 4
                                    : 3,
                                pattern:
                                    _route?.routeQuality == RouteQuality.road
                                    ? const StrokePattern.solid()
                                    : StrokePattern.dashed(
                                        segments: const [8, 8],
                                      ),
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            ...couriers.map(
                              (courier) => Marker(
                                point: LatLng(
                                  courier.location!.latitude,
                                  courier.location!.longitude,
                                ),
                                width: 18,
                                height: 18,
                                child: const _CourierDot(),
                              ),
                            ),
                            if (_current != null)
                              Marker(
                                point: _current!,
                                width: 44,
                                height: 44,
                                child: TajGoCurrentLocationMarker(
                                  weakAccuracy: _gpsWeak,
                                ),
                              ),
                            if (_from != null && _stage != _Stage.pickFrom)
                              Marker(
                                point: _from!.toLatLng(),
                                width: 42,
                                height: 42,
                                child: const _PointMarker(
                                  label: 'A',
                                  color: TajGoColors.darkGreen,
                                ),
                              ),
                            if (_to != null && _stage == _Stage.details)
                              Marker(
                                point: _to!.toLatLng(),
                                width: 42,
                                height: 42,
                                child: const _PointMarker(
                                  label: 'B',
                                  color: TajGoColors.lime,
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
                  ),
                  if (selecting)
                    Positioned.fill(
                      bottom: panelHeight,
                      child: IgnorePointer(
                        child: Center(
                          child: Transform.translate(
                            offset: const Offset(0, -24),
                            child: _SelectionPin(stage: _stage),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RoundButton(
                              icon: Icons.arrow_back_rounded,
                              onPressed: () => Navigator.maybePop(context),
                            ),
                            const Spacer(),
                            if (selecting && couriers.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 9,
                                ),
                                decoration: _floatingDecoration(),
                                child: Text(
                                  '💚 ${couriers.length} курьеров рядом',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_mapLoading)
                    Positioned(
                      top: MediaQuery.paddingOf(context).top + 70,
                      left: 0,
                      right: 0,
                      child: const Center(
                        child: _MapStatusChip(text: 'Загружаем карту…'),
                      ),
                    ),
                  Positioned(
                    key: const ValueKey('new-order-map-gps'),
                    right: 16,
                    bottom: panelHeight + 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_stage == _Stage.details) ...[
                          _RoundButton(
                            icon: Icons.route_rounded,
                            onPressed: _showEntireRoute,
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_showLocateHint || _showYouAreHere) ...[
                              _MapStatusChip(
                                text: _showYouAreHere
                                    ? 'Вы здесь'
                                    : 'Показать, где я',
                              ),
                              const SizedBox(width: 8),
                            ],
                            TajGoLocateButton(
                              heroTag: 'newOrderLocate',
                              loading: _locating,
                              onPressed: _locating ? null : _locate,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    key: const ValueKey('new-order-map-bottom-panel'),
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: panelHeight,
                    child: _stage == _Stage.details
                        ? _DetailsPanel(
                            from: _from!,
                            to: _to!,
                            type: _type,
                            types: _types,
                            price: _price,
                            comment: _comment,
                            busy: _busy,
                            route: _route,
                            routeLoading: _routeLoading,
                            onType: (value) => setState(() => _type = value),
                            onPrice: (_) => setState(() {}),
                            onEdit: _edit,
                            onSubmit: _createOrder,
                            onShowRoute: _showEntireRoute,
                          )
                        : _PointPanel(
                            stage: _stage,
                            from: _from,
                            to: _to,
                            address: _address,
                            pendingPlace: _pendingPlace,
                            currentMatchesPickup: _pickupMatchesCurrent,
                            resolving: _resolving,
                            moving: _selectionMoving,
                            onConfirm: _confirmPoint,
                            onSearchFrom: () =>
                                _showAddressSearch(_Stage.pickFrom),
                            onSearchTo: () => _showAddressSearch(_Stage.pickTo),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

BoxDecoration _floatingDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(22),
  boxShadow: const [
    BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 6)),
  ],
);

class _PointPanel extends StatelessWidget {
  const _PointPanel({
    required this.stage,
    required this.from,
    required this.to,
    required this.address,
    required this.pendingPlace,
    required this.currentMatchesPickup,
    required this.resolving,
    required this.moving,
    required this.onConfirm,
    required this.onSearchFrom,
    required this.onSearchTo,
  });

  final _Stage stage;
  final TajGoMapLocation? from;
  final TajGoMapLocation? to;
  final String address;
  final PlaceSuggestion? pendingPlace;
  final bool currentMatchesPickup;
  final bool resolving;
  final bool moving;
  final VoidCallback onConfirm;
  final VoidCallback onSearchFrom;
  final VoidCallback onSearchTo;

  @override
  Widget build(BuildContext context) {
    final active = formatMapAddress(
      address,
      fallback: pendingPlace?.subtitle,
      currentLocation: currentMatchesPickup,
    );
    final fromPresentation = stage == _Stage.pickFrom
        ? active
        : formatMapAddress(from?.address ?? 'Точка забора');
    final toPresentation = stage == _Stage.pickTo
        ? active
        : formatMapAddress(to?.address ?? 'Введите адрес');

    final lowConfidence = (pendingPlace?.confidence ?? 1) < 0.45;
    final hint = moving
        ? 'Подождите, карта перемещается…'
        : resolving
        ? 'Определяем адрес…'
        : currentMatchesPickup
        ? 'Точка забора совпадает с вашим местоположением'
        : lowConfidence
        ? 'Проверьте точку на карте'
        : stage == _Stage.pickFrom
        ? 'Передвиньте карту или нажмите кнопку геолокации.'
        : 'Найдите адрес или передвиньте карту.';
    final enabled = !resolving && !moving;

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            children: [
              _AddressField(
                label: 'Откуда',
                presentation: fromPresentation,
                active: stage == _Stage.pickFrom,
                selected: from != null,
                marker: 'A',
                onTap: onSearchFrom,
              ),
              const SizedBox(height: 6),
              _AddressField(
                label: 'Куда',
                presentation: toPresentation,
                active: stage == _Stage.pickTo,
                selected: to != null,
                marker: 'B',
                onTap: onSearchTo,
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TajGoColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  key: const ValueKey('new-order-map-confirm'),
                  onPressed: enabled ? onConfirm : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: TajGoColors.lime,
                    foregroundColor: TajGoColors.ink,
                    disabledBackgroundColor: const Color(0xFFE1EEE5),
                    disabledForegroundColor: TajGoColors.muted,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: Text(
                    stage == _Stage.pickFrom
                        ? 'Подтвердить точку забора'
                        : 'Подтвердить точку доставки',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.label,
    required this.presentation,
    required this.active,
    required this.selected,
    required this.marker,
    required this.onTap,
  });

  final String label;
  final MapAddressPresentation presentation;
  final bool active;
  final bool selected;
  final String marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEAF4E7) : const Color(0xFFF5F6F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? TajGoColors.green : const Color(0xFFE2E5E3),
        ),
      ),
      child: Row(
        children: [
          _PointBadge(label: marker, active: active, selected: selected),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: TajGoColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  presentation.primary,
                  maxLines: 1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  presentation.secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TajGoColors.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.search_rounded, color: TajGoColors.muted, size: 19),
        ],
      ),
    ),
  );
}

class _PointBadge extends StatelessWidget {
  const _PointBadge({
    required this.label,
    required this.active,
    required this.selected,
  });

  final String label;
  final bool active;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final activeColor = label == 'A' ? TajGoColors.darkGreen : TajGoColors.lime;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active || selected ? activeColor : const Color(0xFFDDE4E0),
        shape: BoxShape.circle,
      ),
      child: selected
          ? Icon(
              Icons.check_rounded,
              size: 18,
              color: label == 'A' ? Colors.white : TajGoColors.ink,
            )
          : Text(
              label,
              style: TextStyle(
                color: active
                    ? label == 'A'
                          ? Colors.white
                          : TajGoColors.ink
                    : TajGoColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}

class _SelectionPin extends StatelessWidget {
  const _SelectionPin({required this.stage});

  final _Stage stage;

  @override
  Widget build(BuildContext context) {
    final color = stage == _Stage.pickFrom
        ? TajGoColors.darkGreen
        : TajGoColors.lime;
    final foreground = stage == _Stage.pickFrom
        ? Colors.white
        : TajGoColors.ink;
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Icon(
            Icons.location_pin,
            size: 58,
            color: color,
            shadows: const [
              Shadow(
                color: Color(0x66000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          Positioned(
            top: 11,
            child: Text(
              stage == _Stage.pickFrom ? 'A' : 'B',
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapStatusChip extends StatelessWidget {
  const _MapStatusChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    elevation: 5,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.from,
    required this.to,
    required this.type,
    required this.types,
    required this.price,
    required this.comment,
    required this.busy,
    required this.route,
    required this.routeLoading,
    required this.onType,
    required this.onPrice,
    required this.onEdit,
    required this.onSubmit,
    required this.onShowRoute,
  });
  final TajGoMapLocation from, to;
  final String type;
  final Map<String, String> types;
  final TextEditingController price;
  final TextEditingController comment;
  final bool busy;
  final TajGoRoute? route;
  final bool routeLoading;
  final ValueChanged<String> onType;
  final ValueChanged<String> onPrice;
  final ValueChanged<_Stage> onEdit;
  final VoidCallback onSubmit;
  final VoidCallback onShowRoute;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => onEdit(_Stage.pickFrom),
              child: Text(
                'Откуда: ${from.address}',
                style: const TextStyle(color: TajGoColors.muted),
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => onEdit(_Stage.pickTo),
              child: Text(
                'Куда: ${to.address}',
                style: const TextStyle(color: TajGoColors.muted),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: types.entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: type == entry.key,
                          selectedColor: TajGoColors.darkGreen,
                          labelStyle: TextStyle(
                            color: type == entry.key
                                ? Colors.white
                                : TajGoColors.ink,
                          ),
                          onSelected: (_) => onType(entry.key),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
            TajGoRouteSummaryCard(
              route: route,
              loading: routeLoading,
              onShowEntireRoute: onShowRoute,
              compact: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: comment,
              maxLength: 200,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Подъезд, ориентир или комментарий',
                hintText: 'Подъезд, этаж, «позвонить за 5 минут»',
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Итоговая цена: ${price.text} TJS',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Цена рассчитана по расстоянию. '
              'В тестовом режиме может быть уточнена.',
              style: const TextStyle(color: TajGoColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: price,
              onChanged: onPrice,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Цена, TJS'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : onSubmit,
              child: Text(
                busy ? 'Создаём...' : 'Найти курьера · ${price.text} TJS',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    elevation: 8,
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      color: TajGoColors.darkGreen,
    ),
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
    ),
  );
}

class _PointMarker extends StatelessWidget {
  const _PointMarker({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.topCenter,
    children: [
      Icon(
        Icons.location_pin,
        color: color,
        size: 42,
        shadows: const [Shadow(color: Color(0x55000000), blurRadius: 4)],
      ),
      Positioned(
        top: 7,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}

@visibleForTesting
Widget buildNewOrderPointPanelForTest({bool pickup = true}) => SizedBox(
  height: 272,
  child: _PointPanel(
    stage: pickup ? _Stage.pickFrom : _Stage.pickTo,
    from: pickup
        ? null
        : const TajGoMapLocation(
            latitude: 40.2833,
            longitude: 69.6222,
            address: 'ул. Исмоили Сомони, 54, Худжанд',
          ),
    to: null,
    address: pickup ? 'ул. Исмоили Сомони, 54, Худжанд' : 'Точка на карте',
    pendingPlace: null,
    currentMatchesPickup: false,
    resolving: false,
    moving: false,
    onConfirm: () {},
    onSearchFrom: () {},
    onSearchTo: () {},
  ),
);

@visibleForTesting
Widget buildNewOrderEmergencyMapLayoutForTest() {
  const size = Size(360, 800);
  final panelHeight = NewOrderMapLayout.panelHeight(size, details: false);
  return SizedBox.fromSize(
    size: size,
    child: NewOrderMapStack(
      children: [
        Positioned.fill(
          key: const ValueKey('new-order-map-viewport'),
          child: FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(40.2833, 69.6222),
              initialZoom: 13,
            ),
            children: const [],
          ),
        ),
        Positioned(
          key: const ValueKey('new-order-map-gps'),
          right: 16,
          bottom: panelHeight + 12,
          child: const TajGoLocateButton(
            heroTag: 'newOrderEmergencyTestLocate',
            onPressed: null,
          ),
        ),
        Positioned(
          key: const ValueKey('new-order-map-bottom-panel'),
          left: 0,
          right: 0,
          bottom: 0,
          height: panelHeight,
          child: buildNewOrderPointPanelForTest(),
        ),
      ],
    ),
  );
}
