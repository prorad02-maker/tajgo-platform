import 'package:cloud_firestore/cloud_firestore.dart';

/// Метка сохранённого адреса.
abstract final class AddressLabel {
  static const home = 'home';
  static const work = 'work';
  static const other = 'other';

  static const values = {home, work, other};

  static String title(String label, String custom) => switch (label) {
    home => 'Дом',
    work => 'Работа',
    _ => custom.trim().isEmpty ? 'Другой адрес' : custom.trim(),
  };

  static String icon(String label) => switch (label) {
    home => '🏠',
    work => '💼',
    _ => '📍',
  };
}

/// Сохранённый адрес клиента (Дом / Работа / Другой) с деталями подъезда.
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    this.customTitle = '',
    required this.shortAddress,
    this.fullAddress = '',
    this.geo,
    this.entrance = '',
    this.floor = '',
    this.apartment = '',
    this.landmark = '',
    this.comment = '',
    this.updatedAt,
  });

  final String id;
  final String label;
  final String customTitle;
  final String shortAddress;
  final String fullAddress;
  final GeoPoint? geo;
  final String entrance;
  final String floor;
  final String apartment;
  final String landmark;
  final String comment;
  final DateTime? updatedAt;

  String get title => AddressLabel.title(label, customTitle);
  String get displayAddress =>
      shortAddress.trim().isNotEmpty ? shortAddress : fullAddress;

  Map<String, dynamic> toMap() => {
    'label': label,
    'customTitle': customTitle,
    'shortAddress': shortAddress,
    'fullAddress': fullAddress,
    if (geo != null) 'geo': geo,
    'entrance': entrance,
    'floor': floor,
    'apartment': apartment,
    'landmark': landmark,
    'comment': comment,
  };

  /// JSON для локального кэша (SharedPreferences).
  Map<String, dynamic> toCacheJson() => {
    'id': id,
    ...toMap(),
    'geo': geo == null
        ? null
        : {'lat': geo!.latitude, 'lng': geo!.longitude},
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
  };

  factory SavedAddress.fromCacheJson(Map<String, dynamic> data) => SavedAddress(
    id: data['id'] as String? ?? '',
    label: data['label'] as String? ?? AddressLabel.other,
    customTitle: data['customTitle'] as String? ?? '',
    shortAddress: data['shortAddress'] as String? ?? '',
    fullAddress: data['fullAddress'] as String? ?? '',
    geo: _geoFromCache(data['geo']),
    entrance: data['entrance'] as String? ?? '',
    floor: data['floor'] as String? ?? '',
    apartment: data['apartment'] as String? ?? '',
    landmark: data['landmark'] as String? ?? '',
    comment: data['comment'] as String? ?? '',
    updatedAt: data['updatedAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(data['updatedAt'] as int)
        : null,
  );

  factory SavedAddress.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return SavedAddress(
      id: doc.id,
      label: data['label'] as String? ?? AddressLabel.other,
      customTitle: data['customTitle'] as String? ?? '',
      shortAddress: data['shortAddress'] as String? ?? '',
      fullAddress: data['fullAddress'] as String? ?? '',
      geo: data['geo'] as GeoPoint?,
      entrance: data['entrance'] as String? ?? '',
      floor: data['floor'] as String? ?? '',
      apartment: data['apartment'] as String? ?? '',
      landmark: data['landmark'] as String? ?? '',
      comment: data['comment'] as String? ?? '',
      updatedAt: switch (data['updatedAt']) {
        Timestamp t => t.toDate(),
        _ => null,
      },
    );
  }

  static GeoPoint? _geoFromCache(Object? value) {
    if (value is Map && value['lat'] is num && value['lng'] is num) {
      return GeoPoint(
        (value['lat'] as num).toDouble(),
        (value['lng'] as num).toDouble(),
      );
    }
    return null;
  }
}
