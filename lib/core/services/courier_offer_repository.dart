import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/courier_offer.dart';
import 'authoritative_command_service.dart';

class CourierOfferRepository {
  CourierOfferRepository(this._db, this._commands);

  final FirebaseFirestore _db;
  final AuthoritativeCommandService _commands;

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
    String? idempotencyKey,
  }) async {
    await _commands.call('submitCourierOffer', {
      'orderId': orderId,
      'proposedPrice': proposedPrice.toInt(),
      'idempotencyKey':
          idempotencyKey ??
          TajGoIdempotencyKey.create('submit-offer-$orderId-$courierId'),
    });
  }

  Future<void> updateCourierOffer({
    required String orderId,
    required String courierId,
    required num proposedPrice,
    String? idempotencyKey,
  }) async {
    await _commands.call('updateCourierOffer', {
      'orderId': orderId,
      'proposedPrice': proposedPrice.toInt(),
      'idempotencyKey':
          idempotencyKey ??
          TajGoIdempotencyKey.create('update-offer-$orderId-$courierId'),
    });
  }

  Future<void> withdrawCourierOffer({
    required String orderId,
    required String courierId,
  }) async {
    await _commands.call('withdrawCourierOffer', {
      'orderId': orderId,
      'idempotencyKey': TajGoIdempotencyKey.stable('withdraw-offer', [
        orderId,
        courierId,
      ]),
    });
  }

  Future<void> rejectCourierOffer({
    required String orderId,
    required String offerId,
    required String customerId,
  }) async {
    await _commands.call('rejectCourierOffer', {
      'orderId': orderId,
      'offerId': offerId,
      'idempotencyKey': TajGoIdempotencyKey.stable('reject-offer', [
        orderId,
        offerId,
        customerId,
      ]),
    });
  }

  Future<void> selectCourierOffer({
    required String orderId,
    required String offerId,
    required String customerId,
  }) async {
    await _commands.call('selectCourierOffer', {
      'orderId': orderId,
      'offerId': offerId,
      'idempotencyKey': TajGoIdempotencyKey.stable('select-offer', [
        orderId,
        offerId,
        customerId,
      ]),
    });
  }
}

bool isWaitingOrderStatus(String? status) =>
    status == null ||
    status == 'draft' ||
    status == 'waiting' ||
    status == 'waitingOffers';

bool isCourierOfferPriceValid({
  required num proposedPrice,
  required num clientPrice,
  bool priceNegotiable = true,
}) =>
    proposedPrice == proposedPrice.roundToDouble() &&
    (priceNegotiable
        ? proposedPrice >= clientPrice
        : proposedPrice == clientPrice);

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
