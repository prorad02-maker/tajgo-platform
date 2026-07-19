import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/account_migration_service.dart';
import '../../core/services/account_mode_service.dart';
import '../../core/services/admin_repository.dart';
import '../../core/services/courier_repository.dart';
import '../../core/services/courier_offer_repository.dart';
import '../../core/services/courier_application_repository.dart';
import '../../core/services/external_navigator_service.dart';
import '../../core/services/marketplace_repository.dart';
import '../../core/services/order_repository.dart';
import '../../core/services/route_service.dart';
import '../../core/services/user_repository.dart';
import '../../core/services/role_preference_service.dart';
import '../../features/map/services/tajgo_location_service.dart';
import '../../core/models/marketplace_cart.dart';

class TajGoScope extends InheritedWidget {
  factory TajGoScope({Key? key, required Widget child}) {
    final db = FirebaseFirestore.instance;
    final auth = AuthService(FirebaseAuth.instance);
    final users = UserRepository(db);
    final rolePreferences = RolePreferenceService();
    return TajGoScope._(
      key: key,
      authService: auth,
      userRepository: users,
      accountModeService: AccountModeService(auth, users, rolePreferences),
      rolePreferenceService: rolePreferences,
      accountMigrationService: AccountMigrationService(db),
      adminRepository: AdminRepository(db),
      courierRepository: CourierRepository(db),
      courierOfferRepository: CourierOfferRepository(db),
      courierApplicationRepository: CourierApplicationRepository(db),
      orderRepository: OrderRepository(db),
      routeService: RouteService(),
      locationService: TajGoLocationService(),
      externalNavigatorService: ExternalNavigatorService(),
      marketplaceRepository: MarketplaceRepository(db),
      marketplaceCart: MarketplaceCart(),
      child: child,
    );
  }

  const TajGoScope._({
    super.key,
    required super.child,
    required this.authService,
    required this.userRepository,
    required this.accountModeService,
    required this.rolePreferenceService,
    required this.accountMigrationService,
    required this.adminRepository,
    required this.courierRepository,
    required this.courierOfferRepository,
    required this.courierApplicationRepository,
    required this.orderRepository,
    required this.routeService,
    required this.locationService,
    required this.externalNavigatorService,
    required this.marketplaceRepository,
    required this.marketplaceCart,
  });

  final AuthService authService;
  final UserRepository userRepository;
  final AccountModeService accountModeService;
  final RolePreferenceService rolePreferenceService;
  final AccountMigrationService accountMigrationService;
  final AdminRepository adminRepository;
  final CourierRepository courierRepository;
  final CourierOfferRepository courierOfferRepository;
  final CourierApplicationRepository courierApplicationRepository;
  final OrderRepository orderRepository;
  final RouteService routeService;
  final TajGoLocationService locationService;
  final ExternalNavigatorService externalNavigatorService;
  final MarketplaceRepository marketplaceRepository;
  final MarketplaceCart marketplaceCart;

  static TajGoScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TajGoScope>();
    assert(scope != null, 'TajGoScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(TajGoScope oldWidget) => false;
}
