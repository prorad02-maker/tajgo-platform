import 'package:cloud_firestore/cloud_firestore.dart';

import 'authoritative_command_service.dart';
import 'order_command_service.dart';

/// Existing server-v1 orders retain their original transaction and receipt
/// format. Never retry a failed server request as a direct Firestore write.
class CompatibleCommandGateway implements AuthoritativeCommandGateway {
  CompatibleCommandGateway(this._current, this._legacy, this._version);

  final AuthoritativeCommandGateway _current;
  final OrderCommandService _legacy;
  final Future<String?> Function(String orderId) _version;

  factory CompatibleCommandGateway.firebase(
    AuthoritativeCommandGateway current,
    FirebaseFirestore db,
  ) => CompatibleCommandGateway(
    current,
    OrderCommandService(),
    (id) async =>
        (await db.collection('orders').doc(id).get()).data()?['commandVersion']
            as String?,
  );

  @override
  String get region => _current.region;

  @override
  Future<Map<String, dynamic>> call(
    String command,
    Map<String, dynamic> data,
  ) async {
    final orderId = data['orderId'];
    if (orderId is! String ||
        !const {
          'cancelWaitingOrder',
          'cancelCatalogOrder',
          'updateDeliveryStatus',
          'completeDeliveryWithCode',
          'submitCourierOffer',
          'updateCourierOffer',
          'withdrawCourierOffer',
          'rejectCourierOffer',
          'selectCourierOffer',
          'adminCancelOrder',
          'adminResolveDispute',
          'adminReleaseCourier',
        }.contains(command) ||
        await _version(orderId) != 'server-v1') {
      return _current.call(command, data);
    }
    final action = switch (command) {
      'cancelWaitingOrder' || 'cancelCatalogOrder' => 'cancel',
      'submitCourierOffer' || 'updateCourierOffer' => 'offer',
      'withdrawCourierOffer' => 'withdraw',
      'rejectCourierOffer' => 'reject',
      'selectCourierOffer' => 'select',
      'completeDeliveryWithCode' => 'complete',
      'adminCancelOrder' => 'adminCancel',
      'adminReleaseCourier' => 'adminClear',
      'adminResolveDispute' => switch (data['resolution']) {
        'returnToWaiting' => 'adminReturn',
        'complete' => 'adminComplete',
        'markDisputed' => 'adminDispute',
        _ => null,
      },
      'updateDeliveryStatus' => switch (data['action']) {
        'arrivedPickup' => 'arrive',
        'pickedUp' => 'pickup',
        'delivered' => 'deliver',
        'customerConfirm' => 'confirm',
        'customerDispute' => 'dispute',
        _ => null,
      },
      _ => null,
    };
    if (action == null) {
      throw const TajGoCommandException(
        code: 'failed-precondition',
        message:
            'Это действие недоступно для старого заказа. Обратитесь в поддержку.',
      );
    }
    return _legacy.run(action, {
      'orderId': orderId,
      if (data.containsKey('offerId')) 'offerId': data['offerId'],
      if (data.containsKey('proposedPrice'))
        'proposedPrice': data['proposedPrice'],
      if (data.containsKey('code')) 'code': data['code'],
      if (data.containsKey('reason')) 'reason': data['reason'],
    });
  }
}
