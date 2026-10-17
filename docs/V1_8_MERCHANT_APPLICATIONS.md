# TajGo v1.8 — Merchant Applications (P0.3)

Статус: реализовано, backend-authoritative, покрыто тестами.

## Модель и статусы

Коллекция `merchant_applications/{uid}` (id = uid заявителя, одна активная заявка
на пользователя). Статусы:

```
draft -> submitted -> underReview -> approved -> convertedToPartner
                   \-> needsInfo -> submitted
      (submitted/underReview/needsInfo) -> rejected | withdrawn
```

Поля: storeName, category (food/groceries/flowers), ownerName, phone,
extraContact, address, location (GeoPoint), workingHours, description,
minimumOrder, deliveryMode (self/tajgo), comment, priceFileUrl?, consent,
adminNote, convertedPartnerId, timestamps.

## Callable Functions (europe-west1)

Пользователь: `saveMerchantApplicationDraft`, `submitMerchantApplication`
(idempotent, требует consent + обязательные поля + точку на карте),
`updateMerchantApplication` (только из needsInfo), `withdrawMerchantApplication`
(до approved/converted).

Admin: `adminReviewMerchantApplication({action: take|needsInfo|approve|reject,
message?})` с проверкой допустимых переходов и audit log;
`adminConvertMerchantApplication` — idempotent, из approved создаёт
**неопубликованный** черновик партнёра (`isActive=false, isPublished=false`,
`sourceApplicationId`), не создаёт дубликат, пишет audit log.

## Firestore Rules

`merchant_applications/{uid}`: владелец читает свою (`owner(uid)`), admin —
читает/листит все; прямые create/update/delete запрещены (только Functions).

## Клиент

- Профиль (клиент) → «Подключить свой магазин» (за флагом `merchantApplications`).
- `MerchantApplicationScreen`: intro / статус / маршрут к форме; отзыв; повторная
  подача после reject/withdraw.
- `MerchantApplicationFormScreen`: все поля, выбор точки через `MapPointPickerScreen`
  (переиспользуемый), согласие, черновик и отправка/обновление.

## Admin

- Дашборд → «Заявки магазинов» (счётчик в работе).
- `AdminMerchantApplicationsScreen`: фильтры (новые/в работе/нужны данные/
  одобрены/завершены).
- `AdminMerchantApplicationDetailsScreen`: все поля + действия (взять/одобрить/
  запросить данные/отклонить/создать магазин). Все действия — через Functions.

## Тесты

Functions integration (emulator): полный жизненный цикл draft→submit→needsInfo→
update→approve→convert; идемпотентность конвертации (один партнёр); non-admin не
может ревьюить; submit требует consent; withdraw заблокирован после конвертации.
Rules: владелец/admin читают, чужой — нет, клиент не пишет.

## Ограничения / owner

- Загрузка прайс-файла требует Firebase Storage (не входит в текущий scope) —
  сейчас поле `priceFileUrl` опционально (ссылка). Импорт прайса — отдельный
  admin-инструмент (P2).
- Публикация созданного партнёра выполняется вручную админом в разделе
  «Партнёры и товары».
- Deploy Functions/Rules — владелец.
