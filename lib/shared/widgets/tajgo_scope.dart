import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/account_migration_service.dart';
import '../../core/services/account_mode_service.dart';
import '../../core/services/admin_repository.dart';
import '../../core/services/courier_repository.dart';
import '../../core/services/order_repository.dart';
import '../../core/services/route_service.dart';
import '../../core/services/user_repository.dart';
import '../../features/map/services/tajgo_location_service.dart';

class TajGoScope extends InheritedWidget {
  factory TajGoScope({Key? key, required Widget child}) {
    final db = FirebaseFirestore.instance;
    final auth = AuthService(FirebaseAuth.instance);
    final users = UserRepository(db);
    return TajGoScope._(
      key: key,
      authService: auth,
      userRepository: users,
      accountModeService: AccountModeService(auth, users),
      accountMigrationService: AccountMigrationService(db),
      adminRepository: AdminRepository(db),
      courierRepository: CourierRepository(db),
      orderRepository: OrderRepository(db),
      routeService: RouteService(),
      locationService: TajGoLocationService(),
      child: child,
    );
  }

  const TajGoScope._({
    super.key,
    required super.child,
    required this.authService,
    required this.userRepository,
    required this.accountModeService,
    required this.accountMigrationService,
    required this.adminRepository,
    required this.courierRepository,
    required this.orderRepository,
    required this.routeService,
    required this.locationService,
  });

  final AuthService authService;
  final UserRepository userRepository;
  final AccountModeService accountModeService;
  final AccountMigrationService accountMigrationService;
  final AdminRepository adminRepository;
  final CourierRepository courierRepository;
  final OrderRepository orderRepository;
  final RouteService routeService;
  final TajGoLocationService locationService;

  static TajGoScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TajGoScope>();
    assert(scope != null, 'TajGoScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(TajGoScope oldWidget) => false;
}
