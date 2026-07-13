import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tajgo/core/models/tajgo_order.dart';
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
    expect(courierNavigationEtaMinutes(3), 10);
    expect(suggestedPrice(0), 10);
    expect(suggestedPrice(2.5), 20);
  });

  test('комментарий попадает в данные заказа только когда он не пустой', () {
    const withComment = TajGoOrder(
      id: '1',
      customerId: 'c1',
      customerName: 'Клиент',
      status: OrderStatus.waiting,
      type: 'package',
      city: 'Худжанд',
      fromText: 'A',
      toText: 'B',
      price: 15,
      currency: 'TJS',
      comment: 'Подъезд 2, этаж 3',
    );
    expect(withComment.toCreateMap()['comment'], 'Подъезд 2, этаж 3');

    const withoutComment = TajGoOrder(
      id: '2',
      customerId: 'c1',
      customerName: 'Клиент',
      status: OrderStatus.waiting,
      type: 'package',
      city: 'Худжанд',
      fromText: 'A',
      toText: 'B',
      price: 15,
      currency: 'TJS',
    );
    expect(withoutComment.toCreateMap().containsKey('comment'), isFalse);
  });

  test('код подтверждения и гео-гейт', () {
    final code = generateConfirmationCode(Random(7));
    expect(code, hasLength(4));
    expect(int.tryParse(code), isNotNull);
    expect(withinActionRadius(2), isTrue);
    expect(withinActionRadius(2.01), isFalse);
  });
}
