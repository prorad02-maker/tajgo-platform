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

  /// Разовый список товаров партнёра (для сопоставления по SKU при импорте).
  Future<List<MarketplaceProduct>> partnerProductsOnce(String partnerId) async {
    final snapshot = await _db
        .collection('products')
        .where('partnerId', isEqualTo: partnerId)
        .get();
    return snapshot.docs.map(MarketplaceProduct.fromDoc).toList(growable: false);
  }

  static Map<String, dynamic> _partnerFields(MarketplacePartner p) => {
    'name': p.name,
    'category': p.category,
    'description': p.description,
    'imageUrl': p.imageUrl,
    'address': p.address,
    'location': {
      'latitude': p.location.latitude,
      'longitude': p.location.longitude,
    },
    'minimumOrder': p.minimumOrder,
    'deliveryFee': p.deliveryFee,
    'rating': p.rating,
    'preparationMinutes': p.preparationMinutes,
    'sortOrder': p.sortOrder,
    'workingHours': p.workingHours,
    'isOpen': p.isOpen,
    'isActive': p.isActive,
    'isPublished': !p.isPreview,
  };

  static Map<String, dynamic> _productFields(MarketplaceProduct p) => {
    'partnerId': p.partnerId,
    'name': p.name,
    'description': p.description,
    'imageUrl': p.imageUrl,
    'price': p.price,
    if (p.oldPrice != null) 'oldPrice': p.oldPrice,
    'unit': p.unit,
    if (p.sku.isNotEmpty) 'sku': p.sku,
    'isAvailable': p.isAvailable,
    'hidden': p.hidden,
    'popularity': p.popularity,
    'sortOrder': p.sortOrder,
  };

  Future<void> savePartner({
    required MarketplacePartner partner,
    required String adminId,
  }) => _commands.call('adminSavePartner', {
    if (partner.id.isNotEmpty) 'partnerId': partner.id,
    ..._partnerFields(partner),
  });

  Future<void> saveProduct({
    required MarketplaceProduct product,
    required String adminId,
  }) => _commands.call('adminSaveProduct', {
    if (product.id.isNotEmpty) 'productId': product.id,
    ..._productFields(product),
  });

  Future<void> publishSampleCatalog({required String adminId}) async {
    for (final partner in marketplaceSamplePartners) {
      final published = partner.copyWith(isPreview: false);
      final products = marketplaceSampleProducts
          .where((product) => product.partnerId == partner.id)
          .toList(growable: false);
      await importCatalog(
        catalog: MarketplaceCatalogImport(
          partner: published,
          products: products,
          warnings: const [],
        ),
        adminId: adminId,
      );
    }
  }

  Future<MarketplaceImportResult> importCatalog({
    required MarketplaceCatalogImport catalog,
    required String adminId,
  }) async {
    final partner = catalog.partner.copyWith(isPreview: false);
    await _commands.call('adminImportCatalog', {
      'idempotencyKey': TajGoIdempotencyKey.create('catalog-import-${partner.id}'),
      'partner': {'id': partner.id, ..._partnerFields(partner)},
      'products': catalog.products
          .map((p) => {'id': p.id, ..._productFields(p)})
          .toList(growable: false),
    });
    return MarketplaceImportResult(
      partnerCreated: true,
      productsCreated: catalog.products.length,
      productsUpdated: 0,
    );
  }

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
