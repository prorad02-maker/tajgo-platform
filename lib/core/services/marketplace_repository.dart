import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/marketplace_cart.dart';
import '../models/marketplace_partner.dart';
import '../models/marketplace_product.dart';
import '../models/marketplace_sample_catalog.dart';
import 'authoritative_command_service.dart';
import 'marketplace_import_service.dart';

bool isMarketplaceCheckoutBlocked(MarketplacePartner partner) =>
    partner.isPreview || partner.isTest;

class MarketplaceRepository {
  MarketplaceRepository(this._db, this._commands);

  final FirebaseFirestore _db;
  final AuthoritativeCommandService _commands;

  Stream<List<MarketplacePartner>> partnersStream({String? category}) async* {
    Query<Map<String, dynamic>> query = _db
        .collection('partners')
        .where('isActive', isEqualTo: true)
        .where('isTest', isEqualTo: false)
        .where('isPreview', isEqualTo: false)
        .where('isPublished', isEqualTo: true);
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
        .where('partnerId', isEqualTo: partnerId)
        .where('isTest', isEqualTo: false)
        .where('isAvailable', isEqualTo: true)
        .where('isPublished', isEqualTo: true);
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

  /// Опубликованные, доступные и не скрытые товары всех партнёров — для поиска.
  ///
  /// Запрос по одному индексируемому полю `isPublished`; остальные условия
  /// (не test, доступен, не скрыт) фильтруются на клиенте, чтобы не требовать
  /// составного индекса. При ошибке возвращается пустой список.
  Stream<List<MarketplaceProduct>> publishedProductsStream() => _db
      .collection('products')
      .where('isPublished', isEqualTo: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(MarketplaceProduct.fromDoc)
            .where(
              (product) =>
                  !product.isTest && product.isAvailable && !product.hidden,
            )
            .toList(growable: false),
      )
      .handleError((_) {});

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
    String? idempotencyKey,
  }) async {
    if (isMarketplaceCheckoutBlocked(partner)) {
      throw const TajGoCommandException(
        code: 'failed-precondition',
        message: 'Тестовый каталог нельзя оформить.',
        reason: 'preview-blocked',
      );
    }
    if (cartLines.isEmpty) throw StateError('Корзина пока пуста.');
    final result = await _commands.call('createCatalogOrder', {
      'idempotencyKey':
          idempotencyKey ??
          TajGoIdempotencyKey.create('catalog-order-$customerId'),
      'partnerId': partner.id,
      'items': cartLines
          .map(
            (line) => {
              'productId': line.product.id,
              'quantity': line.quantity,
              'knownUnitPrice': line.product.price,
            },
          )
          .toList(growable: false),
      'deliveryLocation': {
        'latitude': deliveryLocation.latitude,
        'longitude': deliveryLocation.longitude,
      },
      'deliveryAddress': deliveryAddress.trim(),
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
      // UI hints are deliberately non-authoritative. The backend recalculates.
      'clientDistanceKm': distanceKm,
      'clientEtaMinutes': etaMinutes,
    });
    final orderId = result['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) {
      throw const TajGoCommandException(
        code: 'aborted',
        message: 'TajGo не вернул номер заказа. Повторите запрос.',
        retryable: true,
      );
    }
    return orderId;
  }
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
