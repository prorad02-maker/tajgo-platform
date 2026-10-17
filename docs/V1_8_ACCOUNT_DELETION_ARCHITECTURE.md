# TajGo v1.8 — Account Deletion Architecture

Статус: реализовано (Part 2, P0.1). Backend-authoritative, покрыто тестами.

## Обзор

Удаление аккаунта — self-service поток, доступный из приложения и описанный на
публичной web-странице. Критическую операцию выполняет callable Function
`deleteAccountRequest`; клиент только собирает подтверждение и повторную
авторизацию. Персональные данные обезличиваются, обязательная операционная
история сохраняется в обезличенном виде, вход завершается.

## Клиентский flow (in-app)

Путь: Профиль → «Безопасность и данные» → «Удалить аккаунт».

Экран `AccountDeletionScreen` (`lib/features/account/account_deletion_screen.dart`):

1. **Проверка права.** `orderRepository.hasActiveOrder(uid)` + courier
   `activeOrderId`/`isBusy`. При активном заказе удаление заблокировано с
   понятным сообщением.
2. **Последствия и данные.** Показ категорий, которые будут удалены/обезличены и
   которые сохраняются обезличенно (см. ниже).
3. **Повторная авторизация.** Для пользователей с подтверждённым номером —
   SMS-код и `AuthService.reauthenticateWithSmsCode` (обновляет «recent login» и
   подтверждает владение номером). Debug/тестовые аккаунты без номера этот шаг
   пропускают.
4. **Финальное подтверждение.** Явный чекбокс необратимости.
5. **Вызов Function** `deleteAccountRequest` → `signOut` → возврат на стартовый
   экран.

Все состояния (loading/blocked/error) обрабатываются; технические ошибки
пользователю не показываются.

## Backend Function `deleteAccountRequest`

`functions/src/core.ts`, регион `europe-west1`. Контракт: `{ idempotencyKey,
reason? }`. Гарантии:

- **Auth обязателен** (обёртка callable). Идентичность подтверждается клиентским
  re-auth перед вызовом.
- **Idempotent** через `command_results` (`runIdempotent`).
- **Запрет при активном заказе.** В транзакции читаются: профиль, courier,
  и запрос активных заказов клиента (`orders where customerId == uid and status
  in [draft, waiting, waitingOffers, courierSelected, accepted, arrivedPickup,
  pickedUp, arrivedDropoff, delivered, disputed] limit 1`). Также проверяется
  courier `activeOrderId`/`isBusy`. Иначе `failed-precondition`,
  `reason: active-order`.
- **Анонимизация профиля** (`users/{uid}`): `displayName`/`name` →
  «Удалённый пользователь», `phoneNumber: null`, `phoneVerified: false`,
  `role: deleted`, `roles: []`, `courierStatus: none`, `deleted: true`,
  `deletedAt`.
- **Анонимизация курьера** (если есть `couriers/{uid}`): имя обезличено,
  `phoneNumber: null`, `isOnline/online: false`, `deleted: true`; публичная
  проекция `courier_public/{uid}` удаляется.
- **Запись запроса** `account_deletion_requests/{uid}`: `status: completed`,
  `method: in-app`, `anonymizedCategories`, `retainedCategories`, timestamps.
- **Audit log** `admin_logs` (`action: account.delete.self`).
- **Best-effort удаление Firebase Auth** (`getAuth().deleteUser(uid)`) вне
  транзакции; сбой не откатывает уже зафиксированную анонимизацию (инъектируемо
  для тестов).

## Firestore Rules

`account_deletion_requests/{uid}`: `get` — владелец или admin; `list` — admin;
`create/update/delete` — запрещены (пишет только Function). Прямые критические
записи невозможны.

## Политика данных

| Категория | Действие |
|---|---|
| Имя, номер телефона, `phoneVerified` | обезличиваются/обнуляются |
| Присутствие курьера, геолокация, публичная проекция | обезличиваются/удаляются |
| Токены уведомлений (FCM) | деактивируются при реализации FCM (P3) |
| Сохранённые адреса | удаляются при реализации saved addresses (P1) |
| История заказов | сохраняется, привязка к PII разорвана (профиль обезличен) |
| Спорные заказы, обязательные операционные записи | сохраняются обезличенно |

Полная перезапись PII-полей в исторических документах заказов (customerName и
т.п.) — задача планового backend-джоба (owner/scheduled), задокументирована как
DEPLOY_REQUIRED; профиль уже обезличен и является источником идентичности.

## Тесты

- Functions integration (emulator): анонимизация профиля + запись запроса +
  audit log; запрет при активном заказе; удаление courier presence и public doc;
  идемпотентность по ключу. (4 теста, все зелёные.)
- Rules (emulator): владелец/админ читают, чужой — нет, клиент не пишет.
- Unit-логика домена не затронута.

## Что требует владельца / deploy

- Deploy обновлённых Functions и Rules (owner, вне репозитория).
- Хостинг web-страницы удаления (см. `V1_8_ACCOUNT_DELETION_WEB_PAGE.md`) и URL в
  Google Play Data Safety / App Store.
- (Опционально) плановый job для обезличивания PII в исторических заказах.
