import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/core/models/marketplace_cart.dart';
import 'package:tajgo/core/models/marketplace_partner.dart';
import 'package:tajgo/core/models/marketplace_product.dart';
import 'package:tajgo/core/models/marketplace_sample_catalog.dart';
import 'package:tajgo/core/models/tajgo_order.dart';
import 'package:tajgo/core/services/courier_offer_repository.dart';
import 'package:tajgo/core/services/marketplace_import_service.dart';

void main() {
  const point = GeoPoint(40.2833, 69.6222);

  MarketplacePartner partner(String id, {num minimum = 20}) =>
      MarketplacePartner(
        id: id,
        name: 'Partner $id',
        category: 'food',
        address: 'Khujand',
        location: point,
        minimumOrder: minimum,
        deliveryFee: 10,
      );

  MarketplaceProduct product(
    String id,
    String partnerId, {
    num price = 12,
    String unit = 'item',
  }) => MarketplaceProduct(
    id: id,
    partnerId: partnerId,
    name: 'Product $id',
    price: price,
    unit: unit,
  );

  group('marketplace cart', () {
    test('keeps products from one partner only', () {
      final cart = MarketplaceCart();
      cart.add(partner('a'), product('one', 'a'));

      expect(
        () => cart.add(partner('b'), product('two', 'b')),
        throwsA(isA<MarketplaceCartConflict>()),
      );
      expect(cart.partner?.id, 'a');
      expect(cart.itemKinds, 1);
    });

    test('uses half-kilogram quantity steps and exact totals', () {
      final cart = MarketplaceCart();
      cart.add(partner('a'), product('apples', 'a', price: 12, unit: 'kg'));
      expect(cart.itemCount, 0.5);
      expect(cart.subtotal, 6);

      cart.increment('apples');
      expect(cart.itemCount, 1);
      expect(cart.subtotal, 12);
      expect(cart.total, 22);
    });

    test('checkout quote enforces the partner minimum', () {
      const low = MarketplaceCheckoutQuote(
        subtotal: 18,
        deliveryFee: 10,
        minimumOrder: 25,
      );
      const ready = MarketplaceCheckoutQuote(
        subtotal: 30,
        deliveryFee: 10,
        minimumOrder: 25,
      );
      expect(low.meetsMinimum, isFalse);
      expect(low.missingForMinimum, 7);
      expect(ready.meetsMinimum, isTrue);
      expect(ready.total, 40);
    });
  });

  test('catalog entities preserve Firestore-compatible fields', () {
    final mappedPartner = MarketplacePartner.fromMap('p1', {
      'name': 'Cafe',
      'category': 'food',
      'address': 'Center',
      'location': point,
      'minimumOrder': 25,
      'deliveryFee': 11,
      'isActive': true,
    });
    final mappedProduct = MarketplaceProduct.fromMap('x1', {
      'partnerId': 'p1',
      'name': 'Plov',
      'price': 30,
      'unit': 'portion',
      'isAvailable': true,
      'hidden': false,
    });

    expect(mappedPartner.toWriteMap()['category'], 'food');
    expect(mappedProduct.toWriteMap()['partnerId'], 'p1');
    expect(mappedProduct.quantityStep, 1);
  });

  test('catalog order snapshot survives the common order model', () {
    const order = TajGoOrder(
      id: 'o1',
      customerId: 'c1',
      customerName: 'Customer',
      status: OrderStatus.waiting,
      type: 'food',
      city: 'Худжанд',
      fromText: 'Cafe',
      toText: 'Home',
      price: 10,
      currency: 'TJS',
      orderType: 'catalogOrder',
      priceNegotiable: false,
      partnerId: 'p1',
      partnerName: 'Cafe',
      subtotal: 30,
      deliveryFee: 10,
      total: 40,
      items: [
        CatalogOrderItem(
          productId: 'x1',
          name: 'Plov',
          unit: 'portion',
          unitPrice: 30,
          quantity: 1,
          lineTotal: 30,
        ),
      ],
    );

    final data = order.toCreateMap();
    expect(data['orderType'], 'catalogOrder');
    expect(data['priceNegotiable'], isFalse);
    expect(data['items'], hasLength(1));
    expect(data['total'], 40);
  });

  test('fixed catalog delivery price cannot be raised by courier', () {
    expect(
      isCourierOfferPriceValid(
        proposedPrice: 10,
        clientPrice: 10,
        priceNegotiable: false,
      ),
      isTrue,
    );
    expect(
      isCourierOfferPriceValid(
        proposedPrice: 11,
        clientPrice: 10,
        priceNegotiable: false,
      ),
      isFalse,
    );
  });

  group('marketplace admin import', () {
    const service = MarketplaceImportService();

    test('template passes dry-run and preserves sortable catalog fields', () {
      final catalog = service.parse(
        service.template(),
        newPartnerId: () => 'generated-partner',
        newProductId: () => 'generated-product',
      );

      expect(catalog.partner.id, 'demo-cafe-khujand');
      expect(catalog.partner.category, 'food');
      expect(catalog.partner.sortOrder, 10);
      expect(catalog.products, hasLength(1));
      expect(catalog.products.single.oldPrice, 36);
      expect(catalog.products.single.sortOrder, 10);
      expect(catalog.warnings, isEmpty);
    });

    test('rejects unsupported categories and insecure image URLs', () {
      expect(
        () => service.parse(
          service.template().replaceFirst('"food"', '"taxi"'),
          newPartnerId: () => 'partner',
          newProductId: () => 'product',
        ),
        throwsA(isA<MarketplaceImportException>()),
      );
      expect(
        () => service.parse(
          service.template().replaceFirst(
            '"imageUrl": ""',
            '"imageUrl": "http://example.com/image.png"',
          ),
          newPartnerId: () => 'partner',
          newProductId: () => 'product',
        ),
        throwsA(isA<MarketplaceImportException>()),
      );
    });

    test('warns when establishment coordinates are outside Khujand', () {
      final catalog = service.parse(
        service.template().replaceFirst('40.2833', '39.0000'),
        newPartnerId: () => 'partner',
        newProductId: () => 'product',
      );
      expect(catalog.warnings.single, contains('за пределами'));
    });

    test('preview catalog covers all three primary categories', () {
      expect(marketplaceSamplePartners, hasLength(6));
      expect(marketplaceSampleProducts, hasLength(18));
      for (final category in marketplaceCategories) {
        expect(samplePartnersForCategory(category), hasLength(2));
      }
      for (final partner in marketplaceSamplePartners) {
        expect(partner.isPreview, isTrue);
        expect(sampleProductsForPartner(partner.id), hasLength(3));
        expect(partner.toWriteMap(), isNot(contains('isPreview')));
      }
    });
  });
}
