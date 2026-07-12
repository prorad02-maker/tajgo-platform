import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/core/models/tajgo_order.dart';
import 'package:latlong2/latlong.dart';
import 'package:tajgo/core/services/pricing.dart';

void main() {
  test('неизвестный статус заказа считается ожидающим', () {
    expect(orderStatusFromString('legacy'), OrderStatus.waiting);
    expect(orderStatusToString(OrderStatus.pickedUp), 'pickedUp');
  });

  test('расчёт расстояния, времени и цены', () {
    final distance = distanceKm(
      const LatLng(40.2833, 69.6222),
      const LatLng(40.2833, 69.6322),
    );
    expect(distance, closeTo(0.8, 0.2));
    expect(etaMinutes(2.5), 14);
    expect(suggestedPrice(0), 10);
    expect(suggestedPrice(2.5), 20);
  });
}
