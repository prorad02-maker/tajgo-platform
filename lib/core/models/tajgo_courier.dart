import 'package:cloud_firestore/cloud_firestore.dart';

class TajGoCourier {
  const TajGoCourier({
    required this.uid,
    required this.displayName,
    required this.city,
    required this.isOnline,
    required this.rating,
    required this.transport,
    required this.earningsToday,
    this.phoneNumber,
    this.location,
    this.locationUpdatedAt,
    this.activeOrderId,
    this.ordersToday = 0,
    this.score = 100,
  });
  final String uid, displayName, city, transport;
  final String? phoneNumber;
  final bool isOnline;
  final double rating;
  final num earningsToday;
  final GeoPoint? location;
  final DateTime? locationUpdatedAt;
  final String? activeOrderId;
  final int ordersToday;
  final int score;

  /// Legacy aliases used by the existing Courier MVP widgets.
  String get name => displayName;
  bool get online => isOnline;

  factory TajGoCourier.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TajGoCourier(
      uid: data['uid'] as String? ?? doc.id,
      phoneNumber: data['phoneNumber'] as String?,
      displayName:
          data['displayName'] as String? ?? data['name'] as String? ?? 'Курьер',
      city: data['city'] as String? ?? 'Худжанд',
      isOnline: data['isOnline'] as bool? ?? data['online'] as bool? ?? false,
      rating: (data['rating'] as num? ?? 5).toDouble(),
      transport: data['transport'] as String? ?? 'electric_bike',
      earningsToday: data['earningsToday'] as num? ?? 0,
      location: data['location'] as GeoPoint?,
      locationUpdatedAt: (data['locationUpdatedAt'] as Timestamp?)?.toDate(),
      activeOrderId: data['activeOrderId'] as String?,
      ordersToday: (data['ordersToday'] as num? ?? 0).toInt(),
      score: (data['score'] as num? ?? 100).toInt(),
    );
  }
}
