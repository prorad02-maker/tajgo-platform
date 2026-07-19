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
    this.updatedAt,
    this.activeOrderId,
    this.ordersToday = 0,
    this.score = 100,
    this.isBusy = false,
    this.locationAccuracy,
  });
  final String uid, displayName, city, transport;
  final String? phoneNumber;
  final bool isOnline;
  final double rating;
  final num earningsToday;
  final GeoPoint? location;
  final DateTime? locationUpdatedAt;
  final DateTime? updatedAt;
  final String? activeOrderId;
  final int ordersToday;
  final int score;
  final bool isBusy;
  final double? locationAccuracy;

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
      location: _locationFrom(data),
      locationUpdatedAt: (data['locationUpdatedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      activeOrderId: data['activeOrderId'] as String?,
      ordersToday: (data['ordersToday'] as num? ?? 0).toInt(),
      score: (data['score'] as num? ?? 100).toInt(),
      isBusy: data['isBusy'] as bool? ?? data['activeOrderId'] != null,
      locationAccuracy: (data['locationAccuracy'] as num?)?.toDouble(),
    );
  }

  static GeoPoint? _locationFrom(Map<String, dynamic> data) {
    final location = data['location'];
    if (location is GeoPoint) {
      return location;
    }
    if (location is Map) {
      final latitude = location['latitude'] ?? location['lat'];
      final longitude = location['longitude'] ?? location['lng'];
      if (latitude is num && longitude is num) {
        return GeoPoint(latitude.toDouble(), longitude.toDouble());
      }
    }
    final latitude = data['latitude'] ?? data['lat'];
    final longitude = data['longitude'] ?? data['lng'];
    if (latitude is num && longitude is num) {
      return GeoPoint(latitude.toDouble(), longitude.toDouble());
    }
    return null;
  }
}
