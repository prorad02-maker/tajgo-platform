# TajGo Pilot Core

## Контуры приложения

- `RoleOnboardingScreen` выбирает интерфейс клиента или курьера и сохраняет выбор локально и в `users/{uid}`.
- Клиент публикует `customDelivery` со своей ценой и выбирает одно предложение.
- Курьер видит ленты «Рядом / Дальше / Мой заказ». Предложение доступно только при свежем точном GPS и расстоянии до A меньше 1000 м.
- `CourierOfferRepository` выполняет создание и выбор предложения транзакционно.
- Map Core v0.8.7 остаётся единственным источником маршрута, ETA, follow-mode и fallback.

## Firestore

```text
users/{uid}
couriers/{uid}
courier_public/{uid}
orders/{orderId}
orders/{orderId}/offers/{courierId}
```

Один документ offer на курьера исключает дубликаты. При выборе offer заказ и курьер закрепляются одной транзакцией, остальные pending-offers закрываются.

## Совместимость

Старый `waiting` читается как `waitingOffers`, а `walking`, `foot` и `pedestrian` переводятся в `bicycle`. Firebase-проект и `firebase_options.dart` не менялись.
