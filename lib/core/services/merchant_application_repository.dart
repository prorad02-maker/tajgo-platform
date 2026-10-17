import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/merchant_application.dart';
import 'authoritative_command_service.dart';

/// Заявки магазинов на подключение. Все записи — через authoritative Functions;
/// клиент только читает свою заявку (или admin — все).
class MerchantApplicationRepository {
  MerchantApplicationRepository(this._db, this._commands);

  final FirebaseFirestore _db;
  final AuthoritativeCommandService _commands;

  Stream<MerchantApplication?> myApplicationStream(String uid) =>
      applicationStream(uid);

  /// Поток одной заявки по id (id == uid заявителя). Для владельца и admin.
  Stream<MerchantApplication?> applicationStream(String id) => _db
      .collection('merchant_applications')
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? MerchantApplication.fromDoc(doc) : null);

  Stream<List<MerchantApplication>> allApplicationsStream() => _db
      .collection('merchant_applications')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(MerchantApplication.fromDoc).toList()
              ..sort(
                (a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(
                  a.updatedAt ?? DateTime(2000),
                ),
              ),
      );

  Future<void> saveDraft(Map<String, dynamic> fields) =>
      _commands.call('saveMerchantApplicationDraft', fields);

  Future<void> submit(String uid, Map<String, dynamic> fields) => _commands.call(
    'submitMerchantApplication',
    {
      ...fields,
      'idempotencyKey': TajGoIdempotencyKey.create('merchant-submit-$uid'),
    },
  );

  Future<void> update(Map<String, dynamic> fields) =>
      _commands.call('updateMerchantApplication', fields);

  Future<void> withdraw() =>
      _commands.call('withdrawMerchantApplication', const {});

  Future<void> review({
    required String applicationId,
    required String action,
    String? message,
  }) => _commands.call('adminReviewMerchantApplication', {
    'applicationId': applicationId,
    'action': action,
    if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
  });

  Future<String?> convert(String applicationId) async {
    final result = await _commands.call('adminConvertMerchantApplication', {
      'applicationId': applicationId,
      'idempotencyKey': TajGoIdempotencyKey.create('merchant-convert-$applicationId'),
    });
    return result['partnerId'] as String?;
  }
}
