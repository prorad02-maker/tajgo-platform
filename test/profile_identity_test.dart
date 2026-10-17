import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/core/models/app_user.dart';
import 'package:tajgo/core/models/tajgo_courier.dart';
import 'package:tajgo/core/models/courier_application.dart';

// This document-only test double never initializes or subclasses the SDK at runtime.
// ignore: subtype_of_sealed_class
class ProfileDocument extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  String get id => 'actual-owner';
  @override
  Map<String, dynamic> data() => {
    'uid': 'wrong-legacy-id',
    'displayName': 'Курьер',
  };
}

void main() {
  test('user profile keeps its document identity despite an old uid field', () {
    final profile = AppUser.fromMap({
      'uid': 'wrong-legacy-id',
    }, uid: 'actual-owner');
    expect(profile.uid, 'actual-owner');
  });
  test(
    'courier actions target the courier document rather than a stored uid alias',
    () {
      expect(TajGoCourier.fromDoc(ProfileDocument()).uid, 'actual-owner');
    },
  );
  test(
    'courier application review targets the applicant document rather than a stored uid alias',
    () {
      expect(
        CourierApplication.fromMap({
          'uid': 'wrong-legacy-id',
        }, uid: 'actual-owner').uid,
        'actual-owner',
      );
    },
  );
}
