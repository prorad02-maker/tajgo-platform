import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_user.dart';

class CourierApplication {
  const CourierApplication({
    required this.uid,
    required this.displayName,
    required this.phoneNumber,
    required this.status,
    required this.currentStep,
    required this.transport,
    required this.documentType,
    required this.documentNumber,
    required this.city,
    required this.workDistrict,
    required this.availability,
    required this.termsAccepted,
    required this.dataConsent,
    required this.storageEnabled,
    required this.verificationMethod,
    required this.history,
    this.birthDate,
    this.profilePhotoUrl,
    this.documentPhotoUrl,
    this.transportPhotoUrl,
    this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    this.suspensionReason,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String? phoneNumber;
  final String status;
  final int currentStep;
  final String? birthDate;
  final String? profilePhotoUrl;
  final String transport;
  final String documentType;
  final String documentNumber;
  final String? documentPhotoUrl;
  final String? transportPhotoUrl;
  final String city;
  final String workDistrict;
  final String availability;
  final bool termsAccepted;
  final bool dataConsent;
  final bool storageEnabled;
  final String verificationMethod;
  final DateTime? submittedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final String? suspensionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<Map<String, dynamic>> history;

  bool get canSubmit =>
      displayName.trim().length >= 2 &&
      CourierTransport.values.contains(transport) &&
      documentType.trim().isNotEmpty &&
      documentNumber.trim().isNotEmpty &&
      termsAccepted &&
      dataConsent;

  bool get needsTransportPhoto => true;

  factory CourierApplication.empty({
    required String uid,
    required String displayName,
    String? phoneNumber,
  }) => CourierApplication(
    uid: uid,
    displayName: displayName,
    phoneNumber: phoneNumber,
    status: CourierStatus.draft,
    currentStep: 0,
    transport: CourierTransport.bicycle,
    documentType: CourierDocumentType.passport,
    documentNumber: '',
    city: 'Худжанд',
    workDistrict: 'Весь город',
    availability: 'Свободный график',
    termsAccepted: false,
    dataConsent: false,
    storageEnabled: courierStorageEnabled,
    verificationMethod: 'personalMeeting',
    history: const [],
  );

  factory CourierApplication.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => CourierApplication.fromMap(doc.data() ?? const {}, uid: doc.id);

  factory CourierApplication.fromMap(
    Map<String, dynamic> data, {
    required String uid,
  }) => CourierApplication(
    uid: data['uid'] as String? ?? uid,
    displayName:
        data['displayName'] as String? ?? data['name'] as String? ?? 'Курьер',
    phoneNumber: data['phoneNumber'] as String?,
    status: data['status'] as String? ?? CourierStatus.draft,
    currentStep: ((data['currentStep'] as num?)?.toInt() ?? 0).clamp(0, 4),
    birthDate: data['birthDate'] as String?,
    profilePhotoUrl: data['profilePhotoUrl'] as String?,
    transport: CourierTransport.normalize(data['transport'] as String?),
    documentType:
        data['documentType'] as String? ?? CourierDocumentType.passport,
    documentNumber: data['documentNumber'] as String? ?? '',
    documentPhotoUrl: data['documentPhotoUrl'] as String?,
    transportPhotoUrl: data['transportPhotoUrl'] as String?,
    city: data['city'] as String? ?? 'Худжанд',
    workDistrict: data['workDistrict'] as String? ?? 'Весь город',
    availability: data['availability'] as String? ?? 'Свободный график',
    termsAccepted: data['termsAccepted'] as bool? ?? false,
    dataConsent: data['dataConsent'] as bool? ?? false,
    storageEnabled: data['storageEnabled'] as bool? ?? false,
    verificationMethod:
        data['verificationMethod'] as String? ?? 'personalMeeting',
    submittedAt: _date(data['submittedAt']),
    reviewedBy: data['reviewedBy'] as String?,
    reviewedAt: _date(data['reviewedAt']),
    rejectionReason: data['rejectionReason'] as String?,
    suspensionReason: data['suspensionReason'] as String?,
    createdAt: _date(data['createdAt']),
    updatedAt: _date(data['updatedAt']),
    history: (data['history'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false),
  );

  Map<String, dynamic> toDraftMap() => {
    'uid': uid,
    'displayName': displayName.trim(),
    'name': displayName.trim(),
    'phoneNumber': phoneNumber,
    'status': CourierStatus.draft,
    'currentStep': currentStep.clamp(0, 4),
    if (birthDate?.trim().isNotEmpty == true) 'birthDate': birthDate!.trim(),
    if (profilePhotoUrl?.trim().isNotEmpty == true)
      'profilePhotoUrl': profilePhotoUrl!.trim(),
    'transport': transport,
    'documentType': documentType,
    'documentNumber': documentNumber.trim(),
    if (documentPhotoUrl?.trim().isNotEmpty == true)
      'documentPhotoUrl': documentPhotoUrl!.trim(),
    if (transportPhotoUrl?.trim().isNotEmpty == true)
      'transportPhotoUrl': transportPhotoUrl!.trim(),
    'city': city,
    'workDistrict': workDistrict,
    'availability': availability,
    'termsAccepted': termsAccepted,
    'dataConsent': dataConsent,
    'storageEnabled': storageEnabled,
    'verificationMethod': verificationMethod,
  };

  static DateTime? _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };
}

const bool courierStorageEnabled = bool.fromEnvironment(
  'COURIER_STORAGE_ENABLED',
  defaultValue: false,
);

abstract final class CourierTransport {
  /// Legacy only: never show this value in the UI.
  static const walking = 'walking';
  static const bicycle = 'bicycle';
  static const electricBike = 'electric_bike';
  static const scooter = 'scooter';
  static const car = 'car';
  static const values = {bicycle, scooter, car};

  static String normalize(String? value) => switch (value) {
    walking || 'pedestrian' || 'foot' => bicycle,
    electricBike => bicycle,
    bicycle || scooter || car => value!,
    _ => bicycle,
  };

  static String label(String value) => switch (value) {
    walking => 'Велосипед',
    bicycle => 'Велосипед',
    electricBike => 'Электровелосипед',
    scooter => 'Скутер',
    car => 'Автомобиль · позже',
    _ => value,
  };
}

abstract final class CourierDocumentType {
  static const passport = 'passport';
  static const idCard = 'id_card';
  static const values = {passport, idCard};

  static String label(String value) => switch (value) {
    idCard => 'Удостоверение личности',
    _ => 'Паспорт',
  };
}
