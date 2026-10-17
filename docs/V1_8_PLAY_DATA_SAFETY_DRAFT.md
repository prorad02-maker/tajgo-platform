# TajGo v1.8 — Google Play Data Safety (черновик)

Черновик для формы Data Safety в Google Play Console. Не является юридическим
заключением. Основано на `V1_8_PRIVACY_DATA_INVENTORY.md`.

## Общие ответы

- **Собираются ли данные?** Да.
- **Передаются ли данные третьим лицам (share)?** Нет (только обработчики —
  Firebase/Google как processor, не считается «sharing»).
- **Шифрование при передаче?** Да (TLS, Firebase SDK).
- **Можно ли запросить удаление данных?** Да — in-app и по URL
  (`V1_8_ACCOUNT_DELETION_WEB_PAGE.md`).
- **Deletion URL:** указать хостинг `public/account-deletion.html`.

## Категории данных (collected / processed)

| Data type | Collected | Purpose | Ephemeral? | Required? |
|---|---|---|---|---|
| Phone number | Yes | Account management, App functionality | No | Required |
| Name | Yes | App functionality | No | Required |
| Approximate/Precise location | Yes | App functionality (delivery) | Location collected only in-session | Optional (manual fallback) |
| Purchase/Order history | Yes | App functionality | No | Required |
| App activity (orders, in-app actions) | Yes | App functionality, Analytics (если включена) | No | Required |
| Crash logs / Diagnostics | Yes (если Crashlytics включён) | Crash prevention, Diagnostics | No | Optional |
| Messages/Notifications token | Yes (при FCM) | App functionality | No | Optional |

## Security practices

- Data is encrypted in transit.
- Users can request that data be deleted (in-app + web).
- Committed to Play Families / Data safety guidelines: критические операции на
  сервере, код получения не раскрывается.

## Data NOT collected

- Точная реклама/трекинг между приложениями — нет.
- Финансовые данные (карты) — нет (оплата вне приложения на этапе пилота).
- Контакты, фото/медиа (кроме будущих вложений заявок), аудио — нет.

## Перед публикацией (владелец)

- Включить/выключить строки Crashlytics и Notifications согласно фактическому
  состоянию флагов на релизе.
- Проставить Deletion URL после хостинга страницы.
- Проверить, что targetSdk и разрешения манифеста соответствуют заявленному.
