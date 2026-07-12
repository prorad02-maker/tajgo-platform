import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tajgo_order.dart';

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
          }.contains(order.status)) {
            return order;
          }
        }
        return null;
      });

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
}
