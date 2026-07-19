import 'package:cloud_firestore/cloud_firestore.dart';

const marketplaceProductUnits = <String>{'item', 'kg', 'portion', 'bouquet'};

String marketplaceUnitLabel(String value) => switch (value) {
  'kg' => 'кг',
  'portion' => 'порция',
  'bouquet' => 'букет',
  _ => 'шт.',
};

class MarketplaceProduct {
  const MarketplaceProduct({
    required this.id,
    required this.partnerId,
    required this.name,
    required this.price,
    this.description = '',
    this.imageUrl = '',
    this.oldPrice,
    this.unit = 'item',
    this.isAvailable = true,
    this.hidden = false,
    this.popularity = 0,
    this.sortOrder = 0,
    this.isTest = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String partnerId;
  final String name;
  final String description;
  final String imageUrl;
  final num price;
  final num? oldPrice;
  final String unit;
  final bool isAvailable;
  final bool hidden;
  final int popularity;
  final int sortOrder;
  final bool isTest;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get quantityStep => unit == 'kg' ? 0.5 : 1;

  factory MarketplaceProduct.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => MarketplaceProduct.fromMap(doc.id, doc.data() ?? const {});

  factory MarketplaceProduct.fromMap(String id, Map<String, dynamic> data) =>
      MarketplaceProduct(
        id: id,
        partnerId: data['partnerId'] as String? ?? '',
        name: data['name'] as String? ?? 'Товар',
        description: data['description'] as String? ?? '',
        imageUrl: data['imageUrl'] as String? ?? '',
        price: data['price'] as num? ?? 0,
        oldPrice: data['oldPrice'] as num?,
        unit: data['unit'] as String? ?? 'item',
        isAvailable: data['isAvailable'] as bool? ?? true,
        hidden: data['hidden'] as bool? ?? false,
        popularity: (data['popularity'] as num? ?? 0).toInt(),
        sortOrder: (data['sortOrder'] as num? ?? 0).toInt(),
        isTest: data['isTest'] as bool? ?? false,
        createdAt: _date(data['createdAt']),
        updatedAt: _date(data['updatedAt']),
      );

  Map<String, dynamic> toWriteMap() => {
    'partnerId': partnerId,
    'name': name.trim(),
    'description': description.trim(),
    'imageUrl': imageUrl.trim(),
    'price': price,
    if (oldPrice != null) 'oldPrice': oldPrice,
    'unit': unit,
    'isAvailable': isAvailable,
    'hidden': hidden,
    'popularity': popularity,
    'sortOrder': sortOrder,
    'isTest': isTest,
  };
}

DateTime? _date(Object? value) => switch (value) {
  Timestamp timestamp => timestamp.toDate(),
  DateTime date => date,
  _ => null,
};
