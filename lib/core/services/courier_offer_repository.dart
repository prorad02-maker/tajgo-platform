import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../models/courier_offer.dart';
import 'courier_order_eligibility.dart';

class CourierOfferRepository {
  CourierOfferRepository(
    this._db, {
    CourierOrderEligibilityService? eligibility,
  }) : _eligibility = eligibility ?? const CourierOrderEligibilityService();

  final FirebaseFirestore _db;
  final CourierOrderEligibilityService _eligibility;

  Stream<List<CourierOffer>> offersStream(String orderId) => _db
      .collection('orders')
      .doc(orderId)
      .collection('offers')
      .orderBy('createdAt')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => CourierOffer.fromDoc(doc, orderId: orderId))
            .where((offer) => offer.status != CourierOfferStatus.withdrawn)
            .toList(growable: false),
      );

  Future<void> submitCourierOffer({
    required String orderId,
    required String courierId,
    required num proposedPrice,
  }) => _db.runTransaction((transaction) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final courierRef = _db.collection('couriers').doc(courierId);
    final offerRef = orderRef.collection('offers').doc(courierId);
    final snapshots = await Future.wait([
      transaction.get(orderRef),
      transaction.get(courierRef),
      transaction.get(offerRef),
    ]);
    final order = snapshots[0].data();
    final courier = snapshots[1].data();
    if (order == null || courier == null) {
      throw StateError('Заказ или профиль курьера не найден.');
    }
    if (!isWaitingOrderStatus(order['status'] as String?)) {
      throw StateError('Заказ уже недоступен для предложений.');
    }
    if (order['courierId'] != null || order['selectedCourierId'] != null) {
      throw StateError('Клиент уже выбрал курьера.');
    }

    final clientPrice =
        order['clientPrice'] as num? ?? order['price'] as num? ?? 0;
    if (!isCourierOfferPriceValid(
      proposedPrice: proposedPrice,
      clientPrice: clientPrice,
    )) {
      throw StateError('Предложение не может быть ниже цены клиента.');
    }
    final pickup = order['fromLocation'] as GeoPoint?;
    final location = courier['location'] as GeoPoint?;
    if (pickup == null) throw StateError('У заказа не указана точка забора.');
    final result = _eligibility.evaluate(
      courierLocation: location == null
          ? null
          : LatLng(location.latitude, location.longitude),
      locationUpdatedAt: _date(courier['locationUpdatedAt']),
      accuracyMeters: (courier['locationAccuracy'] as num?)?.toDouble(),
      pickup: LatLng(pickup.latitude, pickup.longitude),
      hasActiveOrder:
          courier['activeOrderId'] != null || courier['isBusy'] == true,
    );
    if (!result.allowed) throw StateError(result.message);

    final previous = snapshots[2].data();
    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(minutes: 5)),
    );
    transaction.set(offerRef, {
      'courierId': courierId,
      'courierName':
          courier['displayName'] as String? ??
          courier['name'] as String? ??
          'Курьер',
      'courierRating': courier['rating'] as num? ?? 5,
      'courierTransport': courier['transport'] as String? ?? 'bicycle',
      'courierDistanceMeters': result.distanceMeters?.round() ?? 0,
      'proposedPrice': proposedPrice,
      'originalClientPrice': clientPrice,
      'status': 'pending',
      'createdAt': previous?['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
      'isTest': order['isTest'] == true || order['isTestOrder'] == true,
    }, SetOptions(merge: true));
    if (shouldIncrementOffersCount(previous?['status'] as String?)) {
      transaction.update(orderRef, {
        'offersCount': FieldValue.increment(1),
        'offerExpiresAt': expiresAt,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  });

  Future<void> withdrawCourierOffer({
    required String orderId,
    required String courierId,
  }) => _db
      .collection('orders')
      .doc(orderId)
      .collection('offers')
      .doc(courierId)
      .update({
        'status': 'withdrawn',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> rejectCourierOffer({
    required String orderId,
    required String offerId,
    required String customerId,
  }) => _db.runTransaction((transaction) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final offerRef = orderRef.collection('offers').doc(offerId);
    final order = await transaction.get(orderRef);
    final offer = await transaction.get(offerRef);
    if (order.data()?['customerId'] != customerId) {
      throw StateError('Отклонять предложения может только клиент заказа.');
    }
    if (offer.data()?['status'] != 'pending') return;
    transaction.update(offerRef, {
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  Future<void> selectCourierOffer({
    required String orderId,
    required String offerId,
    required String customerId,
  }) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final offerRefs = (await orderRef.collection('offers').get()).docs
        .map((doc) => doc.reference)
        .toList(growable: false);
    final selectedRef = orderRef.collection('offers').doc(offerId);
    await _db.runTransaction((transaction) async {
      final orderDoc = await transaction.get(orderRef);
      final offerDoc = await transaction.get(selectedRef);
      final order = orderDoc.data();
      final offer = offerDoc.data();
      if (order == null || offer == null) {
        throw StateError('Предложение больше недоступно.');
      }
      if (order['customerId'] != customerId) {
        throw StateError('Выбирать курьера может только клиент заказа.');
      }
      if (!isWaitingOrderStatus(order['status'] as String?) ||
          order['selectedCourierId'] != null ||
          offer['status'] != 'pending') {
        throw StateError('Курьер уже выбран или предложение устарело.');
      }
      final expiresAt = _date(offer['expiresAt']);
      if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
        throw StateError('Срок предложения истёк.');
      }
      final courierId = offer['courierId'] as String? ?? offerId;
      final courierRef = _db.collection('couriers').doc(courierId);
      final courierDoc = await transaction.get(courierRef);
      final courier = courierDoc.data();
      if (courier == null) throw StateError('Профиль курьера не найден.');
      final otherOffers = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in offerRefs) {
        if (ref.path != selectedRef.path) {
          otherOffers.add(await transaction.get(ref));
        }
      }
      final pickup = order['fromLocation'] as GeoPoint?;
      final location = courier['location'] as GeoPoint?;
      if (pickup == null) throw StateError('У заказа не указана точка забора.');
      final result = _eligibility.evaluate(
        courierLocation: location == null
            ? null
            : LatLng(location.latitude, location.longitude),
        locationUpdatedAt: _date(courier['locationUpdatedAt']),
        accuracyMeters: (courier['locationAccuracy'] as num?)?.toDouble(),
        pickup: LatLng(pickup.latitude, pickup.longitude),
        hasActiveOrder:
            courier['activeOrderId'] != null || courier['isBusy'] == true,
      );
      if (!result.allowed) throw StateError(result.message);

      for (final other in otherOffers) {
        if (other.data()?['status'] == 'pending') {
          transaction.update(other.reference, {
            'status': 'rejected',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      final finalPrice =
          offer['proposedPrice'] as num? ?? order['clientPrice'] as num?;
      transaction.update(selectedRef, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(orderRef, {
        'status': 'accepted',
        'courierId': courierId,
        'selectedCourierId': courierId,
        'selectedOfferId': offerId,
        'finalPrice': finalPrice,
        'price': finalPrice,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(courierRef, {
        'activeOrderId': orderId,
        'isBusy': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  static DateTime? _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };
}

bool isWaitingOrderStatus(String? status) =>
    status == null ||
    status == 'draft' ||
    status == 'waiting' ||
    status == 'waitingOffers';

bool isCourierOfferPriceValid({
  required num proposedPrice,
  required num clientPrice,
}) => proposedPrice >= clientPrice;

bool shouldIncrementOffersCount(String? previousStatus) =>
    previousStatus != 'pending';

bool canSelectCourierOffer({
  required String? orderStatus,
  required CourierOfferStatus offerStatus,
  required bool courierBusy,
  required bool expired,
}) =>
    isWaitingOrderStatus(orderStatus) &&
    offerStatus == CourierOfferStatus.pending &&
    !courierBusy &&
    !expired;

CourierOfferStatus offerStatusAfterSelection({
  required CourierOfferStatus current,
  required bool selected,
}) {
  if (current != CourierOfferStatus.pending) return current;
  return selected ? CourierOfferStatus.accepted : CourierOfferStatus.rejected;
}
