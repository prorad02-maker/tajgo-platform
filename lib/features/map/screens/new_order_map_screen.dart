import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/tajgo_colors.dart';
import '../../../core/models/tajgo_courier.dart';
import '../../../core/services/pricing.dart' as pricing;
import '../../../shared/widgets/tajgo_scope.dart';
import '../models/tajgo_map_location.dart';

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
  final _price = TextEditingController();
  _Stage _stage = _Stage.pickFrom;
  late String _type = widget.initialType;
  TajGoMapLocation? _from, _to;
  LatLng? _current;
  String _address = 'Определяем адрес...';
  bool _resolving = false, _locating = false, _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveCenter());
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
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
    final result = await TajGoScope.of(context).locationService.reverseGeocode(
      latitude: point.latitude,
      longitude: point.longitude,
    );
    if (mounted) {
      setState(() {
        _address = result.address;
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
      _map.move(point, 16);
      await _resolveCenter();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
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
    if (_stage == _Stage.pickFrom) {
      setState(() {
        _from = location;
        _stage = _Stage.pickTo;
        _address = 'Определяем адрес...';
      });
      await _resolveCenter();
    } else {
      setState(() {
        _to = location;
        _stage = _Stage.details;
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
      await scope.orderRepository.createOrder(
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
      );
      if (mounted) {
        Navigator.pop(context);
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
                    if (event is MapEventMoveEnd && _stage != _Stage.details) {
                      _resolveCenter();
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.tajgo',
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
                          width: 36,
                          height: 36,
                          child: const _CurrentDot(),
                        ),
                      if (_from != null && _stage != _Stage.pickFrom)
                        Marker(
                          point: _from!.toLatLng(),
                          width: 42,
                          height: 42,
                          child: const Icon(
                            Icons.location_pin,
                            color: TajGoColors.darkGreen,
                            size: 42,
                          ),
                        ),
                      if (_to != null && _stage == _Stage.details)
                        Marker(
                          point: _to!.toLatLng(),
                          width: 42,
                          height: 42,
                          child: const Icon(
                            Icons.location_pin,
                            color: TajGoColors.lime,
                            size: 42,
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
                bottom: _stage == _Stage.details ? 330 : 220,
                child: _RoundButton(
                  icon: _locating ? Icons.hourglass_top : Icons.my_location,
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
                        busy: _busy,
                        onType: (value) => setState(() => _type = value),
                        onPrice: (_) => setState(() {}),
                        onEdit: _edit,
                        onSubmit: _createOrder,
                      )
                    : _PointPanel(
                        stage: _stage,
                        address: _address,
                        resolving: _resolving,
                        onConfirm: _confirmPoint,
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
    required this.address,
    required this.resolving,
    required this.onConfirm,
  });
  final _Stage stage;
  final String address;
  final bool resolving;
  final VoidCallback onConfirm;
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
            Text(
              stage == _Stage.pickFrom ? 'Откуда забрать?' : 'Куда доставить?',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(address, style: const TextStyle(color: TajGoColors.muted)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: resolving ? null : onConfirm,
              child: const Text('Подтвердить точку'),
            ),
          ],
        ),
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
      child: Padding(
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

class _CurrentDot extends StatelessWidget {
  const _CurrentDot();
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.blue,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 4),
    ),
  );
}
