import 'package:latlong2/latlong.dart';

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.shortTitle,
    required this.address,
    required this.lat,
    required this.lng,
    required this.source,
    required this.confidence,
    required this.category,
    this.distanceMetersFromUser,
    this.aliases = const [],
    this.district,
    this.verified = false,
    this.popularity = 0,
    this.notes,
    this.usedAt,
    this.recentType,
  });

  final String id;
  final String title;
  final String subtitle;
  final String shortTitle;
  final String address;
  final double lat;
  final double lng;
  final double? distanceMetersFromUser;
  final String source;
  final double confidence;
  final String category;
  final List<String> aliases;
  final String? district;
  final bool verified;
  final int popularity;
  final String? notes;
  final DateTime? usedAt;
  final String? recentType;

  LatLng get point => LatLng(lat, lng);

  PlaceSuggestion copyWith({
    double? distanceMetersFromUser,
    double? confidence,
    String? source,
    DateTime? usedAt,
    String? recentType,
  }) => PlaceSuggestion(
    id: id,
    title: title,
    subtitle: subtitle,
    shortTitle: shortTitle,
    address: address,
    lat: lat,
    lng: lng,
    distanceMetersFromUser:
        distanceMetersFromUser ?? this.distanceMetersFromUser,
    source: source ?? this.source,
    confidence: confidence ?? this.confidence,
    category: category,
    aliases: aliases,
    district: district,
    verified: verified,
    popularity: popularity,
    notes: notes,
    usedAt: usedAt ?? this.usedAt,
    recentType: recentType ?? this.recentType,
  );

  Map<String, dynamic> toJson({String? type, DateTime? usedAt}) {
    final json = <String, dynamic>{
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'shortTitle': shortTitle,
      'address': address,
      'lat': lat,
      'lng': lng,
      'source': source,
      'confidence': confidence,
      'category': category,
      'district': district,
      'verified': verified,
      'popularity': popularity,
      'notes': notes,
    };
    if (type != null) json['type'] = type;
    if (usedAt != null) json['usedAt'] = usedAt.toIso8601String();
    return json;
  }

  factory PlaceSuggestion.fromJson(
    Map<String, dynamic> json, {
    String? source,
  }) => PlaceSuggestion(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    shortTitle: json['shortTitle'] as String? ?? json['title'] as String? ?? '',
    address: json['address'] as String? ?? '',
    lat: (json['lat'] as num?)?.toDouble() ?? 0,
    lng: (json['lng'] as num?)?.toDouble() ?? 0,
    source: source ?? json['source'] as String? ?? 'local',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 1,
    category: json['category'] as String? ?? 'place',
    aliases:
        (json['aliases'] as List<dynamic>?)?.whereType<String>().toList() ??
        const [],
    district: json['district'] as String?,
    verified: json['verified'] as bool? ?? false,
    popularity: (json['popularity'] as num?)?.round() ?? 0,
    notes: json['notes'] as String?,
    usedAt: DateTime.tryParse(json['usedAt'] as String? ?? ''),
    recentType: json['type'] as String?,
  );
}
