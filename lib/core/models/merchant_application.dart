import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class MerchantStatus {
  static const draft = 'draft';
  static const submitted = 'submitted';
  static const underReview = 'underReview';
  static const needsInfo = 'needsInfo';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const convertedToPartner = 'convertedToPartner';
  static const withdrawn = 'withdrawn';

  static const terminal = {convertedToPartner, rejected, withdrawn};
  static const inReview = {submitted, underReview, approved};

  static String label(String status) => switch (status) {
    draft => 'Черновик',
    submitted => 'Отправлена',
    underReview => 'На рассмотрении',
    needsInfo => 'Нужны данные',
    approved => 'Одобрена',
    rejected => 'Отклонена',
    convertedToPartner => 'Подключён магазин',
    withdrawn => 'Отозвана',
    _ => 'Заявка',
  };
}

abstract final class MerchantDeliveryMode {
  static const self = 'self';
  static const tajgo = 'tajgo';

  static String label(String mode) =>
      mode == self ? 'Своя доставка' : 'Доставка TajGo';
}

class MerchantApplication {
  const MerchantApplication({
    required this.id,
    required this.ownerId,
    required this.status,
    this.storeName = '',
    this.category = 'food',
    this.ownerName = '',
    this.phone = '',
    this.extraContact = '',
    this.address = '',
    this.location,
    this.workingHours = '',
    this.description = '',
    this.minimumOrder = 0,
    this.deliveryMode = MerchantDeliveryMode.tajgo,
    this.comment = '',
    this.priceFileUrl = '',
    this.consent = false,
    this.adminNote,
    this.convertedPartnerId,
    this.createdAt,
    this.updatedAt,
    this.submittedAt,
  });

  final String id;
  final String ownerId;
  final String status;
  final String storeName;
  final String category;
  final String ownerName;
  final String phone;
  final String extraContact;
  final String address;
  final GeoPoint? location;
  final String workingHours;
  final String description;
  final num minimumOrder;
  final String deliveryMode;
  final String comment;
  final String priceFileUrl;
  final bool consent;
  final String? adminNote;
  final String? convertedPartnerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? submittedAt;

  bool get canWithdraw => !{
    MerchantStatus.approved,
    MerchantStatus.convertedToPartner,
    MerchantStatus.withdrawn,
  }.contains(status);

  bool get isEditable =>
      status == MerchantStatus.draft || status == MerchantStatus.needsInfo;

  bool get needsInfo => status == MerchantStatus.needsInfo;

  factory MerchantApplication.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    return MerchantApplication(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? doc.id,
      status: data['status'] as String? ?? MerchantStatus.draft,
      storeName: data['storeName'] as String? ?? '',
      category: data['category'] as String? ?? 'food',
      ownerName: data['ownerName'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      extraContact: data['extraContact'] as String? ?? '',
      address: data['address'] as String? ?? '',
      location: data['location'] as GeoPoint?,
      workingHours: data['workingHours'] as String? ?? '',
      description: data['description'] as String? ?? '',
      minimumOrder: data['minimumOrder'] as num? ?? 0,
      deliveryMode:
          data['deliveryMode'] as String? ?? MerchantDeliveryMode.tajgo,
      comment: data['comment'] as String? ?? '',
      priceFileUrl: data['priceFileUrl'] as String? ?? '',
      consent: data['consent'] as bool? ?? false,
      adminNote: data['adminNote'] as String?,
      convertedPartnerId: data['convertedPartnerId'] as String?,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      submittedAt: _date(data['submittedAt']),
    );
  }

  static DateTime? _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };
}
