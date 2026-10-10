import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tajgo_order.dart';
import '../../features/map/models/tajgo_map_location.dart';
import 'pricing.dart';
import 'order_command_service.dart';

class OrderRepository {
  OrderRepository(this._db, {OrderCommandService? commands})
    // Public injection name deliberately differs from the private field.
    // ignore: prefer_initializing_formals
    : _commands = commands;
  final FirebaseFirestore _db;
  final OrderCommandService? _commands;

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
  }) async {
    pickup?.validate();
    dropoff?.validate();
    if (_commands?.enabled == true) {
      final origin =
          pickup ??
          (fromLocation == null
              ? null
              : TajGoMapLocation.fromGeoPoint(fromLocation, address: fromText));
      final destination =
          dropoff ??
          (toLocation == null
              ? null
              : TajGoMapLocation.fromGeoPoint(toLocation, address: toText));
      if (origin == null || destination == null) {
        throw StateError('Выберите адреса на карте.');
      }
      origin.validate();
      destination.validate();
      final result = await _commands!.run('create', {
        'pickup': origin.toMap(),
        'dropoff': destination.toMap(),
        'price': price,
        'comment': comment ?? '',
      });
      return result['orderId'] as String;
    }
    final ref = _db.collection('orders').doc();
    final order = TajGoOrder(
      id: ref.id,
      customerId: customerId,
      customerName: customerName,
      status: OrderStatus.waiting,
      type: type,
      city: 'Худжанд',
      fromText: pickup?.address ?? fromText,
      toText: dropoff?.address ?? toText,
      price: price,
      currency: 'TJS',
      fromLocation: pickup?.toGeoPoint() ?? fromLocation,
      toLocation: dropoff?.toGeoPoint() ?? toLocation,
      distanceKm: distanceKm,
      etaMinutes: etaMinutes,
      confirmationCode: generateConfirmationCode(),
      comment: comment,
      isTestOrder: isTestOrder,
      orderType: orderType,
      suggestedPrice: suggestedPrice ?? price,
      clientPrice: clientPrice ?? price,
      priceNegotiable: priceNegotiable,
      pricingVersion: 'v2',
    );
    await ref.set(order.toCreateMap());
    return ref.id;
  }

  Stream<TajGoOrder?> activeOrderStream(String customerId) => _db
      .collection('orders')
      .where('customerId', isEqualTo: customerId)
      .where(
        'status',
        whereIn: const [
          'waiting',
          'waitingOffers',
          'accepted',
          'pickedUp',
          'delivered',
          'disputed',
        ],
      )
      .snapshots()
      .map((snapshot) {
        final orders =
            snapshot.docs
                .map(TajGoOrder.fromDoc)
                .where((order) => order.isActive)
                .toList()
              ..sort(
                (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
                  a.createdAt ?? DateTime(1970),
                ),
              );
        return orders.firstOrNull;
      });

  Future<bool> hasActiveOrder(String customerId) async {
    final snapshot = await _db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .where(
          'status',
          whereIn: const [
            'waiting',
            'waitingOffers',
            'accepted',
            'pickedUp',
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

  Stream<String?> receiptCodeStream(String orderId) => _db
      .collection('order_receipts')
      .doc(orderId)
      .snapshots()
      .map((doc) => doc.data()?['confirmationCode'] as String?);

  Future<void> _mutation(
    String orderId,
    String action,
    Future<void> Function() legacy,
  ) async {
    if (_commands != null && await _commands.handlesOrder(_db, orderId)) {
      await _commands.run(action, {'orderId': orderId});
    } else {
      await legacy();
    }
  }

  /// Последние завершённые заказы клиента для секции «Мои заказы».
  /// Uses the customerId/createdAt index shared with the full history.
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

  Stream<List<TajGoOrder>> historyStream(String customerId) => _db
      .collection('orders')
      .where('customerId', isEqualTo: customerId)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(TajGoOrder.fromDoc).toList());

  Future<void> cancelOrder(String orderId) => _mutation(
    orderId,
    'cancel',
    () => _db.runTransaction((transaction) async {
      final ref = _db.collection('orders').doc(orderId);
      final doc = await transaction.get(ref);
      if (!{'waiting', 'waitingOffers'}.contains(doc.data()?['status'])) {
        throw StateError('Отменить можно только ожидающий заказ.');
      }
      transaction.update(ref, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }),
  );

  Future<void> confirmReceived(String orderId) => _mutation(
    orderId,
    'confirm',
    () => _db.runTransaction((transaction) async {
      final orderRef = _db.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);
      final data = orderDoc.data();
      if (data?['status'] != 'delivered') {
        throw StateError('Заказ ещё не ожидает подтверждения получения.');
      }
      final courierId = data?['courierId'] as String?;
      if (courierId == null) {
        throw StateError('У заказа не указан курьер.');
      }
      transaction.update(orderRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(_db.collection('couriers').doc(courierId), {
        'activeOrderId': null,
        'isBusy': false,
        'earningsToday': FieldValue.increment((data?['price'] ?? 0) as num),
        'ordersToday': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }),
  );

  Future<void> reportNotReceived(String orderId) => _mutation(
    orderId,
    'dispute',
    () => _db.runTransaction((transaction) async {
      final orderRef = _db.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);
      if (orderDoc.data()?['status'] != 'delivered') {
        throw StateError('Заказ ещё не ожидает подтверждения получения.');
      }
      transaction.update(orderRef, {
        'status': 'disputed',
        'disputedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }),
  );
}
