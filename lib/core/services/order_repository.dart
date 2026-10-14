import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../features/map/models/tajgo_route.dart';

import '../models/tajgo_order.dart';
import 'authoritative_command_service.dart';
import '../../features/map/models/tajgo_map_location.dart';

class ServerDeliveryQuote {
  const ServerDeliveryQuote({
    required this.status,
    required this.authoritative,
    this.quoteId,
    this.priceTjs,
    this.expiresAt,
    this.confidence,
    this.source,
    this.reason,
    this.distanceMeters,
    this.durationSeconds,
    this.routeSource,
    this.geometry = const [],
  });

  final String status;
  final bool authoritative;
  final String? quoteId;
  final int? priceTjs;
  final DateTime? expiresAt;
  final String? confidence;
  final String? source;
  final String? reason;
  final double? distanceMeters, durationSeconds;
  final String? routeSource;
  final List<GeoPoint> geometry;
  TajGoRoute? roadRoute(GeoPoint pickup, GeoPoint dropoff) {
    final distance = distanceMeters, duration = durationSeconds;
    if (geometry.length < 2 ||
        distance == null ||
        duration == null ||
        !distance.isFinite ||
        !duration.isFinite ||
        distance <= 0 ||
        duration <= 0) {
      return null;
    }
    final points = geometry
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    const measure = Distance();
    if (measure.as(
              LengthUnit.Meter,
              points.first,
              LatLng(pickup.latitude, pickup.longitude),
            ) >
            500 ||
        measure.as(
              LengthUnit.Meter,
              points.last,
              LatLng(dropoff.latitude, dropoff.longitude),
            ) >
            500) {
      return null;
    }
    return TajGoRoute(
      points: points,
      distanceKm: distance / 1000,
      etaMinutes: (duration / 60).ceil(),
      isRoadRouteApproximation: false,
      providerName: routeSource ?? 'server-road',
      routeQuality: RouteQuality.road,
      createdAt: DateTime.now(),
    );
  }

  static List<GeoPoint> parseGeometry(Object? value) {
    if (value is! List || value.length < 2 || value.length > 4096) {
      return const [];
    }
    final points = <GeoPoint>[];
    for (final point in value) {
      if (point is! Map ||
          point['latitude'] is! num ||
          point['longitude'] is! num) {
        return const [];
      }
      final lat = (point['latitude'] as num).toDouble(),
          lon = (point['longitude'] as num).toDouble();
      if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
        return const [];
      }
      points.add(GeoPoint(lat, lon));
    }
    return points;
  }

  bool get ready =>
      status == 'ready' &&
      authoritative &&
      quoteId?.isNotEmpty == true &&
      priceTjs != null &&
      expiresAt?.isAfter(DateTime.now().toUtc()) == true;
}

class OrderRepository {
  OrderRepository(this._db, this._commands);
  final FirebaseFirestore _db;
  final AuthoritativeCommandService _commands;
  Future<String> orderContact(String orderId) async {
    final result = await _commands.call('getOrderContact', {
      'orderId': orderId,
    });
    final phone = result['phoneNumber'];
    if (phone is! String || !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      throw StateError('Номер получателя недоступен. Обратитесь в поддержку.');
    }
    return phone;
  }

  Future<ServerDeliveryQuote> requestDeliveryQuote({
    required GeoPoint pickup,
    required GeoPoint dropoff,
    required String cityId,
    required String transportMode,
  }) async {
    final result = await _commands.call('getDeliveryQuote', {
      'pickup': {'latitude': pickup.latitude, 'longitude': pickup.longitude},
      'dropoff': {'latitude': dropoff.latitude, 'longitude': dropoff.longitude},
      'cityId': cityId,
      'transportMode': transportMode,
    });
    return ServerDeliveryQuote(
      status: result['status'] as String? ?? 'degraded',
      authoritative: result['authoritative'] == true,
      quoteId: result['quoteId'] as String?,
      priceTjs: (result['priceTjs'] as num?)?.round(),
      expiresAt: DateTime.tryParse(
        result['expiresAt'] as String? ?? '',
      )?.toUtc(),
      confidence: result['confidence'] as String?,
      source: result['source'] as String?,
      reason: result['reason'] as String?,
      distanceMeters: (result['distanceMeters'] as num?)?.toDouble(),
      durationSeconds: (result['durationSeconds'] as num?)?.toDouble(),
      routeSource: result['routeSource'] as String?,
      geometry: ServerDeliveryQuote.parseGeometry(result['geometry']),
    );
  }

  Future<String> createOrder({
    required String customerId,
    required String customerName,
    required String fromText,
    required String toText,
    required String type,
    required num price,
    num? suggestedPrice,
    num? clientPrice,
    String orderType = 'customDelivery',
    bool priceNegotiable = true,
    GeoPoint? fromLocation,
    GeoPoint? toLocation,
    TajGoMapLocation? pickup,
    TajGoMapLocation? dropoff,
    num? distanceKm,
    int? etaMinutes,
    String? comment,
    bool isTestOrder = false,
    String? idempotencyKey,
    required String quoteId,
  }) async {
    if (isTestOrder) {
      throw StateError('Тестовые заказы создаются только в Firebase Emulator.');
    }
    if (orderType != 'customDelivery') {
      throw ArgumentError.value(orderType, 'orderType');
    }
    pickup?.validate();
    dropoff?.validate();
    fromLocation = pickup?.toGeoPoint() ?? fromLocation;
    toLocation = dropoff?.toGeoPoint() ?? toLocation;
    fromText = pickup?.address.trim() ?? fromText.trim();
    toText = dropoff?.address.trim() ?? toText.trim();
    if (fromLocation == null || toLocation == null) {
      throw StateError('Укажите точки A и B на карте.');
    }
    final result = await _commands.call('createCustomDeliveryOrder', {
      'idempotencyKey':
          idempotencyKey ??
          TajGoIdempotencyKey.create('create-custom-$customerId'),
      'quoteId': quoteId,
      'fromText': fromText,
      'toText': toText,
      'type': type,
      'clientPrice': (clientPrice ?? price).toInt(),
      'suggestedPrice': (suggestedPrice ?? price).toInt(),
      'priceNegotiable': priceNegotiable,
      'fromLocation': {
        'latitude': fromLocation.latitude,
        'longitude': fromLocation.longitude,
      },
      'toLocation': {
        'latitude': toLocation.latitude,
        'longitude': toLocation.longitude,
      },
      'clientDistanceKm': ?distanceKm,
      'clientEtaMinutes': ?etaMinutes,
      if (comment?.trim().isNotEmpty == true) 'comment': comment!.trim(),
    });
    final orderId = result['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) {
      throw const TajGoCommandException(
        code: 'aborted',
        message: 'TajGo не вернул номер заказа. Повторите запрос.',
        retryable: true,
      );
    }
    return orderId;
  }

  Stream<TajGoOrder?> activeOrderStream(String customerId) => _db
      .collection('orders')
      .where('customerId', isEqualTo: customerId)
      .where(
        'status',
        whereIn: const [
          'draft',
          'waiting',
          'waitingOffers',
          'courierSelected',
          'accepted',
          'arrivedPickup',
          'pickedUp',
          'arrivedDropoff',
          'delivered',
          'disputed',
        ],
      )
      .snapshots()
      .map((snapshot) {
        final orders = snapshot.docs.map(TajGoOrder.fromDoc).toList();
        for (final order in orders) {
          if (order.isActive) {
            return order;
          }
        }
        return null;
      });

  Future<bool> hasActiveOrder(String customerId) async {
    final snapshot = await _db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .where(
          'status',
          whereIn: const [
            'draft',
            'waiting',
            'waitingOffers',
            'courierSelected',
            'accepted',
            'arrivedPickup',
            'pickedUp',
            'arrivedDropoff',
            'delivered',
            'disputed',
          ],
        )
        .get();
    return snapshot.docs.map(TajGoOrder.fromDoc).any((order) => order.isActive);
  }

  /// Один заказ по id — для экрана отслеживания.
  Stream<TajGoOrder?> orderStream(String orderId) => _db
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((doc) => doc.exists ? TajGoOrder.fromDoc(doc) : null);

  Stream<String?> customerDeliveryCodeStream(
    String orderId, {
    bool serverV1 = false,
  }) => _db
      .collection(serverV1 ? 'order_receipts' : 'order_customer_codes')
      .doc(orderId)
      .snapshots()
      .map(
        (doc) => doc.data()?[serverV1 ? 'confirmationCode' : 'code'] as String?,
      );
  Stream<List<TajGoOrder>> historyStream(String customerId) =>
      customerOrdersStream(customerId, limit: 100);

  /// Последние завершённые заказы клиента для секции «Мои заказы».
  /// Тот же запрос, что у activeOrderStream, — составной индекс не нужен.
  Stream<List<TajGoOrder>> recentOrdersStream(String customerId) => _db
      .collection('orders')
      .where('customerId', isEqualTo: customerId)
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(TajGoOrder.fromDoc)
            .where(
              (order) => const {
                OrderStatus.completed,
                OrderStatus.cancelled,
                OrderStatus.disputed,
              }.contains(order.status),
            )
            .take(5)
            .toList(),
      );

  /// Все заказы клиента (для полной вкладки «Заказы» с фильтрами).
  /// Использует индекс orders(customerId ASC, createdAt DESC).
  Stream<List<TajGoOrder>> customerOrdersStream(
    String customerId, {
    int limit = 50,
  }) => _db
      .collection('orders')
      .where('customerId', isEqualTo: customerId)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(TajGoOrder.fromDoc).toList(growable: false),
      );

  Future<void> cancelOrder(String orderId) async {
    await _commands.call('cancelWaitingOrder', {
      'orderId': orderId,
      'idempotencyKey': TajGoIdempotencyKey.stable('cancel-order', [orderId]),
    });
  }

  Future<void> confirmReceived(String orderId) async {
    await _commands.call('updateDeliveryStatus', {
      'orderId': orderId,
      'action': 'customerConfirm',
      'idempotencyKey': TajGoIdempotencyKey.stable('customer-confirm', [
        orderId,
      ]),
    });
  }

  Future<void> reportNotReceived(String orderId) async {
    await _commands.call('updateDeliveryStatus', {
      'orderId': orderId,
      'action': 'customerDispute',
      'idempotencyKey': TajGoIdempotencyKey.stable('customer-dispute', [
        orderId,
      ]),
    });
  }
}
