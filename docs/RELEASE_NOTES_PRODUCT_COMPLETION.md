# TajGo 1.2.0+27 — Courier Product Completion

## Новое

- полный экран «Стать курьером»;
- пошаговая анкета из пяти этапов;
- сохраняемый draft и продолжение с последнего шага;
- статусы pending, approved, rejected и suspended;
- причины отказа/блокировки и повторная отправка;
- транзакционная админская очередь заявок с журналом действий;
- сохранение customer role при всех решениях;
- создание/объединение private/public профилей при approve;
- четыре экрана onboarding после первого одобрения;
- запрет online до approve и завершения onboarding;
- сохранение активного заказа при suspension;
- фильтрация собственного заказа из ленты курьера;
- локальные Firestore Rules для нового домена заявок.

## Технические изменения

- добавлены `CourierApplication` и `CourierApplicationRepository`;
- `AppUser` получил `courierOnboardingCompleted`;
- Startup Router распознаёт обязательный onboarding;
- `TajGoScope` предоставляет репозиторий заявок;
- AdminHome показывает live-счётчик pending;
- legacy-профили мигрируются без дублей и потери статистики;
- версия проекта повышена до `1.2.0+27`.

## Без изменений

- Firebase project и `firebase_options.dart`;
- Android applicationId `tj.tajgo.app`;
- Phone Auth foundation;
- платежи;
- карта и алгоритмы routing v1.0.4;
- Firebase deploy не выполнялся.

## Известные ограничения

- Firebase Storage не настроен: документы проверяются через явно обозначенную личную встречу;
- обновлённые Rules находятся только локально до отдельного review/deploy;
- admin role пока должна назначаться вне мобильного клиента;
- push-уведомления о новых заявках отсутствуют;
- требуется физический end-to-end тест customer/admin/courier.

## Обновление

Это интегрированная debug-сборка поверх Account Foundation v1.1.0 и карты v1.0.4. После установки проверить сценарий из `PRODUCT_V1_OWNER_TEST_PLAN.md`. До production-пилота отдельно настроить Storage, развернуть проверенные Rules, провести тест на физических телефонах и подготовить release signing.
