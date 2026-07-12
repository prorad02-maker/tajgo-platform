import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus { waiting, accepted, pickedUp, delivered, cancelled }

OrderStatus orderStatusFromString(String? value) {
  return switch (value) {
    'accepted' => OrderStatus.accepted,
    'pickedUp' => OrderStatus.pickedUp,
    'delivered' => OrderStatus.delivered,
    'cancelled' => OrderStatus.cancelled,
    _ => OrderStatus.waiting,
  };
}

String orderStatusToString(OrderStatus status) => switch (status) {
  OrderStatus.waiting => 'waiting',
  OrderStatus.accepted => 'accepted',
  OrderStatus.pickedUp => 'pickedUp',
  OrderStatus.delivered => 'delivered',
  OrderStatus.cancelled => 'cancelled',
};

class TajGoOrder {
  const TajGoOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.courierId,
    required this.status,
    required this.type,
    required this.city,
    required this.fromText,
    required this.toText,
    required this.price,
    required this.currency,
    this.distanceKm,
    this.etaMinutes,
    this.fromLocation,
    this.toLocation,
    this.declinedBy = const [],
    this.createdAt,
    this.acceptedAt,
    this.updatedAt,
  });

  final String id,
      customerId,
      customerName,
      type,
      city,
      fromText,
      toText,
      currency;
  final String? courierId;
  final OrderStatus status;
  final num price;
  final num? distanceKm;
  final int? etaMinutes;
  final GeoPoint? fromLocation, toLocation;
  final List<String> declinedBy;
  final DateTime? createdAt, acceptedAt, updatedAt;

  factory TajGoOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    DateTime? date(String key) => (data[key] as Timestamp?)?.toDate();
    return TajGoOrder(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? 'Клиент',
      courierId: data['courierId'] as String?,
      status: orderStatusFromString(data['status'] as String?),
      type: data['type'] as String? ?? 'package',
      city: data['city'] as String? ?? 'Худжанд',
      fromText: data['fromText'] as String? ?? '',
      toText: data['toText'] as String? ?? '',
      price: data['price'] as num? ?? 0,
      currency: data['currency'] as String? ?? 'TJS',
      distanceKm: data['distanceKm'] as num?,
      etaMinutes: (data['etaMinutes'] as num?)?.toInt(),
      fromLocation: data['fromLocation'] as GeoPoint?,
      toLocation: data['toLocation'] as GeoPoint?,
      declinedBy: List<String>.from(data['declinedBy'] as List? ?? const []),
      createdAt: date('createdAt'),
      acceptedAt: date('acceptedAt'),
      updatedAt: date('updatedAt'),
    );
  }

  Map<String, dynamic> toCreateMap() => {
    'customerId': customerId,
    'customerName': customerName,
    'status': 'waiting',
    'type': type,
    'city': city,
    'fromText': fromText,
    'toText': toText,
    'price': price,
    'currency': currency,
    if (fromLocation != null) 'fromLocation': fromLocation,
    if (toLocation != null) 'toLocation': toLocation,
    if (distanceKm != null) 'distanceKm': distanceKm,
    if (etaMinutes != null) 'etaMinutes': etaMinutes,
    'declinedBy': <String>[],
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
