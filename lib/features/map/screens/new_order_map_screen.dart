import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/tajgo_colors.dart';
import '../../../core/models/tajgo_courier.dart';
import '../../../core/services/pricing.dart' as pricing;
import '../../../shared/widgets/tajgo_scope.dart';
import '../../customer/order_tracking_screen.dart';
import '../models/place_suggestion.dart';
import '../models/tajgo_map_location.dart';
import '../services/place_search_service.dart';
import '../services/tajgo_map_camera.dart';
import '../widgets/tajgo_location_widgets.dart';
import '../widgets/place_search_sheet.dart';

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
  LatLng? _current;
  String _address = 'Определяем адрес...';
  bool _resolving = false, _locating = false, _busy = false;
  bool _cameraMoving = false;

  @override
  void initState() {
    super.initState();
    _placeSearch = PlaceSearchService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareMap());
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
    setState(() => _current = point);
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

  @override
  void dispose() {
    _camera.stop();
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Место показано на карте. Проверьте точку и подтвердите.',
        ),
      ),
    );
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
    final result = await _placeSearch.reverse(point);
    if (mounted) {
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
    setState(() => _locating = true);
    try {
      final position = await TajGoScope.of(
        context,
      ).locationService.determineCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) {
        return;
      }
      setState(() => _current = point);
      await _moveToCurrent(point);
      await _resolveCenter();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Вы здесь. Точки «Откуда» и «Куда» выберите на карте отдельно.',
            ),
          ),
        );
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

  Future<void> _useMyLocationAsPickup() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await TajGoScope.of(
        context,
      ).locationService.determineCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      final place = await _placeSearch.reverse(point);
      if (!mounted) return;
      setState(() {
        _stage = _Stage.pickFrom;
        _current = point;
        _pendingPlace = place;
        _address = place.address;
      });
      await _moveToCurrent(point);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ваше местоположение показано. Уточните точку и подтвердите.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) await _showLocationError(error);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _confirmPoint() async {
    if (_resolving) {
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
    }
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
      final km = pricing.distanceKm(_from!.toLatLng(), _to!.toLatLng());
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
    final km = _from != null && _to != null
        ? pricing.distanceKm(_from!.toLatLng(), _to!.toLatLng())
        : 0.0;
    return Scaffold(
      body: StreamBuilder<List<TajGoCourier>>(
        stream: repo.onlineCouriersStream(),
        builder: (context, snapshot) {
          final couriers = snapshot.data ?? [];
          return Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 13,
                  minZoom: 3,
                  maxZoom: 19,
                  onMapEvent: (event) {
                    if (event is MapEventMoveEnd &&
                        !_cameraMoving &&
                        _stage != _Stage.details) {
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
                          points: [_from!.toLatLng(), _to!.toLatLng()],
                          color: TajGoColors.green,
                          strokeWidth: 4,
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
                          child: const TajGoCurrentLocationMarker(),
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
              if (_stage != _Stage.details)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Icon(
                      Icons.location_pin,
                      size: 48,
                      color: _stage == _Stage.pickFrom
                          ? TajGoColors.darkGreen
                          : TajGoColors.lime,
                      shadows: const [
                        Shadow(color: TajGoColors.ink, blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              SafeArea(
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: _floatingDecoration(),
                        child: Text(
                          couriers.isEmpty
                              ? 'Пока нет курьеров рядом'
                              : '💚 ${couriers.length} курьеров рядом',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: _stage == _Stage.details ? 330 : 390,
                child: TajGoLocateButton(
                  heroTag: 'newOrderLocate',
                  loading: _locating,
                  onPressed: _locating ? null : _locate,
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _stage == _Stage.details
                    ? _DetailsPanel(
                        from: _from!,
                        to: _to!,
                        type: _type,
                        types: _types,
                        distance: km,
                        eta: pricing.etaMinutes(km),
                        price: _price,
                        comment: _comment,
                        busy: _busy,
                        onType: (value) => setState(() => _type = value),
                        onPrice: (_) => setState(() {}),
                        onEdit: _edit,
                        onSubmit: _createOrder,
                      )
                    : _PointPanel(
                        stage: _stage,
                        from: _from,
                        to: _to,
                        address: _address,
                        approximate: (_pendingPlace?.confidence ?? 1) < 0.7,
                        resolving: _resolving,
                        onConfirm: _confirmPoint,
                        onSearchFrom: () => _showAddressSearch(_Stage.pickFrom),
                        onSearchTo: () => _showAddressSearch(_Stage.pickTo),
                        onUseMyLocation: _useMyLocationAsPickup,
                      ),
              ),
            ],
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
    required this.approximate,
    required this.resolving,
    required this.onConfirm,
    required this.onSearchFrom,
    required this.onSearchTo,
    required this.onUseMyLocation,
  });
  final _Stage stage;
  final TajGoMapLocation? from;
  final TajGoMapLocation? to;
  final String address;
  final bool approximate;
  final bool resolving;
  final VoidCallback onConfirm;
  final VoidCallback onSearchFrom;
  final VoidCallback onSearchTo;
  final VoidCallback onUseMyLocation;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AddressField(
              label: 'Откуда',
              value: stage == _Stage.pickFrom
                  ? address
                  : from?.address ?? 'Моё местоположение / Введите адрес',
              active: stage == _Stage.pickFrom,
              marker: 'A',
              onTap: onSearchFrom,
            ),
            const SizedBox(height: 8),
            _AddressField(
              label: 'Куда',
              value: stage == _Stage.pickTo
                  ? address
                  : to?.address ?? 'Введите адрес или выберите на карте',
              active: stage == _Stage.pickTo,
              marker: 'B',
              onTap: onSearchTo,
            ),
            const SizedBox(height: 14),
            Text(
              stage == _Stage.pickFrom ? 'Откуда забрать?' : 'Куда доставить?',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(address, style: const TextStyle(color: TajGoColors.muted)),
            if (approximate)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Адрес найден приблизительно',
                  style: TextStyle(
                    color: TajGoColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              'Передвиньте карту, чтобы уточнить точку.',
              style: TextStyle(color: TajGoColors.muted, fontSize: 12),
            ),
            if (stage == _Stage.pickFrom) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: onUseMyLocation,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('Использовать моё местоположение'),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: resolving ? null : onConfirm,
              child: Text(
                stage == _Stage.pickFrom
                    ? 'Выбрать как точку забора'
                    : 'Выбрать как точку доставки',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.label,
    required this.value,
    required this.active,
    required this.marker,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool active;
  final String marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEAF4E7) : const Color(0xFFF5F6F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? TajGoColors.green : const Color(0xFFE2E5E3),
        ),
      ),
      child: Row(
        children: [
          _PointBadge(label: marker, active: active),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: TajGoColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Icon(Icons.search_rounded, color: TajGoColors.muted, size: 20),
        ],
      ),
    ),
  );
}

class _PointBadge extends StatelessWidget {
  const _PointBadge({required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: active ? TajGoColors.darkGreen : const Color(0xFFDDE4E0),
      shape: BoxShape.circle,
    ),
    child: Text(
      label,
      style: TextStyle(
        color: active ? Colors.white : TajGoColors.ink,
        fontWeight: FontWeight.w900,
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
    required this.distance,
    required this.eta,
    required this.price,
    required this.comment,
    required this.busy,
    required this.onType,
    required this.onPrice,
    required this.onEdit,
    required this.onSubmit,
  });
  final TajGoMapLocation from, to;
  final String type;
  final Map<String, String> types;
  final double distance;
  final int eta;
  final TextEditingController price;
  final TextEditingController comment;
  final bool busy;
  final ValueChanged<String> onType;
  final ValueChanged<String> onPrice;
  final ValueChanged<_Stage> onEdit;
  final VoidCallback onSubmit;
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
            Text(
              '~$distance км · ~$eta мин',
              style: const TextStyle(color: TajGoColors.muted),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: comment,
              maxLength: 200,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Комментарий курьеру (необязательно)',
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
