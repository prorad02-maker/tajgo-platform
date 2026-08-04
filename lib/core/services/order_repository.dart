import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tajgo_order.dart';
import 'authoritative_command_service.dart';

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
  });

  final String status;
  final bool authoritative;
  final String? quoteId;
  final int? priceTjs;
  final DateTime? expiresAt;
  final String? confidence;
  final String? source;
  final String? reason;

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
      .orderBy('createdAt', descending: true)
      .limit(5)
      .snapshots()
      .map((snapshot) {
        final orders = snapshot.docs.map(TajGoOrder.fromDoc).toList();
        for (final order in orders) {
          if ({
            OrderStatus.waiting,
            OrderStatus.accepted,
            OrderStatus.pickedUp,
            OrderStatus.delivered,
            OrderStatus.disputed,
          }.contains(order.status)) {
            return order;
          }
        }
        return null;
      });

  Future<bool> hasActiveOrder(String customerId) async {
    final snapshot = await _db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();
    return snapshot.docs
        .map(TajGoOrder.fromDoc)
        .any(
          (order) => const {
            OrderStatus.waiting,
            OrderStatus.accepted,
            OrderStatus.pickedUp,
            OrderStatus.delivered,
            OrderStatus.disputed,
          }.contains(order.status),
        );
  }

  /// Один заказ по id — для экрана отслеживания.
  Stream<TajGoOrder?> orderStream(String orderId) => _db
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((doc) => doc.exists ? TajGoOrder.fromDoc(doc) : null);

  Stream<String?> customerDeliveryCodeStream(String orderId) => _db
      .collection('order_customer_codes')
      .doc(orderId)
      .snapshots()
      .map((doc) => doc.data()?['code'] as String?);

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
