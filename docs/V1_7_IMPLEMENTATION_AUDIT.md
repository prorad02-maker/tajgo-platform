# TajGo — технический аудит реализации v1.7

Дата аудита: 26 июля 2026  
Репозиторий: `C:\Projects\tajgo`  
Режим аудита: только чтение исходного кода и локальные проверки; deploy, push, tag и изменение версии не выполнялись.

## 1. Итог

Официальной версии или спецификации **v1.7 в репозитории не найдено**. Нет ветки, коммита, тега, release notes, roadmap, TODO или исходного файла с содержанием v1.7. Поэтому утверждать, что «v1.7 реализована», нельзя.

Фактическая техническая версия проекта — **1.5.0+30**. Приложение содержит значительный объём клиентского и курьерского MVP, marketplace, offer-flow, картографию и код админ-панели. Debug и release APK локально собираются, 66 тестов проходят. При этом закрытый пилот блокируют серверные и security-проблемы:

- радиус `< 1000 м` проверяется только доверенным клиентом;
- код подтверждения хранится в читаемом курьером заказе, а Rules не проверяют сам код;
- критические транзакции выполняются мобильным клиентом; Cloud Functions в репозитории нет;
- целостность товарных позиций и цен каталога не подтверждается сервером;
- админ-панель и Demo Tools не имеют маршрута из production entry point;
- deployed-версия Rules не установлена, semantic Rules tests отсутствуют;
- физический Android-тест, Phone Auth, GPS, два пользователя и внешние навигаторы не проверены;
- release APK подписан debug-сертификатом.

Вердикт: **собираемый product preview 1.5.0, но не подтверждённая v1.7 и не готовый безопасный пилот**.

## 2. Методика и границы

Проверено:

- состояние Git, локальные/remote refs, теги, reflog и история версий;
- весь `lib/`, `test/`, `docs/`, Firebase и Android config;
- фактическое подключение экранов от `lib/main.dart`;
- модели, repositories, services, Firestore collections, Rules и indexes;
- release/debug guards, signing, разрешения Android;
- локальные `flutter analyze`, `flutter test`, debug/release APK builds;
- компиляция локальных Firestore Rules через emulator;
- активный Firebase project и опубликованные indexes, без изменений проекта.

Не проверено:

- реальная отправка SMS и Firebase Console Phone Auth setup;
- поведение на физическом Android-устройстве;
- работа двух телефонов в одной сессии;
- фактические данные production Firestore;
- deployed Rules;
- реальный OSRM endpoint и внешние приложения-навигации;
- push-уведомления, которых в проекте нет.

Статусы:

- `READY` — flow подключён, хранит/читает данные, обрабатывает основные ошибки, имеет тест или воспроизводимую проверку и не содержит найденного критического обхода;
- `PARTIAL` — существенная часть работает, но не выполнен хотя бы один критерий `READY`;
- `UI_ONLY` — интерфейс есть, но нет полноценного рабочего потока;
- `DOC_ONLY` — существует только документация;
- `DEMO_ONLY` — тестовый сценарий или данные;
- `LOCAL_ONLY` — подтверждено только локально;
- `BACKEND_MISSING` — клиентский flow есть, обязательной серверной защиты нет;
- `BROKEN` — найдено нарушение заявленного сценария;
- `NOT_IMPLEMENTED` — реализации нет;
- `NOT_VERIFIED` — доказательств недостаточно.

## 3. Git и происхождение версии

| Источник | Факт | Вывод |
|---|---|---|
| Ветка | `main` | Аудит выполнен на main |
| HEAD | `eaf581cbf7006c0b9ee59556966a1a46433cc270` | Пустой checkpoint `chore: checkpoint before v1.5.1 pilot hardening` |
| Последний содержательный commit | `89cbe411912e7eb2778856e3c6166edfcc1dc26f` | `feat: expand marketplace admin and routing for v1.5.0` |
| `origin/main` | `89cbe411912e7eb2778856e3c6166edfcc1dc26f` | Локальная main впереди на один пустой checkpoint |
| Последний релизный документ | `docs/RELEASE_NOTES_v1.5.0.md` | Документированная версия 1.5.0 |
| Текущий `pubspec.yaml` | `1.5.0+30` | Фактическая версия приложения |
| Последний tag | `v1.2.0-product-preview` | Tags отстают от исходного кода |
| Commit/tag/branch v1.7 | Не найден | Официальной v1.7 в Git нет |
| Текстовая спецификация v1.7 | Не найдена | Scope v1.7 нельзя восстановить как факт |

Найденная последовательность технических версий:

`1.0.0+1 → 0.7.0+7 → 0.8.0+8 → 0.8.1+9 → 0.8.3+11 → 0.8.4+12 → 0.8.7+15 → 0.9.0+18 → 1.0.0+21 → 1.0.1+22 → 1.0.2+23 → 1.0.3+24 → 1.0.4+25 → 1.1.0+26 → 1.2.0+27 → 1.3.0+28 → 1.4.0+29 → 1.5.0+30`.

Первоначальный переход с `1.0.0+1` на `0.7.0+7` — историческая аномалия нумерации. Позднейший ряд 1.2–1.5 отражён в commits, но tags закончились на 1.2. Никакого подтверждённого скачка к 1.7 нет.

## 4. Техническая версия и Android identity

| Источник | Значение | Совпадает |
|---|---|---|
| `pubspec.yaml:19` | `1.5.0+30` | Да |
| Android `versionName` | Flutter `versionName` = `1.5.0` | Да |
| Android `versionCode` | Flutter `versionCode` = `30` | Да |
| Debug APK manifest | `1.5.0 (30)` | Да |
| Release APK manifest | `1.5.0 (30)` | Да |
| Package / applicationId | `tj.tajgo.app` | Да |
| Namespace | `tj.tajgo.app` | Да |
| Launcher label | `TajGo` | Да |
| Runtime `package_info_plus` | Не подключён | Версия берётся из build config |

Основные доказательства: `pubspec.yaml`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`.

## 5. Итоговая карта функций

Колонки «UI», «Firebase» и «Backend» означают фактическое подключение, а не наличие документации.

| Функция | Заявлена задачами проекта | Код | UI | Firebase | Backend-защита | Тесты | Статус | Severity | Доказательство |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| Сборка Android | Да | Да | — | — | — | Build | `READY` | LOW | `pubspec.yaml`, Gradle, два APK |
| Phone Auth UI/API | Да | Да | Да | Auth | Console не проверена | Unit отсутствует | `PARTIAL` | HIGH | `AuthService.requestPhoneCode`, `PhoneAuthScreen` |
| Anonymous demo fallback | Да | Да | Debug only | Auth | `kDebugMode` | Нет | `DEMO_ONLY` | LOW | `AuthService.allowAnonymousDemo` |
| Создание `users/{uid}` | Да | Да | После auth | Firestore | Rules локально | Нет integration | `PARTIAL` | HIGH | `UserRepository.ensureUser` |
| Роли customer/courier | Да | Да | Да | Firestore | Rules локально | Decision tests | `PARTIAL` | HIGH | `AppStartupRouter`, `AccountModeService` |
| Admin role/access | Да | Да | Нет маршрута | Firestore | Rules локально | Нет | `BROKEN` | BLOCKER | `AdminAccessGate`; admin files unreachable from `main.dart` |
| CustomerHome | Да | Да | Да | Firestore streams | Rules локально | Widgets частично | `PARTIAL` | MEDIUM | `CustomerHomeScreen` |
| Custom delivery A/B | Да | Да | Да | Firestore | Клиентская запись | Map/unit tests | `PARTIAL` | HIGH | `NewOrderMapScreen`, `OrderRepository` |
| Recommended/client price | Да | Да | Да | Order fields | Нет server authority | Pricing tests | `PARTIAL` | HIGH | `pricing.dart`, `OrderRepository.createOrder` |
| Idempotent order creation | Ожидается | Нет | Busy guard | Firestore | Нет request id | Нет | `NOT_IMPLEMENTED` | HIGH | Случайный doc id при каждой попытке |
| Realtime courier offers | Да | Да | Да | `orders/{id}/offers` | Rules локально | Helpers | `PARTIAL` | HIGH | `CourierOfferRepository` |
| Offer expiration | Да | Частично | UI timestamp | Firestore timestamp | Нет scheduler | Нет integration | `PARTIAL` | MEDIUM | `CourierOffer.isActive`; статус сервером не меняется |
| Atomic offer selection | Да | Да | Да | Client transaction | Rules `getAfter` локально | Нет race integration | `PARTIAL` | HIGH | `CourierOfferRepository.selectOffer` |
| Радиус `< 1000 м` | Да | Да | Да | Клиентские location fields | Нет server calculation | Boundary частично | `BACKEND_MISSING` | BLOCKER | `CourierOrderEligibilityService` |
| GPS freshness/accuracy | Да | Да | Да | location timestamps | Нет server check | Unit частично | `BACKEND_MISSING` | CRITICAL | max age 15 s, accuracy 50 m только в Dart |
| Один active order | Да | Да | Да | Courier transaction | Rules локально | Unit частично | `PARTIAL` | CRITICAL | `activeOrderId`, `isBusy`, `getAfter` |
| Очистка active order | Да | Частично | Да | Firestore transaction | Спор зависит от admin | Нет E2E | `PARTIAL` | HIGH | completed очищает; disputed может оставить busy |
| Статусная машина | Да | Да | Да | Order status | Rules локально | Model/helpers | `PARTIAL` | HIGH | `TajGoOrderStatus`, repositories, Rules |
| Delivery code | Да | Да | Да | Код внутри order | Код не проверяется Rules | Client unit/UI only | `BROKEN` | BLOCKER | Courier читает order; Rules не сравнивают код |
| Live courier location | Да | Да | Да | `couriers`, `courier_public` | Rules локально | Service unit only | `PARTIAL` | HIGH | `TajGoLocationService`, `CourierRepository` |
| Customer tracking | Да | Да | Да | `courier_public` | Публичная проекция ограничена | Widget/unit | `PARTIAL` | MEDIUM | `OrderTrackingScreen` |
| Marketplace categories | Да | Да | Да | Firestore + preview | — | Widget/model | `READY` для UI | LOW | Еда / Продукты / Цветы |
| Preview partners/products | Да | Да | Да | Локальный fallback | Checkout UI заблокирован | Tests | `DEMO_ONLY` | LOW | 6 partners, 18 products |
| Firestore marketplace | Да | Да | Да | partners/products/orders | Items не сверяются Rules | Нет integration | `BACKEND_MISSING` | BLOCKER | `MarketplaceRepository.createCatalogOrder` |
| Cart, weight, totals | Да | Да | Да | Order snapshot | Серверной цены нет | Unit tests | `PARTIAL` | HIGH | `CartController`, checkout |
| Marketplace admin CRUD | Да | Да | Код UI не достижим | Firestore | Admin Rules локально | Import tests | `UI_ONLY` | HIGH | `AdminMarketplaceScreen`, repository |
| JSON catalog import | Да | Да | Код UI не достижим | Client transaction | Admin-trusted | Unit tests | `LOCAL_ONLY` | MEDIUM | schema v1, dry run, max 100 |
| Admin orders/couriers | Да | Да | Нет production entry | Firestore | Rules локально | Нет | `BROKEN` | BLOCKER | `AdminHomeScreen` не импортирован от root |
| Admin audit log | Да | Да | Viewer отсутствует | `admin_logs` | Append-only локально | Нет | `PARTIAL` | MEDIUM | Запись есть, чтения в UI нет |
| Dispatch map | Да | Да | Только недостижимый admin | Firestore | — | Нет phone test | `UI_ONLY` | HIGH | admin dispatch screen |
| NewOrder map | Да | Да | Да | Route optional | — | Map tests | `PARTIAL` | MEDIUM | `NewOrderMapScreen` |
| Courier navigation | Да | Да | Да | Live location | — | Unit/widget | `PARTIAL` | HIGH | direct/road line, ETA, recenter |
| OSRM road route | Да | Да | Fallback | HTTP endpoint by define | Нет SLA | Parser/URI tests | `LOCAL_ONLY` | HIGH | Release default disabled |
| External navigators | Да | Да | Да | — | — | URI tests | `PARTIAL` | MEDIUM | Yandex, Google, 2GIS, geo |
| Cloud Functions | Ожидается для security | Нет | Нет | Deploy не установлен | Нет | Нет | `NOT_IMPLEMENTED` | BLOCKER | `functions/` отсутствует |
| Firestore Rules syntax | Да | Да | — | Local config | Compile only | Emulator compile | `LOCAL_ONLY` | HIGH | `firestore.rules`, emulator exit 0 |
| Firestore Rules semantics | Да | Rules есть | — | Deploy неизвестен | Не доказана | Нет rules tests | `NOT_VERIFIED` | BLOCKER | Нет emulator authorization suite |
| Firestore indexes | Да | Да | — | Один deployed | Частично | Нет query suite | `PARTIAL` | HIGH | local 2, deployed 1 |
| FCM notifications | Ожидается пилотом | Нет | Нет | Нет | Нет sender | Нет | `NOT_IMPLEMENTED` | HIGH | Нет dependency/permission/token |
| Firebase App Check | Ожидается production | Нет | Нет | Нет | Нет | Нет | `NOT_IMPLEMENTED` | CRITICAL | Модифицированный клиент не ограничен |
| Storage | Не обязательно MVP | Нет | URL fields | Нет | — | Нет | `NOT_IMPLEMENTED` | LOW | Изображения только URL |
| Crashlytics/Analytics | Ожидается pilot ops | Нет | Нет | Нет | — | Нет | `NOT_IMPLEMENTED` | MEDIUM | Нет dependencies/init |
| Offline/idempotency | Да | Частично | Loading guards | Firestore SDK | Нет operation ids | Нет failure tests | `PARTIAL` | HIGH | Retry после uncertain result может дублировать |
| Release guards | Да | Да | Debug UI скрыт | — | — | Static audit | `PARTIAL` | HIGH | Raw Firebase errors остаются; debug signing |
| Data migration | Да | Fallbacks | Авто для user частично | Existing docs | Нет dry-run migration | Model tests частично | `PARTIAL` | HIGH | Unknown order status превращается в waiting |

## 6. Авторизация и первый вход

### Реализовано

- `AuthService.requestPhoneCode` вызывает `FirebaseAuth.verifyPhoneNumber`.
- Обработаны `verificationCompleted`, `verificationFailed`, `codeSent`, `codeAutoRetrievalTimeout`.
- Есть resend token, таймер повторной отправки, нормализация номера `+992`, проверка шестизначного кода и loading guard.
- При наличии anonymous user выполняется попытка link; конфликт существующего аккаунта переводит на вход phone credential.
- После входа `PhoneAuthScreen._finishAuth` вызывает создание/обновление `users/{uid}`.
- Anonymous demo-кнопка ограничена `kDebugMode`.

### Ограничения

- Phone Auth provider, SHA-1/SHA-256, reCAPTCHA и реальная SMS не проверены.
- Нет Auth emulator/integration tests и теста повторного входа на двух телефонах.
- `PhoneAuthScreen._finishAuth` повторно завершает role onboarding по текущему entry intent. Это может переписать `selectedRole/lastMode` существующего пользователя вместо безопасного восстановления.
- Ошибки известных Auth-кодов нормализованы, но сетевые/console сценарии физически не проверены.

Статус: `PARTIAL`, дополнительно `PHONE_REQUIRED` и `CONSOLE_REQUIRED`.

## 7. Роли и доступ

Firestore-профиль является фактическим source of truth при startup. SharedPreferences получает запись, но `RolePreferenceService.load()` в production startup не вызывается. Следствия:

- смена роли на другом телефоне обнаруживается при новом запуске/повторном роутинге, не live;
- offline startup полагается на cache Firestore, явного local fallback роли нет;
- legacy users обрабатываются fallback/migration логикой;
- customer и courier используют один UID, переключение mode предусмотрено;
- customer → courier требует approved/onboarded courier;
- переключение блокируется при active customer/courier order;
- `CourierHomeScreen` повторно проверяет courier eligibility.

Admin:

- Rules ожидают `users/{uid}.role == admin`;
- `AdminAccessGate` допускает admin либо `kDebugMode`;
- test self-admin метод ограничен debug, но локальные Rules не позволяют owner самостоятельно выставить admin;
- ни `AdminHomeScreen`, ни `DemoToolsScreen` не достижимы по import graph от `main.dart`.

Статус customer/courier: `PARTIAL`. Admin: `BROKEN`.

## 8. Клиентское приложение

`CustomerHomeScreen` содержит:

- компактный header;
- навигацию «Главная / Заказы / Профиль»;
- рабочую кнопку «Отправить посылку»;
- категории «Еда / Продукты / Цветы»;
- active и recent order streams;
- courier onboarding в профиле;
- скрытые Demo Tools и admin entry — фактически отсутствуют.

Кнопки истории, избранного, помощи и privacy открывают сообщение «Раздел готовится…» и являются placeholders. В некоторых `StreamBuilder` loading/error сводятся к пустому состоянию. Marketplace при любой Firestore ошибке показывает preview, поэтому permission/network error может выглядеть как валидный пустой backend.

Статус: `PARTIAL`.

## 9. Custom delivery flow

Фактический поток:

1. A и B выбираются на `NewOrderMapScreen`.
2. Рассчитываются Haversine distance, ETA и recommended price.
3. Пользователь может указать client price с валидацией.
4. `OrderRepository.createOrder` создаёт новый Firestore document.
5. Новый формат `waitingOffers` сериализуется моделью как `waiting`.
6. Курьеры создают offers в `orders/{orderId}/offers/{courierId}`.
7. Клиент выбирает offer.
8. Order и courier обновляются client-side Firestore transaction.
9. Курьер проходит pickup/delivery.
10. Клиент или курьерский code-flow завершает order.

Данные сохраняются реально, не mock. Поля совместимости включают `orderType`, `suggestedPrice`, `clientPrice`, `finalPrice`, `offersCount`, `selectedOfferId`, courier fields, timestamps и confirmation code.

Недостатки:

- новый случайный document id создаётся до каждой попытки; request/idempotency key отсутствует;
- `_busy` защищает двойной tap только в пределах живого экрана;
- retry после timeout/uncertain commit может создать второй заказ;
- recommended price и итоговая бизнес-операция не имеют server authority;
- Rules не ограничивают пользователя одним active customer order.

Статус: `PARTIAL`, ключевые операции `BACKEND_MISSING`.

## 10. Courier offers и конкуренция

Реализованы create/update/withdraw, client-price/custom-price, repeat offer, realtime updates, `offersCount`, client selection и отклонение известных остальных offers.

Все транзакции выполняются в мобильном repository, не Cloud Functions. Firestore transaction читает order и courier и поэтому корректно конфликтует при двух клиентах, выбирающих одного courier, либо двух courier, принимающих один order — при условии реально deployed ожидаемых Rules.

Остаются риски:

- список остальных offers читается до transaction; новый concurrent offer может остаться pending после выбора;
- expiration определяется timestamp на клиенте, scheduler/status transition нет;
- weak-network retry не имеет operation id;
- race-сценарии не покрыты emulator integration tests;
- радиус и location inputs сервером не проверяются.

Статус: `PARTIAL`, security boundary `BACKEND_MISSING`.

## 11. Правило 999/1000 м

Формула в `CourierOrderEligibilityService` строгая:

`distanceMeters < 1000`

Клиент также проверяет:

- расстояние courier → pickup A;
- GPS age не старше 15 секунд;
- accuracy не хуже 50 метров;
- наличие coordinate/timestamp;
- отсутствие active order.

Unit tests покрывают 999, 1000/1001, stale GPS и busy, но не весь запрошенный набор 0, 500, 998, 999.99 и 1500.

Firestore Rules не рассчитывают Haversine, не проверяют GPS freshness/accuracy и доверяют записанному клиентом distance/location. Модифицированный APK может обойти ограничение.

Статус: `BACKEND_MISSING`, severity `BLOCKER`.

## 12. Один активный заказ

Положительные свойства:

- используются `activeOrderId` и `isBusy`;
- direct accept и offer selection транзакционно читают courier;
- Rules используют `getAfter` для согласования order/courier;
- completed транзакционно очищает active order и увеличивает статистику;
- role switch блокируется во время active order;
- debug reset скрыт через `kDebugMode`.

Проблемы:

- customer dispute не очищает courier active state — это зависит от admin resolution;
- admin UI недостижим, поэтому courier может остаться busy;
- `AdminRepository.clearActiveOrder` очищает courier без синхронизации order;
- deployed Rules и реальные races не проверены.

Статус: `PARTIAL`, severity `CRITICAL`.

## 13. Статусная машина

Фактический Dart enum:

`waiting → accepted → pickedUp → delivered → completed`, плюс `disputed` и `cancelled`.

`arrivedAtPickupAt` — timestamp при статусе `accepted`, а не отдельный enum. Совместимость:

- `draft`, `waiting`, `waitingOffers`, null → `waiting`;
- `courierSelected`, `accepted`, `arrivedPickup` → `accepted`;
- `pickedUp`, `arrivedDropoff` → `pickedUp`;
- остальные текущие terminal statuses сохраняются.

Проблемы:

- новый код не пишет отдельные состояния `draft/courierSelected/arrivedPickup/arrivedDropoff`;
- `pickedUpAt` и `deliveredAt` есть в модели, но courier transitions их не записывают;
- repository может вызвать pickup без arrived timestamp, полагаясь на Rules;
- неизвестный статус бесшумно превращается в `waiting`, что скрывает повреждение данных;
- admin может перевести completed в disputed, а затем manual complete повторно увеличить статистику.

Статус: `PARTIAL`.

## 14. Delivery confirmation code

Код генерируется на клиенте как четыре цифры и хранится в том же document order. Назначенный courier имеет доступ к order и поэтому технически может прочитать код. Courier UI сравнивает введённые цифры, но `courierCompletesWithCode()` в Rules проверяет только transition и связанные courier stats — не submitted secret.

Нет:

- server hash или отдельного закрытого document;
- callable verification;
- лимита попыток;
- rate limiting;
- security event log.

Модифицированный assigned courier может завершить заказ без знания кода.

Статус: `BROKEN`, severity `BLOCKER`.

## 15. Marketplace и корзина

### Preview

- три категории;
- шесть hardcoded preview partners;
- восемнадцать sample products;
- `isTest=true`, partners `isPreview=true`;
- preview checkout заблокирован;
- при пустом Firestore или любой ошибке отображается preview.

Это качественная демонстрация UI, но не реальный каталог. Статус: `DEMO_ONLY`.

### Firestore catalog

Admin-код умеет публиковать sample data и редактировать partners/products. Checkout транзакционно перечитывает partner/products на клиенте, проверяет availability, price, minimum и totals.

Rules проверяют metadata, fee/minimum/sum, но не перебирают `items` с чтением актуальных product documents. Модифицированный клиент может подставить произвольные товары/цены при согласованных итоговых полях. Нет server-side stock reservation, payment или authoritative calculation.

Дополнительный риск: опубликованные sample products сохраняют `isTest`; debug anonymous user в debug-signed артефакте может создавать test orders.

Статус: `BACKEND_MISSING`, severity `BLOCKER`.

## 16. Админка

В коде имеются:

- order/courier management;
- courier application approve/reject/suspend/restore;
- marketplace CRUD;
- JSON import с dry run;
- admin logs;
- dispatch map;
- test cleanup.

Но import graph от `lib/main.dart` не содержит admin screens или Demo Tools. Legit admin получает обычный customer/courier route. Поэтому админка не является доступной функцией приложения.

Найдены логические проблемы:

- cancel разрешает legacy `waiting`, но не текущий `waitingOffers`;
- disputed после completed и последующий manual complete могут дважды увеличить earnings/orders;
- clear active courier не исправляет order;
- `admin_logs.adminId` задаётся клиентом и не связан Rules с `request.auth.uid`;
- viewer audit logs отсутствует.

JSON import имеет schema v1, dry-run, лимит 100 products, валидацию IDs/categories/coordinates/HTTPS/prices/units/duplicates и atomic client transaction. Он полезен, но доступ к UI отсутствует.

Статус: `BROKEN` для рабочего admin-flow; отдельные экраны `UI_ONLY/LOCAL_ONLY`.

## 17. Карты, GPS и routing

### Карты

Фактически используются:

- `NewOrderMapScreen`;
- `CourierOrderScreen`;
- `OrderTrackingScreen`;
- admin dispatch map в недостижимом admin UI.

`TajGoMapScreen` и `RoleScreen` отсутствуют. `NewOrderMapScreen` является реальным экраном создания заказа.

Реализованы A/B markers, courier marker, location/follow/recenter, route/ETA/price, reverse geocoding, search/recent points, off-route detection и route rebuild.

### GPS

- Android имеет `ACCESS_FINE_LOCATION` и `ACCESS_COARSE_LOCATION`;
- background permission не запрошен и background tracking не реализован;
- обработаны disabled/denied/deniedForever/open settings;
- stream настроен на navigation accuracy и distance filter 5 м;
- courier location публикуется примерно раз в 7 секунд либо после 15 м движения;
- customer читает безопасную проекцию `courier_public`.

Поведение на телефоне не проверено.

### OSRM

- `RoutingConfig` по умолчанию выключен без `dart-define`;
- в default debug/release audit builds используется direct Haversine fallback;
- pilot config указывает публичный `routing.openstreetmap.de/routed-bike`;
- mode называется bicycle, но профиль задан `driving`;
- timeout 7 секунд, cache, parse geometry/steps, sanity fallback и in-flight dedupe реализованы;
- публичный endpoint не имеет SLA и production-конфигурации нет.

Заказ не блокируется при отсутствии endpoint — используется прямая линия.

Статус: карта `PARTIAL`, OSRM `LOCAL_ONLY`, production routing `NOT_IMPLEMENTED`.

## 18. Внешние навигаторы

Есть TajGo internal, Yandex Navigator, Google Maps, 2GIS и system geo URI. Android manifest содержит `<queries>` для схем. Сохраняется preference и поддерживается `askEveryTime`. При недоступном приложении используется fallback.

URI tests подтверждают выбор A для accepted и B для pickedUp, а также порядок lat/lng. Phone, code и comment во внешний URI не передаются.

Установка/отсутствие каждого приложения и fallback на реальном Android не проверены.

Статус: `PARTIAL`, `PHONE_REQUIRED`.

## 19. Firebase products

| Продукт | Configured | Initialized | Used | Deploy/Console | Статус |
|---|---:|---:|---:|---|---|
| Firebase Core | Да | Да | Да | Android config есть | `READY` локально |
| Authentication | Да | Да | Да | Provider/SHA не проверены | `PARTIAL` |
| Firestore | Да | Да | Да | Rules deploy неизвестен | `PARTIAL` |
| Cloud Functions | Нет | Нет | Нет | `functions/` отсутствует | `NOT_IMPLEMENTED` |
| Messaging | Нет | Нет | Нет | Требуется клиент+backend | `NOT_IMPLEMENTED` |
| App Check | Нет | Нет | Нет | Требуется Console/enforcement | `NOT_IMPLEMENTED` |
| Storage | Нет | Нет | Нет | Не используется | `NOT_IMPLEMENTED` |
| Crashlytics | Нет | Нет | Нет | Не настроено | `NOT_IMPLEMENTED` |
| Analytics | Нет | Нет | Нет | Не настроено | `NOT_IMPLEMENTED` |

`firebase.json` связывает Android с project `tajgo-4fcd0` и объявляет Firestore Rules/indexes. `.firebaserc` отсутствует, но локальный Firebase CLI показал active project `tajgo-4fcd0`. `google-services.json` содержит старый `com.example.tajgo` и текущий `tj.tajgo.app`; текущий client совпадает с Android identity.

Команда listing Functions завершилась ошибкой, поэтому состояние deployed Functions — `NOT_VERIFIED`, а не доказанное отсутствие. Локальная реализация Functions отсутствует однозначно.

## 20. Firestore collections

Фактически используются:

- `users`;
- `courier_applications`;
- `couriers`;
- `courier_public`;
- `orders`;
- `orders/{orderId}/offers`;
- `partners`;
- `products`;
- `admin_logs`.

Критические create/update/select/complete операции выполняются через client SDK.

## 21. Firestore Rules

Локальный `firestore.rules` успешно компилируется Firestore emulator на Java 21. Это подтверждает syntax/compile, но не корректность разрешений.

Положительные свойства:

- unknown collections закрыты;
- users owner/admin разделены;
- courier/private и `courier_public` имеют разные проекции;
- order create требует authenticated owner и ожидаемый initial status;
- customer/courier/admin transitions ограничены;
- offer ownership и selected courier проверяются;
- `getAfter` используется для согласования order и courier;
- partners/products изменяет admin;
- admin logs append-only.

Критические пробелы:

- нет server-side radius/location freshness/accuracy;
- delivery code читаем и не проверяется;
- catalog items не сверяются с product documents;
- нет semantic emulator suite для anonymous/customer/courier/admin/foreign access;
- deployed Rules version неизвестна.

Статус: syntax `LOCAL_ONLY`; security `NOT_VERIFIED`; найденные обходы делают текущую модель непригодной для пилота.

## 22. Firestore indexes

Локально объявлены:

1. `orders(customerId ASC, createdAt DESC)`;
2. `orders(status ASC, createdAt DESC)`.

Firebase CLI показал deployed только первый index. Deploy в ходе аудита не выполнялся.

| Query | Нужен index | Есть local | Есть deployed | Риск |
|---|---:|---:|---:|---|
| orders by customerId + createdAt | Composite | Да | Да | LOW |
| orders by status + createdAt | Composite | Да | Нет | HIGH, если query активирован |
| orders createdAt range/order | Single-field | Auto | Auto | LOW |
| offers orderBy createdAt | Single-field | Auto | Auto | LOW |
| orders status whereIn | Single-field | Auto | Auto | LOW |
| courierId / courier_public.isOnline | Single-field | Auto | Auto | LOW |
| partners isActive + category | Index merge/возможен composite | Нет отдельного | Не проверено | MEDIUM |
| products partnerId + hidden | Index merge/возможен composite | Нет отдельного | Не проверено | MEDIUM |

Нужен emulator/real-project query test всех экранов до deploy decisions.

## 23. Уведомления

FCM полностью отсутствует:

- нет dependency;
- нет Android runtime notification permission;
- нет token/token refresh/storage;
- нет foreground/background/tap handlers;
- нет sender Function;
- нет privacy-safe payload design.

Статус: `NOT_IMPLEMENTED`. Для foreground demo Firestore streams могут обновить экран, но courier/customer не получат надёжное событие в background.

## 24. Offline и надёжность

Есть локальные loading/busy guards и Firestore transactions. Нет end-to-end механизмов:

- operation/request IDs;
- idempotent create/offer/select/checkout/status calls;
- recovery record для uncertain result;
- explicit offline queue UX;
- timeout/retry policy для business writes;
- emulator tests network loss/restart/stale streams;
- duplicate detection.

App restart в основном восстанавливает state из Firestore, но disputed courier может остаться busy; cached role не имеет явного local fallback.

Статус: `PARTIAL`, severity `HIGH`.

## 25. Release security

Подтверждено:

- anonymous demo button, dev reset и Demo Tools ограничены `kDebugMode`;
- debug admin bypass ограничен `kDebugMode`;
- delivery code/phone/token не логируются найденными debug prints;
- launcher exported корректно; иных exported components не найдено;
- cleartext traffic явно не разрешён;
- manifest содержит только Internet и foreground location permissions;
- приватных service-account keys не найдено.

Проблемы:

- `android/key.properties` отсутствует;
- release build fallback подписывает APK debug key;
- `.gitignore` не закрывает `*.jks`, `*.keystore`, `android/key.properties`, service-account/env secrets;
- несколько экранов показывают raw `$error`/`snapshot.error`, включая возможный FirebaseException;
- App Check отсутствует;
- server authority отсутствует.

Важно: Firebase API keys в `firebase_options.dart` и `google-services.json` являются публичной client configuration, но это не заменяет Rules/App Check.

Статус: `PARTIAL`; production release security `FAIL`.

## 26. Автоматические проверки

| Команда | Exit | Результат |
|---|---:|---|
| `flutter clean` | 0 | Успешно |
| `flutter pub get` | 0 | Успешно; 28 newer incompatible packages, upgrade не выполнялся |
| `flutter analyze` | 0 | `No issues found`, 90.1 s |
| `flutter test` | 0 | 66 passed, 0 failed |
| `flutter build apk --debug` | 0 | APK собран |
| `flutter build apk --release` | 0 | APK собран, но debug-signed |
| Firestore emulator compile | 0 | Rules загружены и emulator запущен |
| Functions build/test | — | `functions/` отсутствует |

Тесты покрывают модели, pricing, cart/import, map geometry, routing parser/URI, role decision, eligibility helper и widgets. Они не покрывают:

- Firebase Auth/Firestore integration;
- Rules authorization matrix;
- реальные transaction races;
- SMS/reCAPTCHA;
- GPS/permissions/lifecycle;
- два телефона;
- network loss/retry;
- внешние apps;
- production admin navigation;
- FCM.

## 27. Build artifacts

| Артефакт | Размер | SHA-256 | Package/version | Подпись |
|---|---:|---|---|---|
| `build/app/outputs/flutter-apk/app-debug.apk` | 170,473,067 bytes | `3D5C526587F2A56B81A104613A63CD8216161AF30756C4FA7B32869C9BB158B2` | `tj.tajgo.app`, `1.5.0 (30)` | Android Debug |
| `build/app/outputs/flutter-apk/app-release.apk` | 63,930,066 bytes | `AFDF2E95320A874FF4E4E8E06FF197DF54CE45795A44D0F72DF078761188C7E3` | `tj.tajgo.app`, `1.5.0 (30)` | Android Debug |

Оба сертификата: `C=US, O=Android, CN=Android Debug`. Release APK не является production artifact. AAB не создан.

## 28. Мёртвый, недостижимый и demo-код

Статический import/export graph от `lib/main.dart` нашёл 19 недостижимых Dart-файлов из 117. Это эвристика, но для admin/demo entry подтверждается отсутствием production import path.

Ключевые недостижимые области:

- все admin screens/widgets;
- `DemoToolsScreen`;
- delivery map intelligence model/service;
- map point selection helper;
- часть старых shared widgets/logo.

Также:

- `IntentSelectionScreen` является deprecated alias `RoleOnboardingScreen`;
- marketplace preview — hardcoded demo data;
- нет класса `RoleScreen`;
- нет `TajGoMapScreen`;
- реальный экран создания заказа — `NewOrderMapScreen`.

Удаление или рефакторинг в ходе аудита не выполнялись.

## 29. Совместимость и migration

Есть fallbacks:

- users без role и legacy roles/status;
- couriers без `activeOrderId`, `isBusy` из active state;
- `online/isOnline`, GeoPoint/map/lat-lng location aliases;
- orders без `orderType`;
- legacy order statuses;
- legacy transport `walking/pedestrian/foot/electric_bike`;
- старые prices и необязательные marketplace fields.

Риски:

- unknown order status silently становится waiting;
- legacy order может снова попасть в offer list;
- offers с отсутствующими полями получают defaults и могут выглядеть валидными;
- `AccountMigrationService` исправляет user profile, но не orders/offers/catalog;
- dry-run migration inventory/report отсутствует.

Перед пилотом нужен read-only inventory existing Firestore documents, затем versioned migration script с backup и повторным dry run.

## 30. Что реально реализовано, а что только выглядит готовым

### Реально реализовано на уровне client MVP

- Flutter customer/courier UI;
- Firebase Auth API integration;
- Firestore repositories и realtime streams;
- custom delivery creation;
- offers и client selection;
- courier active order/status flow;
- marketplace UI/cart/catalog repositories;
- GPS и live public courier projection;
- карты, direct navigation и optional OSRM;
- external navigation URI generation;
- admin screens/repositories как код;
- debug/release build.

### Demo/UI-only/local-only

- hardcoded marketplace preview;
- Demo Tools;
- admin screens без маршрута;
- JSON import без доступного admin entry;
- public OSRM pilot config;
- Rules compile без semantic tests;
- client-side security checks.

### Не реализовано

- authoritative Cloud Functions;
- secure code verification;
- server radius;
- authoritative catalog pricing/items;
- FCM;
- App Check;
- production signing;
- production routing SLA;
- Crashlytics/Analytics;
- full data migration;
- E2E/two-phone/rules integration suite.

## 31. Аудиторское заключение

Кодовая база заметно продвинута по сравнению с ранним MVP и пригодна для локальной демонстрации интерфейсов и алгоритмов. Однако версия v1.7 не имеет документального или Git-основания. Текущий проект следует называть **TajGo 1.5.0 product preview**.

Собранный APK можно установить для одиночного технического smoke-теста, осознавая debug signing и отсутствие проверки телефона. Использовать текущую систему с реальными клиентами, деньгами или независимыми courier нельзя до переноса критических решений на доверенный backend, проверки Rules, подключения admin flow и прохождения двухтелефонного E2E.
