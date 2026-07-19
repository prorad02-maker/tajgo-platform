import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/marketplace_cart.dart';
import '../models/marketplace_partner.dart';
import '../models/marketplace_product.dart';
import '../models/marketplace_sample_catalog.dart';
import 'marketplace_import_service.dart';
import 'pricing.dart';

class MarketplaceRepository {
  MarketplaceRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<MarketplacePartner>> partnersStream({String? category}) async* {
    Query<Map<String, dynamic>> query = _db
        .collection('partners')
        .where('isActive', isEqualTo: true);
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    try {
      await for (final snapshot in query.snapshots()) {
        final partners = snapshot.docs
            .map(MarketplacePartner.fromDoc)
            .toList(growable: false);
        if (partners.isEmpty) {
          yield samplePartnersForCategory(category);
          continue;
        }
        partners.sort((a, b) {
          final active = b.isOpen.toString().compareTo(a.isOpen.toString());
          if (active != 0) return active;
          final order = a.sortOrder.compareTo(b.sortOrder);
          if (order != 0) return order;
          return a.name.compareTo(b.name);
        });
        yield partners;
      }
    } catch (_) {
      yield samplePartnersForCategory(category);
    }
  }

  Stream<List<MarketplacePartner>> allPartnersStream() => _db
      .collection('partners')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(MarketplacePartner.fromDoc).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );

  Stream<List<MarketplaceProduct>> productsStream(
    String partnerId, {
    bool includeHidden = false,
    bool previewFallback = false,
  }) {
    if (previewFallback) {
      return Stream.value(sampleProductsForPartner(partnerId));
    }
    Query<Map<String, dynamic>> query = _db
        .collection('products')
        .where('partnerId', isEqualTo: partnerId);
    if (!includeHidden) {
      query = query.where('hidden', isEqualTo: false);
    }
    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map(MarketplaceProduct.fromDoc).toList(growable: false)
            ..sort((a, b) {
              final order = a.sortOrder.compareTo(b.sortOrder);
              if (order != 0) return order;
              final popular = b.popularity.compareTo(a.popularity);
              if (popular != 0) return popular;
              return a.name.compareTo(b.name);
            }),
    );
  }

  Stream<List<MarketplaceProduct>> allProductsStream() => _db
      .collection('products')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(MarketplaceProduct.fromDoc).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );

  String newPartnerId() => _db.collection('partners').doc().id;
  String newProductId() => _db.collection('products').doc().id;

  Future<void> savePartner({
    required MarketplacePartner partner,
    required String adminId,
  }) => _saveAdminDocument(
    collection: 'partners',
    id: partner.id,
    data: partner.toWriteMap(),
    adminId: adminId,
    action: 'marketplace.partner.save',
  );

  Future<void> saveProduct({
    required MarketplaceProduct product,
    required String adminId,
  }) => _saveAdminDocument(
    collection: 'products',
    id: product.id,
    data: product.toWriteMap(),
    adminId: adminId,
    action: 'marketplace.product.save',
  );

  Future<void> publishSampleCatalog({
    required String adminId,
  }) => _db.runTransaction((transaction) async {
    final partners = marketplaceSamplePartners
        .map((partner) => partner.copyWith(isPreview: false))
        .toList(growable: false);
    final partnerRefs = {
      for (final partner in partners)
        partner.id: _db.collection('partners').doc(partner.id),
    };
    final productRefs = {
      for (final product in marketplaceSampleProducts)
        product.id: _db.collection('products').doc(product.id),
    };
    final existingPartners = <String, Map<String, dynamic>?>{};
    final existingProducts = <String, Map<String, dynamic>?>{};
    for (final entry in partnerRefs.entries) {
      existingPartners[entry.key] = (await transaction.get(entry.value)).data();
    }
    for (final entry in productRefs.entries) {
      existingProducts[entry.key] = (await transaction.get(entry.value)).data();
    }
    for (final partner in partners) {
      transaction.set(partnerRefs[partner.id]!, {
        ...partner.toWriteMap(),
        'createdAt':
            existingPartners[partner.id]?['createdAt'] ??
            FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    for (final product in marketplaceSampleProducts) {
      transaction.set(productRefs[product.id]!, {
        ...product.toWriteMap(),
        'createdAt':
            existingProducts[product.id]?['createdAt'] ??
            FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    transaction.set(_db.collection('admin_logs').doc(), {
      'adminId': adminId,
      'action': 'marketplace.samples.publish',
      'entityType': 'marketplace',
      'entityId': 'sample-catalog',
      'before': {
        'existingPartners': existingPartners.values
            .whereType<Map<String, dynamic>>()
            .length,
        'existingProducts': existingProducts.values
            .whereType<Map<String, dynamic>>()
            .length,
      },
      'after': {
        'partners': partners.length,
        'products': marketplaceSampleProducts.length,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  });

  Future<MarketplaceImportResult> importCatalog({
    required MarketplaceCatalogImport catalog,
    required String adminId,
  }) => _db.runTransaction((transaction) async {
    final partner = catalog.partner.copyWith(isPreview: false);
    final partnerRef = _db.collection('partners').doc(partner.id);
    final productRefs = {
      for (final product in catalog.products)
        product.id: _db.collection('products').doc(product.id),
    };
    final partnerBefore = (await transaction.get(partnerRef)).data();
    final productsBefore = <String, Map<String, dynamic>?>{};
    for (final entry in productRefs.entries) {
      final data = (await transaction.get(entry.value)).data();
      if (data != null && data['partnerId'] != partner.id) {
        throw StateError(
          'Товар ${entry.key} уже принадлежит другому партнёру.',
        );
      }
      productsBefore[entry.key] = data;
    }
    transaction.set(partnerRef, {
      ...partner.toWriteMap(),
      'createdAt': partnerBefore?['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final product in catalog.products) {
      transaction.set(productRefs[product.id]!, {
        ...product.toWriteMap(),
        'createdAt':
            productsBefore[product.id]?['createdAt'] ??
            FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    transaction.set(_db.collection('admin_logs').doc(), {
      'adminId': adminId,
      'action': 'marketplace.catalog.import',
      'entityType': 'marketplace',
      'entityId': partner.id,
      'before': {
        'partnerExists': partnerBefore != null,
        'existingProducts': productsBefore.values
            .whereType<Map<String, dynamic>>()
            .length,
      },
      'after': {
        'partnerId': partner.id,
        'productIds': catalog.products.map((product) => product.id).toList(),
        'warnings': catalog.warnings,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
    return MarketplaceImportResult(
      partnerCreated: partnerBefore == null,
      productsCreated: productsBefore.values
          .where((data) => data == null)
          .length,
      productsUpdated: productsBefore.values
          .whereType<Map<String, dynamic>>()
          .length,
    );
  });

  Future<void> _saveAdminDocument({
    required String collection,
    required String id,
    required Map<String, dynamic> data,
    required String adminId,
    required String action,
  }) => _db.runTransaction((transaction) async {
    final ref = _db.collection(collection).doc(id);
    final existing = await transaction.get(ref);
    transaction.set(ref, {
      ...data,
      'createdAt':
          existing.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    transaction.set(_db.collection('admin_logs').doc(), {
      'adminId': adminId,
      'action': action,
      'entityType': collection,
      'entityId': id,
      'before': existing.data(),
      'after': data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  });

  Future<String> createCatalogOrder({
    required String customerId,
    required String customerName,
    required MarketplacePartner partner,
    required List<MarketplaceCartLine> cartLines,
    required GeoPoint deliveryLocation,
    required String deliveryAddress,
    required num distanceKm,
    required int etaMinutes,
    String? comment,
  }) => _db.runTransaction((transaction) async {
    if (cartLines.isEmpty) throw StateError('Корзина пока пуста.');
    final partnerRef = _db.collection('partners').doc(partner.id);
    final partnerDoc = await transaction.get(partnerRef);
    final freshPartner = partnerDoc.exists
        ? MarketplacePartner.fromMap(partner.id, partnerDoc.data()!)
        : null;
    if (freshPartner == null || !freshPartner.isActive) {
      throw StateError('Партнёр сейчас недоступен.');
    }
    if (!freshPartner.isOpen) {
      throw StateError('Партнёр сейчас закрыт.');
    }

    final items = <Map<String, dynamic>>[];
    num subtotal = 0;
    for (final line in cartLines) {
      final productDoc = await transaction.get(
        _db.collection('products').doc(line.product.id),
      );
      if (!productDoc.exists) throw StateError('Один из товаров не найден.');
      final product = MarketplaceProduct.fromMap(
        productDoc.id,
        productDoc.data()!,
      );
      if (product.partnerId != partner.id ||
          product.hidden ||
          !product.isAvailable) {
        throw StateError('Некоторые товары закончились. Обновите корзину.');
      }
      if (product.price != line.product.price) {
        throw StateError('Цена товара изменилась. Обновите корзину.');
      }
      if (line.quantity <= 0) throw StateError('Количество товара неверно.');
      final lineTotal = product.price * line.quantity;
      subtotal += lineTotal;
      items.add({
        'productId': product.id,
        'name': product.name,
        'unit': product.unit,
        'unitPrice': product.price,
        'quantity': line.quantity,
        'lineTotal': lineTotal,
      });
    }
    if (subtotal < freshPartner.minimumOrder) {
      final missing = freshPartner.minimumOrder - subtotal;
      throw StateError('Добавьте товаров ещё на $missing TJS.');
    }

    final deliveryFee = freshPartner.deliveryFee < minimumPrice
        ? minimumPrice
        : freshPartner.deliveryFee;
    final ref = _db.collection('orders').doc();
    transaction.set(ref, {
      'customerId': customerId,
      'customerName': customerName,
      'status': 'waitingOffers',
      'orderType': 'catalogOrder',
      'type': freshPartner.category,
      'city': 'Худжанд',
      'fromText': freshPartner.address,
      'toText': deliveryAddress.trim(),
      'fromLocation': freshPartner.location,
      'toLocation': deliveryLocation,
      'partnerId': freshPartner.id,
      'partnerName': freshPartner.name,
      'items': items,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': subtotal + deliveryFee,
      'price': deliveryFee,
      'suggestedPrice': deliveryFee,
      'clientPrice': deliveryFee,
      'priceNegotiable': false,
      'offersCount': 0,
      'pricingVersion': 'marketplace-v1',
      'currency': 'TJS',
      'confirmationCode': generateConfirmationCode(),
      'distanceKm': distanceKm,
      'etaMinutes': etaMinutes,
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
      if (freshPartner.isTest) 'isTestOrder': true,
      'declinedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  });
}

class MarketplaceImportResult {
  const MarketplaceImportResult({
    required this.partnerCreated,
    required this.productsCreated,
    required this.productsUpdated,
  });

  final bool partnerCreated;
  final int productsCreated;
  final int productsUpdated;
}
