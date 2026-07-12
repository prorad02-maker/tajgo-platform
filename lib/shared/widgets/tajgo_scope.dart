import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/courier_repository.dart';
import '../../core/services/order_repository.dart';
import '../../core/services/user_repository.dart';
import '../../features/map/services/tajgo_location_service.dart';

class TajGoScope extends InheritedWidget {
  TajGoScope({super.key, required super.child})
    : authService = AuthService(FirebaseAuth.instance),
      userRepository = UserRepository(FirebaseFirestore.instance),
      courierRepository = CourierRepository(FirebaseFirestore.instance),
      orderRepository = OrderRepository(FirebaseFirestore.instance),
      locationService = TajGoLocationService();

  final AuthService authService;
  final UserRepository userRepository;
  final CourierRepository courierRepository;
  final OrderRepository orderRepository;
  final TajGoLocationService locationService;

  static TajGoScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TajGoScope>();
    assert(scope != null, 'TajGoScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(TajGoScope oldWidget) => false;
}
