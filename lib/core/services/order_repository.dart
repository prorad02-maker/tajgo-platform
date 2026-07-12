import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tajgo_order.dart';
import 'pricing.dart';

class OrderRepository {
  OrderRepository(this._db);
  final FirebaseFirestore _db;

  Future<String> createOrder({
    required String customerId,
    required String customerName,
    required String fromText,
    required String toText,
    required String type,
    required num price,
    GeoPoint? fromLocation,
    GeoPoint? toLocation,
    num? distanceKm,
    int? etaMinutes,
    String? comment,
  }) async {
    final ref = _db.collection('orders').doc();
    final order = TajGoOrder(
      id: ref.id,
      customerId: customerId,
      customerName: customerName,
      status: OrderStatus.waiting,
      type: type,
      city: 'Худжанд',
      fromText: fromText,
      toText: toText,
      price: price,
      currency: 'TJS',
      fromLocation: fromLocation,
      toLocation: toLocation,
      distanceKm: distanceKm,
      etaMinutes: etaMinutes,
      confirmationCode: generateConfirmationCode(),
      comment: comment,
    );
    await ref.set(order.toCreateMap());
    return ref.id;
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

  /// Один заказ по id — для экрана отслеживания.
  Stream<TajGoOrder?> orderStream(String orderId) => _db
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((doc) => doc.exists ? TajGoOrder.fromDoc(doc) : null);

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

  Future<void> cancelOrder(String orderId) =>
      _db.runTransaction((transaction) async {
        final ref = _db.collection('orders').doc(orderId);
        final doc = await transaction.get(ref);
        if (doc.data()?['status'] != 'waiting') {
          throw StateError('Отменить можно только ожидающий заказ.');
        }
        transaction.update(ref, {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  Future<void> confirmReceived(String orderId) =>
      _db.runTransaction((transaction) async {
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
          'earningsToday': FieldValue.increment((data?['price'] ?? 0) as num),
          'ordersToday': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  Future<void> reportNotReceived(String orderId) =>
      _db.runTransaction((transaction) async {
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
      });
}
