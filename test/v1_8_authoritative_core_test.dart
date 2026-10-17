import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/core/models/app_user.dart';
import 'package:tajgo/core/models/courier_offer.dart';
import 'package:tajgo/core/models/marketplace_cart.dart';
import 'package:tajgo/core/models/marketplace_partner.dart';
import 'package:tajgo/core/models/marketplace_product.dart';
import 'package:tajgo/core/models/tajgo_courier.dart';
import 'package:tajgo/core/models/tajgo_order.dart';
import 'package:tajgo/core/services/authoritative_command_service.dart';
import 'package:tajgo/core/services/delivery_code_input.dart';
import 'package:tajgo/core/services/marketplace_repository.dart';
import 'package:tajgo/features/startup/startup_decision.dart';

void main() {
  AppUser profile({required String role}) => AppUser.fromMap({
    'displayName': 'Pilot user',
    'profileComplete': true,
    'onboardingCompleted': true,
    'role': role,
    'roles': ['customer'],
    'lastMode': 'customer',
  }, uid: 'pilot-user');

  test('server role wins when local role cache disagrees', () {
    const cachedMode = AppUserRole.courier;
    final serverProfile = profile(role: AppUserRole.admin);
    expect(cachedMode, isNot(serverProfile.role));
    expect(
      resolveStartupDestination(authenticated: true, profile: serverProfile),
      StartupDestination.adminHome,
    );
  });

  test('admin route is not selected for a non-admin profile', () {
    final serverProfile = profile(role: AppUserRole.customer);
    expect(
      resolveStartupDestination(authenticated: true, profile: serverProfile),
      StartupDestination.customerHome,
    );
  });

  test('stable idempotency key protects a repeated submit intent', () {
    final first = TajGoIdempotencyKey.stable('select-offer', ['o1', 'c1']);
    final second = TajGoIdempotencyKey.stable('select-offer', ['o1', 'c1']);
    final other = TajGoIdempotencyKey.stable('select-offer', ['o1', 'c2']);
    expect(first, second);
    expect(first, isNot(other));
    expect(first.length, greaterThanOrEqualTo(12));
  });

  test('offer states preserve pending and terminal outcomes', () {
    expect(courierOfferStatusFromString(null), CourierOfferStatus.pending);
    expect(
      courierOfferStatusFromString('accepted'),
      CourierOfferStatus.accepted,
    );
    expect(
      courierOfferStatusFromString('withdrawn'),
      CourierOfferStatus.withdrawn,
    );
    expect(courierOfferStatusFromString('expired'), CourierOfferStatus.expired);
  });

  test('final price becomes the effective locked price', () {
    const order = TajGoOrder(
      id: 'order-1',
      customerId: 'customer-1',
      customerName: 'Customer',
      status: OrderStatus.accepted,
      type: 'parcel',
      city: 'Khujand',
      fromText: 'A',
      toText: 'B',
      price: 35,
      finalPrice: 35,
      clientPrice: 25,
      currency: 'TJS',
    );
    expect(order.isFinalPriceLocked, isTrue);
    expect(order.effectivePrice, 35);
  });

  test('delivery code input accepts exactly four digits', () {
    expect(isValidDeliveryCodeInput(' 4321 '), isTrue);
    expect(isValidDeliveryCodeInput('432'), isFalse);
    expect(isValidDeliveryCodeInput('43a1'), isFalse);
    expect(isValidDeliveryCodeInput('43210'), isFalse);
  });

  test('safe error mapping hides internal server details', () {
    final error = TajGoCommandException.safe(
      code: 'internal',
      serverMessage: 'projects/secret/databases/private stack trace',
    );
    expect(error.retryable, isTrue);
    expect(error.message, isNot(contains('projects/secret')));
    expect(error.message, isNot(contains('stack trace')));
  });

  test('price-changed response updates the cart from server values', () {
    const partner = MarketplacePartner(
      id: 'partner-1',
      name: 'Shop',
      category: 'groceries',
      address: 'Khujand',
      location: GeoPoint(40.28, 69.62),
      deliveryFee: 10,
    );
    const product = MarketplaceProduct(
      id: 'product-1',
      partnerId: 'partner-1',
      name: 'Milk',
      price: 10,
    );
    final cart = MarketplaceCart()..add(partner, product);
    final error = TajGoCommandException.safe(
      code: 'failed-precondition',
      rawDetails: {
        'reason': 'price-changed',
        'currentPrices': {'product-1': 15},
      },
    );
    cart.applyServerPrices(error.currentPrices);
    expect(error.isPriceChanged, isTrue);
    expect(cart.subtotal, 15);
    expect(cart.total, 25);
  });

  test('released courier displays no active-order state', () {
    const released = TajGoCourier(
      uid: 'courier-1',
      displayName: 'Courier',
      city: 'Khujand',
      isOnline: true,
      rating: 5,
      transport: 'bicycle',
      earningsToday: 40,
      activeOrderId: null,
      isBusy: false,
    );
    expect(released.activeOrderId, isNull);
    expect(released.isBusy, isFalse);
    expect(released.online, isTrue);
  });

  test('preview and test partners are blocked before checkout', () {
    const preview = MarketplacePartner(
      id: 'preview',
      name: 'Preview',
      category: 'food',
      address: 'Khujand',
      location: GeoPoint(40.28, 69.62),
      isPreview: true,
      isTest: true,
    );
    expect(isMarketplaceCheckoutBlocked(preview), isTrue);
  });

  test('legacy statuses and missing catalog flags remain readable', () {
    expect(orderStatusFromString('waiting'), OrderStatus.waiting);
    expect(orderStatusFromString('courierSelected'), OrderStatus.accepted);
    expect(orderStatusFromString('arrivedPickup'), OrderStatus.accepted);
    expect(orderStatusFromString('arrivedDropoff'), OrderStatus.pickedUp);
    final legacyPartner = MarketplacePartner.fromMap('legacy', {
      'name': 'Legacy shop',
      'category': 'food',
      'address': 'Khujand',
      'location': const GeoPoint(40.28, 69.62),
      'isActive': true,
    });
    expect(legacyPartner.isTest, isFalse);
    expect(legacyPartner.isPreview, isFalse);
  });
}
