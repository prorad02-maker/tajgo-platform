# TajGo v1.8 Part 1 — Authoritative Core

## Цель

Flutter отвечает за интерфейс, realtime-чтение и безопасные presence/GPS-записи. Все операции, которые меняют владельца, цену, статус, занятость курьера, итог каталога или код получения, выполняются callable Cloud Functions в `europe-west1`.

```text
Flutter -> callable + auth + idempotencyKey
        -> validation + role/ownership checks
        -> Firestore transaction + server timestamps
        -> safe result/error
        -> Firestore realtime streams -> Flutter
```

Источник роли — `users/{uid}`. `SharedPreferences` хранит только cache последнего режима. При запуске `ensureUserProfile` нормализует legacy-профиль, после чего router читает Firestore и исправляет локальный cache.

## Границы доверия

- Клиенту не доверяются `role`, `distanceMeters`, `finalPrice`, `total`, availability, status и результат проверки delivery code.
- Координаты курьера для радиуса читаются из `couriers/{uid}.location`.
- Принятие offer блокирует order и courier одной транзакцией.
- Повтор команды с тем же ключом возвращает `command_results`, а не повторяет mutation.
- Firestore Rules запрещают mobile create/update/delete для orders и offers.
- `couriers/{uid}` с клиента принимает только presence/location-поля.

## Коллекции authoritative core

- `users` — профиль и server role.
- `couriers` — приватное состояние курьера.
- `courier_public` — безопасное публичное presence-представление.
- `orders` и `orders/{orderId}/offers`.
- `order_secrets` — salt/hash/attempts, backend-only.
- `order_customer_codes` — открытый код, доступный только владельцу заказа.
- `command_results` — idempotency ledger, backend-only.
- `partners`, `products` — опубликованный каталог.
- `admin_logs` — неизменяемый журнал.

## Совместимость

Legacy `waiting` отображается как `waitingOffers`; `courierSelected` — как `accepted`; `arrivedPickup`/`arrivedDropoff` сохраняются без разрушения старых документов. Legacy `confirmationCode` мигрируется отдельной admin-командой и до миграции намеренно скрывает заказ от курьера.

## Не входит в Part 1

Настоящий turn-by-turn, платежи, push-уведомления, App Check enforcement, production deploy и store release относятся к следующим этапам.
