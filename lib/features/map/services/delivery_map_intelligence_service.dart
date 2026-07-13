import '../../../core/models/tajgo_order.dart';
import '../models/delivery_map_intelligence.dart';

class DeliveryMapIntelligenceService {
  const DeliveryMapIntelligenceService();

  DeliveryMapIntelligence forOrder(TajGoOrder order) {
    final isPickup = order.status == OrderStatus.accepted;
    final comment = order.comment?.trim() ?? '';
    return DeliveryMapIntelligence(
      targetLabel: isPickup ? 'A · Забрать' : 'B · Доставить',
      actionHint: isPickup
          ? 'Следующая цель — точка забора'
          : 'Следующая цель — клиент',
      note: comment.isEmpty
          ? isPickup
                ? 'Уточните ориентир у отправителя, если точка неточная.'
                : 'Передайте заказ только после проверки кода.'
          : comment,
      showConfirmationCode: !isPickup,
      isPickup: isPickup,
    );
  }
}
