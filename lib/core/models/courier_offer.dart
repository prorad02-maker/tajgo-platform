import 'package:cloud_firestore/cloud_firestore.dart';

enum CourierOfferStatus { pending, accepted, rejected, expired, withdrawn }

CourierOfferStatus courierOfferStatusFromString(String? value) =>
    switch (value) {
      'accepted' => CourierOfferStatus.accepted,
      'rejected' => CourierOfferStatus.rejected,
      'expired' => CourierOfferStatus.expired,
      'withdrawn' => CourierOfferStatus.withdrawn,
      _ => CourierOfferStatus.pending,
    };

class CourierOffer {
  const CourierOffer({
    required this.id,
    required this.orderId,
    required this.courierId,
    required this.courierName,
    required this.courierRating,
    required this.courierTransport,
    required this.courierDistanceMeters,
    required this.proposedPrice,
    required this.originalClientPrice,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
  });

  final String id;
  final String orderId;
  final String courierId;
  final String courierName;
  final double courierRating;
  final String courierTransport;
  final double courierDistanceMeters;
  final num proposedPrice;
  final num originalClientPrice;
  final CourierOfferStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  bool get isActive =>
      status == CourierOfferStatus.pending &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory CourierOffer.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String orderId,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    DateTime? date(String key) => switch (data[key]) {
      Timestamp value => value.toDate(),
      DateTime value => value,
      _ => null,
    };
    return CourierOffer(
      id: doc.id,
      orderId: orderId,
      courierId: data['courierId'] as String? ?? doc.id,
      courierName: data['courierName'] as String? ?? 'Курьер',
      courierRating: (data['courierRating'] as num? ?? 5).toDouble(),
      courierTransport: data['courierTransport'] as String? ?? 'bicycle',
      courierDistanceMeters: (data['courierDistanceMeters'] as num? ?? 0)
          .toDouble(),
      proposedPrice: data['proposedPrice'] as num? ?? 0,
      originalClientPrice: data['originalClientPrice'] as num? ?? 0,
      status: courierOfferStatusFromString(data['status'] as String?),
      createdAt: date('createdAt'),
      updatedAt: date('updatedAt'),
      expiresAt: date('expiresAt'),
    );
  }
}
