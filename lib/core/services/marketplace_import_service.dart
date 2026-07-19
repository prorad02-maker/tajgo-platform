import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/marketplace_partner.dart';
import '../models/marketplace_product.dart';

class MarketplaceCatalogImport {
  const MarketplaceCatalogImport({
    required this.partner,
    required this.products,
    this.warnings = const [],
  });

  final MarketplacePartner partner;
  final List<MarketplaceProduct> products;
  final List<String> warnings;
}

class MarketplaceImportException implements FormatException {
  const MarketplaceImportException(this.message, [this.source, this.offset]);

  @override
  final String message;
  @override
  final Object? source;
  @override
  final int? offset;

  @override
  String toString() => message;
}

class MarketplaceImportService {
  const MarketplaceImportService();

  MarketplaceCatalogImport parse(
    String raw, {
    required String Function() newPartnerId,
    required String Function() newProductId,
  }) {
    late final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw MarketplaceImportException(
        'JSON не распознан: ${error.message}',
        raw,
        error.offset,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const MarketplaceImportException(
        'В корне JSON должен быть объект.',
      );
    }
    final schemaVersion = decoded['schemaVersion'] as num? ?? 1;
    if (schemaVersion.toInt() != 1) {
      throw MarketplaceImportException(
        'Поддерживается только schemaVersion = 1, получено $schemaVersion.',
      );
    }
    final partnerData = decoded['partner'];
    final productsData = decoded['products'];
    if (partnerData is! Map<String, dynamic>) {
      throw const MarketplaceImportException('Поле partner обязательно.');
    }
    if (productsData is! List<dynamic> || productsData.isEmpty) {
      throw const MarketplaceImportException(
        'Добавьте хотя бы один товар в products.',
      );
    }
    if (productsData.length > 100) {
      throw const MarketplaceImportException(
        'За один импорт допускается не более 100 товаров.',
      );
    }

    final partnerId = _id(partnerData['id'], newPartnerId, 'partner.id');
    final name = _text(partnerData['name'], 'partner.name', maxLength: 80);
    final category = _text(
      partnerData['category'],
      'partner.category',
      maxLength: 20,
    );
    if (!marketplaceCategories.contains(category)) {
      throw MarketplaceImportException(
        'partner.category должен быть food, groceries или flowers.',
      );
    }
    final address = _text(
      partnerData['address'],
      'partner.address',
      maxLength: 180,
    );
    final latitude = _number(
      partnerData['latitude'],
      'partner.latitude',
      min: -90,
      max: 90,
    ).toDouble();
    final longitude = _number(
      partnerData['longitude'],
      'partner.longitude',
      min: -180,
      max: 180,
    ).toDouble();
    final warnings = <String>[];
    if (latitude < 40.15 ||
        latitude > 40.40 ||
        longitude < 69.45 ||
        longitude > 69.80) {
      warnings.add('Координаты партнёра находятся за пределами зоны Худжанда.');
    }
    final imageUrl = _optionalText(
      partnerData['imageUrl'],
      'partner.imageUrl',
      maxLength: 500,
    );
    _validateUrl(imageUrl, 'partner.imageUrl');
    final partner = MarketplacePartner(
      id: partnerId,
      name: name,
      category: category,
      description: _optionalText(
        partnerData['description'],
        'partner.description',
        maxLength: 300,
      ),
      imageUrl: imageUrl,
      address: address,
      location: GeoPoint(latitude, longitude),
      minimumOrder: _number(
        partnerData['minimumOrder'] ?? 0,
        'partner.minimumOrder',
        min: 0,
        max: 100000,
      ),
      deliveryFee: _number(
        partnerData['deliveryFee'] ?? 10,
        'partner.deliveryFee',
        min: 0,
        max: 10000,
      ),
      rating: _number(
        partnerData['rating'] ?? 5,
        'partner.rating',
        min: 0,
        max: 5,
      ).toDouble(),
      preparationMinutes: _integer(
        partnerData['preparationMinutes'] ?? 20,
        'partner.preparationMinutes',
        min: 0,
        max: 240,
      ),
      sortOrder: _integer(
        partnerData['sortOrder'] ?? 0,
        'partner.sortOrder',
        min: 0,
        max: 10000,
      ),
      workingHours: _optionalText(
        partnerData['workingHours'],
        'partner.workingHours',
        maxLength: 80,
      ),
      isOpen: _boolean(partnerData['isOpen'], fallback: true),
      isActive: _boolean(partnerData['isActive'], fallback: true),
      isTest: _boolean(partnerData['isTest'], fallback: false),
    );

    final ids = <String>{};
    final products = <MarketplaceProduct>[];
    for (var index = 0; index < productsData.length; index++) {
      final data = productsData[index];
      if (data is! Map<String, dynamic>) {
        throw MarketplaceImportException(
          'products[$index] должен быть объектом.',
        );
      }
      final prefix = 'products[$index]';
      final id = _id(data['id'], newProductId, '$prefix.id');
      if (!ids.add(id)) {
        throw MarketplaceImportException('Повторяется id товара: $id.');
      }
      final unit = _optionalText(
        data['unit'] ?? 'item',
        '$prefix.unit',
        maxLength: 20,
      );
      if (!marketplaceProductUnits.contains(unit)) {
        throw MarketplaceImportException(
          '$prefix.unit должен быть item, kg, portion или bouquet.',
        );
      }
      final productImage = _optionalText(
        data['imageUrl'],
        '$prefix.imageUrl',
        maxLength: 500,
      );
      _validateUrl(productImage, '$prefix.imageUrl');
      final oldPrice = data['oldPrice'] == null
          ? null
          : _number(data['oldPrice'], '$prefix.oldPrice', min: 0, max: 100000);
      final price = _number(
        data['price'],
        '$prefix.price',
        min: 0.01,
        max: 100000,
      );
      if (oldPrice != null && oldPrice < price) {
        throw MarketplaceImportException(
          '$prefix.oldPrice не может быть меньше price.',
        );
      }
      products.add(
        MarketplaceProduct(
          id: id,
          partnerId: partnerId,
          name: _text(data['name'], '$prefix.name', maxLength: 100),
          description: _optionalText(
            data['description'],
            '$prefix.description',
            maxLength: 300,
          ),
          imageUrl: productImage,
          price: price,
          oldPrice: oldPrice,
          unit: unit,
          isAvailable: _boolean(data['isAvailable'], fallback: true),
          hidden: _boolean(data['hidden'], fallback: false),
          popularity: _integer(
            data['popularity'] ?? 0,
            '$prefix.popularity',
            min: 0,
            max: 1000000,
          ),
          sortOrder: _integer(
            data['sortOrder'] ?? index,
            '$prefix.sortOrder',
            min: 0,
            max: 10000,
          ),
          isTest: _boolean(data['isTest'], fallback: partner.isTest),
        ),
      );
    }
    return MarketplaceCatalogImport(
      partner: partner,
      products: products,
      warnings: warnings,
    );
  }

  String template() => const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': 1,
    'partner': {
      'id': 'demo-cafe-khujand',
      'name': 'Пример · Кафе Худжанд',
      'category': 'food',
      'description': 'Домашняя кухня',
      'imageUrl': '',
      'address': 'проспект Исмоили Сомони, Худжанд',
      'latitude': 40.2833,
      'longitude': 69.6222,
      'minimumOrder': 30,
      'deliveryFee': 12,
      'rating': 4.9,
      'preparationMinutes': 25,
      'workingHours': '09:00–22:00',
      'sortOrder': 10,
      'isOpen': true,
      'isActive': true,
      'isTest': true,
    },
    'products': [
      {
        'id': 'demo-cafe-plov',
        'name': 'Оши палав',
        'description': 'Порция традиционного плова',
        'imageUrl': '',
        'price': 32,
        'oldPrice': 36,
        'unit': 'portion',
        'isAvailable': true,
        'hidden': false,
        'popularity': 100,
        'sortOrder': 10,
        'isTest': true,
      },
    ],
  });

  String _id(Object? value, String Function() fallback, String field) {
    final result = value == null
        ? fallback()
        : _text(value, field, maxLength: 80);
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(result)) {
      throw MarketplaceImportException(
        '$field может содержать только латинские буквы, цифры, _ и -.',
      );
    }
    return result;
  }

  String _text(Object? value, String field, {required int maxLength}) {
    if (value is! String || value.trim().isEmpty) {
      throw MarketplaceImportException('$field обязательно.');
    }
    final result = value.trim();
    if (result.length > maxLength) {
      throw MarketplaceImportException(
        '$field длиннее допустимых $maxLength символов.',
      );
    }
    return result;
  }

  String _optionalText(Object? value, String field, {required int maxLength}) {
    if (value == null) return '';
    if (value is! String) {
      throw MarketplaceImportException('$field должен быть строкой.');
    }
    final result = value.trim();
    if (result.length > maxLength) {
      throw MarketplaceImportException(
        '$field длиннее допустимых $maxLength символов.',
      );
    }
    return result;
  }

  num _number(
    Object? value,
    String field, {
    required num min,
    required num max,
  }) {
    if (value is! num || !value.isFinite || value < min || value > max) {
      throw MarketplaceImportException(
        '$field должен быть числом от $min до $max.',
      );
    }
    return value;
  }

  int _integer(
    Object? value,
    String field, {
    required int min,
    required int max,
  }) {
    final number = _number(value, field, min: min, max: max);
    if (number != number.roundToDouble()) {
      throw MarketplaceImportException('$field должен быть целым числом.');
    }
    return number.toInt();
  }

  bool _boolean(Object? value, {required bool fallback}) {
    if (value == null) return fallback;
    if (value is! bool) {
      throw const MarketplaceImportException('Ожидалось true или false.');
    }
    return value;
  }

  void _validateUrl(String value, String field) {
    if (value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw MarketplaceImportException('$field должен быть HTTPS URL.');
    }
  }
}
