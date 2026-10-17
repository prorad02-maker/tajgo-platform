import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajgo/core/config/app_environment.dart';
import 'package:tajgo/core/config/feature_flags.dart';
import 'package:tajgo/core/models/app_user.dart';
import 'package:tajgo/core/models/courier_offer.dart';
import 'package:tajgo/core/models/marketplace_cart.dart';
import 'package:tajgo/core/models/marketplace_partner.dart';
import 'package:tajgo/core/models/marketplace_product.dart';
import 'package:tajgo/core/models/merchant_application.dart';
import 'package:tajgo/core/models/tajgo_courier.dart';
import 'package:tajgo/core/models/tajgo_order.dart';
import 'package:tajgo/core/services/account_migration_service.dart';
import 'package:tajgo/core/services/account_mode_service.dart';
import 'package:tajgo/core/services/admin_repository.dart';
import 'package:tajgo/core/services/auth_service.dart';
import 'package:tajgo/core/services/courier_application_repository.dart';
import 'package:tajgo/core/services/courier_offer_repository.dart';
import 'package:tajgo/core/services/courier_repository.dart';
import 'package:tajgo/core/services/diagnostic_service.dart';
import 'package:tajgo/core/services/external_navigator_service.dart';
import 'package:tajgo/core/services/marketplace_repository.dart';
import 'package:tajgo/core/services/merchant_application_repository.dart';
import 'package:tajgo/core/services/order_notification_service.dart';
import 'package:tajgo/core/services/order_repository.dart';
import 'package:tajgo/core/services/role_preference_service.dart';
import 'package:tajgo/core/services/route_service.dart';
import 'package:tajgo/core/services/saved_address_repository.dart';
import 'package:tajgo/core/services/user_repository.dart';
import 'package:tajgo/features/map/services/tajgo_location_service.dart';
import 'package:tajgo/shared/widgets/tajgo_scope.dart';

class FixtureUser extends Fake implements User {
  @override
  String get uid => 'ui-fixture';
  @override
  String get phoneNumber => '+992900000001';
  @override
  bool get isAnonymous => false;
}

class FixtureAuth extends Fake implements AuthService {
  @override
  User? get currentUser => FixtureUser();
}

class FixtureUsers extends Fake implements UserRepository {
  Stream<AppUser?>? streamOverride;
  Future<AppUser?>? getOverride;
  int getCalls = 0;
  AppUser? profile = AppUser.fromMap({
    'displayName': 'Мадина',
    'phoneNumber': '+992900000001',
    'phoneVerified': true,
    'role': 'customer',
    'roles': ['customer', 'courier'],
    'courierStatus': 'approved',
    'courierOnboardingCompleted': true,
    'profileComplete': true,
  }, uid: 'ui-fixture');
  bool fail = false;
  @override
  Future<AppUser?> getUser(String uid) async {
    getCalls++;
    if (getOverride != null) return getOverride!;
    if (fail) throw StateError('PRIVATE BACKEND DETAILS');
    return profile;
  }

  @override
  Stream<AppUser?> userStream(String uid) =>
      streamOverride ??
      (fail
          ? Stream.error(StateError('PRIVATE BACKEND DETAILS'))
          : Stream.value(profile));
}

class FixtureOrders extends Fake implements OrderRepository {
  String? deliveryCode;
  @override
  Stream<String?> customerDeliveryCodeStream(
    String orderId, {
    bool serverV1 = false,
  }) => Stream.value(deliveryCode);
  bool fail = false;
  bool activeFail = false;
  int subscriptions = 0;
  List<TajGoOrder> orders = [];
  Stream<List<TajGoOrder>> _stream() {
    subscriptions++;
    return fail
        ? Stream.error(StateError('PRIVATE BACKEND DETAILS'))
        : Stream.value(orders);
  }

  @override
  Stream<List<TajGoOrder>> customerOrdersStream(
    String uid, {
    int limit = 100,
  }) => _stream();
  @override
  Stream<List<TajGoOrder>> recentOrdersStream(String uid) => _stream();
  @override
  Stream<List<TajGoOrder>> historyStream(String uid) => _stream();
  @override
  Stream<TajGoOrder?> activeOrderStream(String uid) => activeFail
      ? Stream.error(StateError('PRIVATE BACKEND DETAILS'))
      : Stream.value(null);
}

class FixtureCourier extends Fake implements CourierRepository {
  List<TajGoOrder> waitingOrders = [];
  bool waitingFail = false;
  int waitingSubscriptions = 0;
  @override
  Future<void> updateLocation({
    required String uid,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    double? accuracy,
    bool force = false,
  }) async {}
  @override
  Stream<List<TajGoCourier>> onlineCouriersStream() => Stream.value([]);
  bool failEnsure = false;
  Object? ensureError;
  TajGoCourier? cachedCourier;
  TajGoOrder? activeOrder;
  @override
  Future<void> ensureCourierProfile({
    required String uid,
    String? phoneNumber,
    String? displayName,
    String city = 'Худжанд',
  }) async {
    if (ensureError != null) throw ensureError!;
    if (failEnsure) throw StateError('PRIVATE BACKEND DETAILS');
  }

  @override
  Stream<TajGoCourier?> courierStream(String uid) => Stream.value(
    cachedCourier ??
        const TajGoCourier(
          uid: 'ui-fixture',
          displayName: 'Рахим',
          city: 'Худжанд',
          isOnline: false,
          rating: 4.9,
          transport: 'bicycle',
          earningsToday: 140,
          ordersToday: 7,
        ),
  );
  @override
  Stream<List<TajGoOrder>> historyStream(String uid) => Stream.value([]);
  @override
  Stream<List<TajGoOrder>> waitingOrdersStream() {
    waitingSubscriptions++;
    return waitingFail
        ? Stream.error(StateError('PRIVATE BACKEND DETAILS'))
        : Stream.value(waitingOrders);
  }

  @override
  Future<TajGoCourier?> getCourier(String uid) async => cachedCourier;
  @override
  Stream<TajGoOrder?> orderStream(String id) => Stream.value(activeOrder);
}

class FixtureAdmin extends Fake implements AdminRepository {
  @override
  Stream<List<TajGoOrder>> ordersStream({int limit = 100}) => Stream.value([]);
  @override
  Stream<List<TajGoOrder>> todayOrdersStream() => Stream.value([]);
  @override
  Stream<List<TajGoCourier>> couriersStream() => Stream.value([]);
}

class FixtureMarketplace extends Fake implements MarketplaceRepository {
  bool fail = false;
  @override
  Stream<List<MarketplacePartner>> partnersStream({
    String? category,
    bool allowPreview = false,
  }) => fail
      ? Stream.error(StateError('PRIVATE BACKEND DETAILS'))
      : Stream.value([]);
  @override
  Stream<List<MarketplaceProduct>> publishedProductsStream() =>
      Stream.value([]);
}

class FixtureApplications extends Fake implements CourierApplicationRepository {
  @override
  Stream<int> pendingCountStream() => Stream.value(0);
}

class FixtureMerchants extends Fake implements MerchantApplicationRepository {
  @override
  Stream<List<MerchantApplication>> allApplicationsStream() => Stream.value([]);
}

class FixtureNavigator extends Fake implements ExternalNavigatorService {
  NavigatorPreference preference = const NavigatorPreference();
  @override
  Future<NavigatorPreference> load() async => preference;
}

class UnusedMode extends Fake implements AccountModeService {}

class UnusedMigration extends Fake implements AccountMigrationService {}

class UnusedRoles extends Fake implements RolePreferenceService {}

class FixtureOffers extends Fake implements CourierOfferRepository {
  List<CourierOffer> offers = [];
  bool fail = false;
  int subscriptions = 0;
  @override
  Stream<List<CourierOffer>> offersStream(String orderId) {
    subscriptions++;
    return fail
        ? Stream.error(StateError('PRIVATE BACKEND DETAILS'))
        : Stream.value(offers);
  }
}

class UnusedAddresses extends Fake implements SavedAddressRepository {}

class UnusedLocation extends Fake implements TajGoLocationService {}

class FixturePreferences extends Fake implements SharedPreferencesAsync {
  @override
  Future<bool?> getBool(String key) async => null;
  @override
  Future<String?> getString(String key) async => null;
}

/// These adapters never access Firebase or a phone. They exercise production
/// screen rendering with deterministic data, including failures and retries.
class UiFixture {
  TajGoLocationService? locationOverride;
  final users = FixtureUsers();
  final orders = FixtureOrders();
  final courier = FixtureCourier();
  final offers = FixtureOffers();
  final marketplace = FixtureMarketplace();
  final navigator = FixtureNavigator();
  final notifications = OrderNotificationService(
    supported: false,
    preferences: FixturePreferences(),
  );
  final diagnostics = DiagnosticService(
    supported: false,
    preferences: FixturePreferences(),
  );
  final cart = MarketplaceCart();
  Widget wrap(
    Widget child, {
    AuthService? authService,
    UserRepository? userRepository,
    TajGoLocationService? locationService,
  }) => TajGoScope.withServices(
    authService: authService ?? FixtureAuth(),
    userRepository: userRepository ?? users,
    accountModeService: UnusedMode(),
    accountMigrationService: UnusedMigration(),
    rolePreferenceService: UnusedRoles(),
    adminRepository: FixtureAdmin(),
    courierRepository: courier,
    courierOfferRepository: offers,
    courierApplicationRepository: FixtureApplications(),
    orderRepository: orders,
    routeService: RouteService(),
    locationService: locationService ?? locationOverride ?? UnusedLocation(),
    externalNavigatorService: navigator,
    marketplaceRepository: marketplace,
    merchantApplicationRepository: FixtureMerchants(),
    savedAddressRepository: UnusedAddresses(),
    notificationService: notifications,
    diagnosticService: diagnostics,
    marketplaceCart: cart,
    featureFlags: FeatureFlags.forEnvironment(AppEnvironment.production),
    child: child,
  );
  void dispose() {
    notifications.dispose();
    diagnostics.dispose();
    cart.dispose();
  }
}
