import 'package:cloud_firestore/cloud_firestore.dart';

class TajGoCourier {
  const TajGoCourier({
    required this.uid,
    required this.name,
    required this.city,
    required this.online,
    required this.rating,
    required this.transport,
    required this.earningsToday,
    this.location,
    this.locationUpdatedAt,
  });
  final String uid, name, city, transport;
  final bool online;
  final double rating;
  final num earningsToday;
  final GeoPoint? location;
  final DateTime? locationUpdatedAt;

  factory TajGoCourier.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TajGoCourier(
      uid: data['uid'] as String? ?? doc.id,
      name: data['name'] as String? ?? 'Курьер',
      city: data['city'] as String? ?? 'Худжанд',
      online: data['online'] as bool? ?? false,
      rating: (data['rating'] as num? ?? 5).toDouble(),
      transport: data['transport'] as String? ?? 'electric_bike',
      earningsToday: data['earningsToday'] as num? ?? 0,
      location: data['location'] as GeoPoint?,
      locationUpdatedAt: (data['locationUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
