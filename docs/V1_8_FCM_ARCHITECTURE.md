# TajGo v1.8 — FCM Notifications (P3.1)

Статус: код завершён (client + backend triggers), **DEPLOY_REQUIRED** для активации.
За feature-флагом `notifications`, graceful fallback (отсутствие настройки в
Firebase Console не ломает приложение).

## Клиент

`lib/core/services/push_notification_service.dart`:

- `initialize(enabled, navigatorKey)` — регистрирует background-handler
  (top-level, no-op по секретам), foreground- и tap-обработчики. Вызывается из
  `_NotificationsHost` под `TajGoScope` после первого кадра. Разрешение здесь
  **не** запрашивается.
- `enableForUser(uid)` — запрашивает permission (после pre-permission объяснения
  в Настройках) и сохраняет токен в `users/{uid}/notification_tokens/{token}`
  ({token, platform, active, createdAt, updatedAt, lastSeenAt}). Подписка на
  `onTokenRefresh`.
- `disableForUser(uid)` — деактивирует токен на logout (не удаляет).
- Tap → навигация к `OrderTrackingScreen` по `data.orderId` через глобальный
  `navigatorKey`.

Permission UX: включение — в Профиль → Настройки → «Уведомления» с pre-permission
диалогом. Android 13+ `POST_NOTIFICATIONS` объявлен в манифесте, запрашивается
по требованию.

Rules: `users/{uid}/notification_tokens/{tokenId}` — владелец read/write
(некритические данные); backend-senders читают их admin-SDK.

## Backend (триггеры)

`functions/src/notifications.ts` (экспортированы из `index.ts`):

- `onOrderStatusChanged` — Firestore-триггер `orders/{orderId}` onUpdate: при
  смене статуса строит privacy-safe уведомление и шлёт токенам клиента.
- `onOfferCreated` — `orders/{orderId}/offers/{courierId}` onCreate: уведомляет
  клиента о новых предложениях.

Отправка — `getMessaging().sendEachForMulticast`, только активным токенам, ошибки
проглатываются с логом (без PII).

## Privacy payload

`functions/src/domain.ts`:

- `orderStatusNotification(status, orderId)` / `offerReceivedNotification(orderId)`
  — заголовок/тело без кода получения, полного телефона и адреса; в `data` только
  `type`, `orderId`, `status`.
- `notificationLeaksSensitiveData(...)` — проверка на утечку (используется в тесте).

Тесты: `functions/test/unit/domain.test.ts` — payload не содержит code/phone/
address; неизвестный статус → null.

## События (карта)

Клиенту: новое предложение, курьер выбран/едет за заказом/забрал/едет к вам/
доставлено/отменено (через order status). Курьеру и admin — расширяется
дополнительными триггерами по мере необходимости (offer selected, active order
update, новая заявка).

## Что требует владельца (DEPLOY_REQUIRED)

1. Включить Cloud Messaging в проекте `tajgo-4fcd0`.
2. Задеплоить Functions (триггеры `onOrderStatusChanged`, `onOfferCreated`).
3. Задеплоить Rules (`notification_tokens`).
4. iOS: APNs-ключ в Firebase, `aps-environment` capability (Mac).
5. Проверить на двух телефонах: foreground/background/terminated tap,
   token refresh, logout-деактивация.

До деплоя основной flow не блокируется — приложение работает без push.
