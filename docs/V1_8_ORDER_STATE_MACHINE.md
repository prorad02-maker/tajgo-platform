# TajGo v1.8 Part 1 — Order State Machine

## Канонические статусы

```text
draft -> waitingOffers -> accepted -> arrivedPickup -> pickedUp
      -> arrivedDropoff -> delivered -> completed
```

Дополнительные ветви: `cancelled`, `disputed`.

Backend transitions курьера:

- `accepted -> arrivedPickup`
- `arrivedPickup -> pickedUp`
- `pickedUp -> arrivedDropoff` или `delivered`
- `arrivedDropoff -> delivered`

Клиент может:

- отменить только ожидающий order;
- перевести свой `delivered -> completed`;
- перевести свой `delivered -> disputed`.

Admin использует отдельные команды с причиной и audit log: cancel, release, complete, return-to-waiting и dispute.

## Назначение

`selectCourierOffer` одной транзакцией:

1. повторно читает order, offer, courier и courier user;
2. проверяет owner/status/expiry/role/online/busy/GPS/radius;
3. фиксирует `courierId`, `selectedCourierId`, `selectedOfferId`, `finalPrice`;
4. ставит `activeOrderId`, `currentOrderId`, `isBusy`;
5. принимает выбранный offer и закрывает остальные pending offers.

## Освобождение курьера

На `completed`, допустимой отмене и admin resolution:

- `activeOrderId = null`;
- `currentOrderId = null`;
- `isBusy = false`.

На completed также атомарно растут `ordersToday` и `earningsToday`.

## Legacy mapping

- `waiting` и `draft` -> `waitingOffers`;
- `courierSelected` -> `accepted`;
- `arrivedAtPickupAt` остаётся timestamp-полем, status — `arrivedPickup`;
- Flutter продолжает группировать `arrivedPickup` с accepted и `arrivedDropoff` с pickedUp.

Массовая автоматическая перезапись production-документов не выполняется.
