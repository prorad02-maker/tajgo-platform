import 'package:cloud_firestore/cloud_firestore.dart';

const marketplaceCategories = <String>{'food', 'groceries', 'flowers'};

String marketplaceCategoryLabel(String value) => switch (value) {
  'food' => 'Еда',
  'groceries' => 'Продукты',
  'flowers' => 'Цветы',
  _ => 'Партнёры',
};

class MarketplacePartner {
  const MarketplacePartner({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.location,
    this.description = '',
    this.imageUrl = '',
    this.minimumOrder = 0,
    this.deliveryFee = 10,
    this.rating = 5,
    this.preparationMinutes = 20,
    this.sortOrder = 0,
    this.workingHours = '',
    this.isOpen = true,
    this.isActive = true,
    this.isTest = false,
    this.isPreview = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final String imageUrl;
  final String address;
  final GeoPoint location;
  final num minimumOrder;
  final num deliveryFee;
  final double rating;
  final int preparationMinutes;
  final int sortOrder;
  final String workingHours;
  final bool isOpen;
  final bool isActive;
  final bool isTest;
  final bool isPreview;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MarketplacePartner.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => MarketplacePartner.fromMap(doc.id, doc.data() ?? const {});

  factory MarketplacePartner.fromMap(String id, Map<String, dynamic> data) =>
      MarketplacePartner(
        id: id,
        name: data['name'] as String? ?? 'Партнёр TajGo',
        category: data['category'] as String? ?? 'food',
        description: data['description'] as String? ?? '',
        imageUrl: data['imageUrl'] as String? ?? '',
        address: data['address'] as String? ?? 'Худжанд',
        location:
            data['location'] as GeoPoint? ?? const GeoPoint(40.2833, 69.6222),
        minimumOrder: data['minimumOrder'] as num? ?? 0,
        deliveryFee: data['deliveryFee'] as num? ?? 10,
        rating: (data['rating'] as num? ?? 5).toDouble(),
        preparationMinutes: (data['preparationMinutes'] as num? ?? 20).toInt(),
        sortOrder: (data['sortOrder'] as num? ?? 0).toInt(),
        workingHours: data['workingHours'] as String? ?? '',
        isOpen: data['isOpen'] as bool? ?? true,
        isActive: data['isActive'] as bool? ?? true,
        isTest: data['isTest'] as bool? ?? false,
        isPreview: false,
        createdAt: _date(data['createdAt']),
        updatedAt: _date(data['updatedAt']),
      );

  Map<String, dynamic> toWriteMap() => {
    'name': name.trim(),
    'category': category,
    'description': description.trim(),
    'imageUrl': imageUrl.trim(),
    'address': address.trim(),
    'location': location,
    'minimumOrder': minimumOrder,
    'deliveryFee': deliveryFee,
    'rating': rating,
    'preparationMinutes': preparationMinutes,
    'sortOrder': sortOrder,
    'workingHours': workingHours.trim(),
    'isOpen': isOpen,
    'isActive': isActive,
    'isTest': isTest,
  };

  MarketplacePartner copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    String? imageUrl,
    String? address,
    GeoPoint? location,
    num? minimumOrder,
    num? deliveryFee,
    double? rating,
    int? preparationMinutes,
    int? sortOrder,
    String? workingHours,
    bool? isOpen,
    bool? isActive,
    bool? isTest,
    bool? isPreview,
  }) => MarketplacePartner(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    address: address ?? this.address,
    location: location ?? this.location,
    minimumOrder: minimumOrder ?? this.minimumOrder,
    deliveryFee: deliveryFee ?? this.deliveryFee,
    rating: rating ?? this.rating,
    preparationMinutes: preparationMinutes ?? this.preparationMinutes,
    sortOrder: sortOrder ?? this.sortOrder,
    workingHours: workingHours ?? this.workingHours,
    isOpen: isOpen ?? this.isOpen,
    isActive: isActive ?? this.isActive,
    isTest: isTest ?? this.isTest,
    isPreview: isPreview ?? this.isPreview,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

DateTime? _date(Object? value) => switch (value) {
  Timestamp timestamp => timestamp.toDate(),
  DateTime date => date,
  _ => null,
};
