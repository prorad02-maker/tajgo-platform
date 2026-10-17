# TajGo v1.8 Part 1 — Delivery Code Security

## Новые заказы

При создании backend генерирует 4 цифры и в той же транзакции пишет:

- `order_secrets/{orderId}`: random salt, scrypt hash, failed attempts, lock;
- `order_customer_codes/{orderId}`: customerId и открытый код;
- `orders/{orderId}`: только `codeAvailable: true`, без кода.

Клиент читает код только из `order_customer_codes/{orderId}`. Courier Rules запрещают этот документ и `order_secrets`. Код не попадает в order list, navigator URI или Functions logs.

## Проверка

`completeDeliveryWithCode`:

- требует approved courier;
- проверяет назначение и статус;
- повторно проверяет свежий GPS у delivery point;
- сравнивает scrypt hash;
- блокирует после 5 неверных попыток;
- атомарно завершает order, освобождает courier и обновляет статистику;
- удаляет secret и customer code;
- создаёт audit log.

Customer confirmation и admin completion также удаляют оба code-документа.

## Legacy migration

Старый `orders.confirmationCode` небезопасен. Новые Rules не дают курьеру читать такой order до миграции.

Порядок:

1. Deploy Functions.
2. Войти реальным owner-admin.
3. В деталях каждого legacy-order нажать `Защитить legacy-код`.
4. Проверить `order_secrets` и `order_customer_codes`.
5. Проверить отсутствие `orders.confirmationCode`.
6. Только затем deploy Rules.

Команда `adminMigrateLegacyDeliveryCode` idempotent, требует admin и пишет audit log. Код нельзя переносить вручную в логи, issue tracker или документацию.
