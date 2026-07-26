# TajGo — фактический GO / NO-GO

Дата: 26 июля 2026  
Проверенная версия: `1.5.0+30`  
Важно: официальной v1.7 в проекте не найдено.

## 1. Критерии

| Проверка | Статус | Доказательство / причина |
|---|---|---|
| Приложение анализируется | `PASS` | `flutter analyze`: no issues |
| Unit/widget tests | `PASS` | 66 passed, 0 failed |
| Debug APK собирается | `PASS` | `app-debug.apk`, exit 0 |
| Release APK собирается | `PASS` технически | `app-release.apk`, но debug-signed |
| Production release signing | `FAIL` | Нет `key.properties`, cert Android Debug |
| Android installation | `PHONE_REQUIRED` | Android device/emulator не подключён |
| Phone Auth code-flow | `PHONE_REQUIRED` | Код есть, SMS/Console/SHA не проверены |
| Новый пользователь | `NOT_VERIFIED` | Нет Auth/Firestore integration test |
| Повторный вход | `NOT_VERIFIED` | Нет physical/integration test |
| Anonymous fallback скрыт в release | `PASS` | `kDebugMode` |
| Customer/courier role flow | `NOT_VERIFIED` | Decision logic есть, two-phone/offline test нет |
| Admin role защищён | `FAIL` как продукт | Rules предполагают admin, но admin UI недостижим |
| CustomerHome доступен | `PASS` на уровне кода | Маршрут и UI подключены |
| Custom order создаётся | `NOT_VERIFIED` end-to-end | Client repository есть; живой Firestore flow не запускался |
| Offers создаются/обновляются | `NOT_VERIFIED` end-to-end | Client transaction есть |
| Клиент выбирает courier | `NOT_VERIFIED` end-to-end | Transaction есть, races не тестировались |
| Радиус `<1000 м` защищён | `FAIL` | Только client-side, modified client bypass |
| Один active order защищён | `NOT_VERIFIED` | Client transaction + local Rules; deploy/races неизвестны |
| Delivery code безопасен | `FAIL` | Courier читает code; Rules code не проверяют |
| Status machine согласована | `FAIL` полностью | Compatibility и admin/dispute inconsistencies |
| Catalog checkout authoritative | `FAIL` | Items/prices не сверяются backend |
| Preview checkout заблокирован | `PASS` на UI | `isPreview` отключает checkout |
| Marketplace admin доступен | `FAIL` | Admin screens не достижимы |
| GPS permission/stream | `PHONE_REQUIRED` | Код и manifest есть |
| Live customer tracking | `PHONE_REQUIRED` | `courier_public` flow есть |
| Internal map | `PHONE_REQUIRED` | Unit/widget tests есть, field test нет |
| OSRM production | `FAIL` | Release default disabled, public pilot endpoint без SLA |
| External navigators | `PHONE_REQUIRED` | URI tests есть |
| Firestore Rules компилируются | `PASS` | Emulator загрузил Rules, exit 0 |
| Firestore Rules безопасны | `FAIL` | Нет semantic suite; известны 3 critical bypass |
| Firestore Rules deployed | `DEPLOY_REQUIRED` | Deploy status не подтверждён, deploy не выполнялся |
| Firestore indexes complete | `FAIL` | Один local composite отсутствует deployed |
| Cloud Functions | `FAIL` | Local `functions/` отсутствует |
| Functions build/tests | `FAIL` / N/A | Нечего собирать/тестировать |
| FCM | `FAIL` | Не реализован |
| App Check | `FAIL` | Не реализован |
| Offline/idempotency | `FAIL` | Operation IDs/recovery tests отсутствуют |
| Data migration | `FAIL` | Нет inventory/dry-run migration |
| Release debug/test tools скрыты | `PASS` частично | `kDebugMode`, но raw errors/debug signing остаются |

## 2. GO/NO-GO по уровням

### Установка APK: условный GO для локального smoke

`GO` только для установки debug APK на контролируемый тестовый телефон и визуального smoke-теста без реальных пользователей и денег.

Ограничения:

- установка фактически не выполнена;
- APK большой и debug-signed;
- Phone Auth/GPS/карты ещё требуют телефона;
- release APK также debug-signed и не даёт преимущества как production artifact.

Рекомендуемый файл для текущего инженерного smoke: `build/app/outputs/flutter-apk/app-debug.apk`.

### Два телефона customer + courier: NO-GO

Причины:

- Phone Auth и роли не проверены end-to-end;
- deployed Rules неизвестны;
- semantic Rules tests отсутствуют;
- radius и delivery code небезопасны;
- admin resolution недоступен;
- physical Android/GPS/network test отсутствует.

Двухтелефонный тест разрешать только после изолированного test project/data setup, P0 security corrections и controlled Rules deploy.

### Закрытый пилот с реальными пользователями: NO-GO

Причины:

- modified client обходит radius;
- courier может завершить order без реального code secret;
- catalog totals/items не authoritative;
- нет backend command layer и idempotency;
- disputes/stuck courier нельзя надёжно разрешать из APK;
- нет FCM и operational monitoring;
- release signing не настроен;
- data migration неизвестна.

### Production: NO-GO

В дополнение к pilot blockers:

- нет App Check;
- нет production routing/SLA;
- нет Crashlytics/operational alerts;
- нет signed AAB/reproducible release pipeline;
- нет security/rules regression suite;
- secrets ignore policy неполна;
- официальная версия/release/tag discipline нарушена.

## 3. Минимальный gate для следующего двухтелефонного теста

Перед тестом должны быть выполнены все пункты:

- [ ] Phone Auth test numbers и SHA проверены на двух Android;
- [ ] Rules semantic tests проходят локально;
- [ ] Rules и необходимые indexes deployed с разрешения владельца;
- [ ] secure backend accept/select/complete с radius и code verification;
- [ ] test admin доступен через защищённый маршрут;
- [ ] dispute/clear active flow атомарен;
- [ ] test data изолированы, есть cleanup/reconciliation;
- [ ] один полный сценарий customer → offer → selected → pickup → delivered → completed;
- [ ] негативный тест foreign order/offer/admin;
- [ ] restart/offline/weak network сценарии;
- [ ] APK checksum и test build config зафиксированы.

## 4. Минимальный gate для закрытого пилота

Дополнительно:

- [ ] authoritative marketplace checkout;
- [ ] idempotency для business commands;
- [ ] FCM для ключевых событий;
- [ ] App Check хотя бы monitoring mode;
- [ ] release-signed APK/AAB и upgrade test;
- [ ] read-only data inventory и migration dry run;
- [ ] operational error/stuck-order monitoring;
- [ ] support/admin runbook;
- [ ] privacy/security review phone/location data;
- [ ] rollback procedure и pilot kill switch.

## 5. Сводный вердикт

| Цель | Решение |
|---|---|
| Локально собрать APK | `GO` — выполнено |
| Установить на один контролируемый телефон | `CONDITIONAL GO`, phone smoke only |
| Проверить customer/courier на двух телефонах | `NO-GO` |
| Закрытый пилот | `NO-GO` |
| Production | `NO-GO` |
