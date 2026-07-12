import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_courier.dart';
import '../../core/models/tajgo_order.dart';
import '../../shared/widgets/tajgo_action_button.dart';
import '../../shared/widgets/tajgo_confirmation_code.dart';
import '../../shared/widgets/tajgo_courier_banner.dart';
import '../../shared/widgets/tajgo_order_progress.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../../shared/widgets/tajgo_status_header.dart';

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
  bool _fitted = false;
  bool _busy = false;
  bool _showBanner = false;
  bool _popScheduled = false;
  OrderStatus? _lastStatus;
  Timer? _bannerTimer;
  Timer? _completedTimer;

  @override
  void dispose() {
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

  int _step(TajGoOrder order) => switch (order.status) {
    OrderStatus.waiting => 0,
    OrderStatus.accepted => 1,
    OrderStatus.pickedUp => 2,
    _ => 3,
  };

  String _title(TajGoOrder order) => switch (order.status) {
    OrderStatus.waiting => '🔎 Ищем курьера…',
    OrderStatus.accepted when order.arrivedAtPickupAt != null =>
      '📍 Курьер на месте забора',
    OrderStatus.accepted => '🚴 Курьер найден!',
    OrderStatus.pickedUp => '📦 Заказ у курьера',
    OrderStatus.delivered => 'Курьер передал заказ?',
    OrderStatus.completed => '✅ Доставлено. Спасибо!',
    OrderStatus.disputed => '⚠️ Мы разбираемся',
    OrderStatus.cancelled => 'Заказ отменён',
  };

  String? _subtitle(TajGoOrder order) => switch (order.status) {
    OrderStatus.waiting => 'Обычно это занимает пару минут',
    OrderStatus.accepted when order.arrivedAtPickupAt == null =>
      'Курьер едет к точке забора',
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
    final courierPoint = courier?.location == null
        ? null
        : LatLng(courier!.location!.latitude, courier.location!.longitude);
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
                    userAgentPackageName: 'com.example.tajgo',
                    maxZoom: 19,
                  ),
                  if (from != null && to != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [from, to],
                          color: TajGoColors.green,
                          strokeWidth: 4,
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
                      if (courierPoint != null)
                        Marker(
                          point: courierPoint,
                          width: 22,
                          height: 22,
                          child: const _CourierDot(),
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
          title: _title(order),
          subtitle: _subtitle(order),
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

  @override
  Widget build(BuildContext context) => Material(
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
            TajGoOrderProgress(
              currentStep: step,
              labels: const ['Поиск', 'Принят', 'Забрал', 'Доставлено'],
            ),
            const SizedBox(height: 14),
            TajGoStatusHeader(title: title, subtitle: subtitle),
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
            if ((order.comment ?? '').isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                '💬 ${order.comment}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: TajGoColors.muted, fontSize: 13),
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
