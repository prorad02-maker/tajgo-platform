# TajGo v1.8 Part 2 — Release Gap Audit

Дата: 26 июля 2026
Основание: аудит фактического кода на коммите `43d4126` (v1.8.0+31), режим — только чтение исходников и локальные проверки. Deploy, push, tag, изменение версии и применение stash не выполнялись.
Метод: прочитан реальный код (не имена файлов) по всем подсистемам: клиентская оболочка, marketplace/корзина/checkout, карта/адреса/курьер/навигация, админка/заявки, дизайн-система/платформа. Backend-контракт (22 callable Functions) и его привязка к Flutter-репозиториям подтверждены прямым чтением `functions/src/index.ts` и grep вызовов `AuthoritativeCommandService.call(...)`.

## 0. Итог одной строкой

**Ядро доставки и marketplace (Part 1) — реально работает и backend-authoritative.** Пробелы Part 2 сконцентрированы не в денежном/заказном ядре, а в: (1) отсутствующих новых функциях (удаление аккаунта, заявки магазинов, уведомления), (2) неунифицированной дизайн-системе и клиентской оболочке, (3) store/platform-готовности (iOS identity, signing, feature-flags). Это **RC-незавершённость**, а не сломанное ядро.

## 1. Статусы (легенда)

- `READY` — flow подключён, хранит/читает данные, обрабатывает основные ошибки, есть тест/воспроизводимая проверка, нет найденного обхода.
- `PARTIAL` — существенная часть работает, но не выполнен ≥1 критерий READY.
- `UI_ONLY` — интерфейс есть, рабочего потока нет.
- `BACKEND_READY_UI_MISSING` — Function/бэкенд есть, UI его не вызывает.
- `DEPLOY_REQUIRED` — код готов, нужен owner-deploy (Functions/Rules/indexes/config).
- `PHONE_REQUIRED` — проверяется только на физических телефонах.
- `MAC_REQUIRED` — требует macOS/Xcode/Apple account.
- `SIGNING_REQUIRED` — требует production keystore/подпись.
- `BLOCKER` — отсутствует полностью или ломает заявленный сценарий; блокирует RC.

## 2. Сохранённый authoritative core Part 1 (НЕ переписывать)

Подтверждено чтением кода — все 22 callable существуют в `functions/src/index.ts` и вызываются из репозиториев через `AuthoritativeCommandService`:

| Callable | Flutter-вызов | Статус |
|---|---|---|
| `ensureUserProfile` / `completeUserProfile` / `switchAccountMode` | `user_repository.dart:18,33,45,57` | READY |
| `completeCourierOnboarding` | `courier_application_repository.dart:127` | READY |
| `ensureCourierProfile` / `resetTestOrderForCourier` | `courier_repository.dart:86,259` | READY |
| `createCustomDeliveryOrder` / `cancelWaitingOrder` | `order_repository.dart:39,150` | READY |
| `updateDeliveryStatus` / `completeDeliveryWithCode` | `courier_repository.dart:271,286,301,317`; `order_repository.dart:157,167` | READY |
| `submitCourierOffer` / `updateCourierOffer` / `withdrawCourierOffer` / `rejectCourierOffer` / `selectCourierOffer` | `courier_offer_repository.dart:31,46,59,73,89` | READY |
| `createCatalogOrder` | `marketplace_repository.dart:296` | READY |
| `cancelCatalogOrder` | (доступен) | READY |
| `adminCancelOrder` / `adminReleaseCourier` / `adminResolveDispute` / `adminSetOrderNote` / `adminMigrateLegacyDeliveryCode` | `admin_repository.dart:71,84,98,113,154,169,182` | READY |

**Правило:** денежные/статусные/владельческие/кодовые операции остаются на Functions. Новый прямой Firestore-flow из Flutter для них не создаём.

## 3. Карта функций по этапам Part 2

| # | Функция (этап) | Статус | Доказательство | Пробел для RC |
|---|---|---|---|---|
| Auth | Phone Auth | **READY** | `auth_service.dart:31-93` реальный `verifyPhoneNumber`, resend/timeout/link/conflict; `phone_auth_screen.dart:52-105` | Только `PHONE_REQUIRED` (реальная SMS/reCAPTCHA/SHA — owner+device) |
| Auth | Role/mode onboarding | **READY** | `role_onboarding_screen.dart:11-108`, `intent_selection_screen.dart` = deprecated alias | — |
| Auth | Startup routing (server role) | **READY** | `app_router.dart:31-62` → `ensureUser` → Firestore; `startup_decision.dart:14-36` | — |
| 3 | CustomerShell (5 табов) | **PARTIAL** | `customer_home_screen.dart:76-92` — только 3 таба (Главная/Заказы/Профиль), Профиль пушится роутом | Нет Поиск и Корзина-таба с badge; нет persistent IndexedStack shell |
| 4 | Customer Home разделы | **PARTIAL** | `customer_home_screen.dart:97-266` active-order/«Отправить посылку»/категории/recent | Нет header-адреса/уведомлений, marketplace-поиска, «Популярное»/«Рядом»/«Повторить» |
| 5 | Marketplace search | **BLOCKER (отсутствует)** | grep — нет поиска товаров/партнёров нигде | Целиком новый экран поиска |
| 6 | «Отправить посылку» flow | **PARTIAL** | `new_order_map_screen.dart` A/B/цена/publish→`createCustomDeliveryOrder` | `type` жёстко `package` (`:38`); один free-text вместо что/ориентир/подъезд/этаж |
| 7 | Карта и адреса (UX) | **READY (deploy-config)** | `new_order_map_screen.dart` стадии `:272-359`; routing `route_service.dart:102-161` | Road-routing выключен по умолчанию (`routing_config.dart:56-61`) → `DEPLOY_REQUIRED` (OSRM endpoint) |
| 7b | Reverse geocode / place search | **PARTIAL** | реальный `geocoding_provider.dart` (не Nominatim); справочник `place_search_service.dart:112` | `khujand_places.json` — 4 демо-строки; популярные/партнёрские точки — заглушки |
| 8 | Saved addresses (структурные) | **BLOCKER (отсутствует)** | `saved_places_service.dart:7-62` хранит только «звёздочку» точки, device-local | Нет модели Дом/Работа/Другой + entrance/floor/apartment/landmark/comment, нет CRUD, нет cloud-sync |
| 9 | Еда/Продукты/Цветы список | **PARTIAL** | `marketplace_partners_screen.dart:18-147`; карточка `:106-134` | Нет фильтров/сортировки UI, скелетонов, distance/min-order на карточке; offline замаскирован sample-данными (`marketplace_repository.dart:29-49`) |
| 10 | Экран партнёра | **PARTIAL** | `partner_catalog_screen.dart:139-177` header; товары плоским списком `:99-107` | Нет cover/logo, часов (кроме закрытого), секций категорий товаров |
| 11 | Product card / details | **PARTIAL** | `partner_catalog_screen.dart:179-307`; цена `${price} TJS` `:229` | Availability бинарная (нет lowStock/hidden различий — сервер `stockQuantity` игнорируется моделью `core.ts:1327-1336`); старая цена без «TJS»; нет product-details экрана |
| 12 | Корзина | **PARTIAL** | one-partner `marketplace_cart.dart:44-46`; диалог `partner_catalog_screen.dart:20-40`; итоги `:35-38` | Корзина **in-memory** (`tajgo_scope.dart:50`) — теряется при рестарте; нет per-item comment; нет глобального таба корзины |
| 12b | Catalog checkout | **READY** | `marketplace_checkout_screen.dart:66-146`→`createCatalogOrder`; сервер пересчёт/price-changed `core.ts:1308-1358` | UX смены цены минимален (snackbar + повтор); клиент total может недосчитать при `deliveryFee<10` (сервер floor 10) |
| 13 | Customer Orders / Tracking | **READY** | `order_tracking_screen.dart` live map/offers/cancel/confirm/dispute; человекочитаемые статусы `:281-308`; код клиенту `:716-730` | — |
| 14 | Courier Home redesign | **READY (стиль)** | `courier_home_screen.dart` toggle/статы/табы; `<1000` bucket `:726-773` (999.99 accept, 1000 block) | Нужна унификация под новую дизайн-систему; `setOnline`/`updateLocation` — прямой Firestore (rules-gated) |
| 15 | Активная доставка курьера | **READY** | `courier_order_screen.dart:740-764` markArrived→pickedUp→code; цель A/B `:522-527`; код скрыт `:944` | Нет отдельного `arrivedDropoff` шага; `TajGoOrder.fromDoc` парсит `confirmationCode` (`:186) — проверить, что rules не отдают поле курьеру |
| 16 | Merchant Application (заявки магазинов) | **BLOCKER (greenfield)** | grep по `lib/` и `functions/` — 0 совпадений merchant/store/vendor application | Полностью новая подсистема: модель, статусы, submit-Function, экран, черновики |
| 17 | Admin merchant applications | **BLOCKER (greenfield)** | зависит от #16 | Нет раздела «Заявки», фильтров, конверсии в партнёра |
| 18 | Admin redesign / navigation | **READY (стиль)** | `admin_home_screen.dart:87-218` дашборд+навигация; gate по server-роли `admin_access_gate.dart:16-27` | Унификация стиля; нет tile «waiting offers»/counts партнёров |
| 18b | Admin orders/couriers/offers/dispatch/logs | **READY** | actions через Functions `admin_repository.dart:66-182`; код не показывается plaintext | `forceOffline` — **прямой Firestore** (`admin_repository.dart:123-148`), не Function |
| 19 | Admin partners/products | **PARTIAL** | редакторы `admin_marketplace_screen.dart:483-896` | **Все CRUD — прямой Firestore** (`marketplace_repository.dart:103-274`, rules-only); нет SKU, числового stock, per-product category; partner states неполные |
| 20 | Импорт прайса | **PARTIAL** | `marketplace_import_service.dart:37-62` JSON schema v1, dry-run `admin_marketplace_import_screen.dart:37-107` | Только JSON (нет CSV/XLSX); fail-fast (нет per-row отчёта); один партнёр; клиентская транзакция, не Function |
| 21 | Profile (клиент/курьер) | **PARTIAL** | `account_profile_screen.dart:79-133` mode/настройки/выход | «История/Избранные адреса/Помощь/Политика» → `_soon` заглушки; нет «Удалить аккаунт», «Подключить свой магазин», Terms, Support |
| 22 | Удаление аккаунта | **BLOCKER (отсутствует)** | grep `deleteAccount`/`Удалить аккаунт` → 0 (client+backend) | Нет ни UI, ни Function, ни web-страницы. Store-policy blocker |
| 23 | Privacy/Terms/Support | **BLOCKER (заглушки)** | `account_profile_screen.dart:91,96,122,127` → snackbar «готовится» | Нужны реальные экраны + версии/acceptedAt + черновики документов |
| 24 | Permissions UX | **READY** | `tajgo_location_service.dart:28-52` lazy-запрос; нет startup-запросов | `permission_handler` (`pubspec.yaml:44`) — не используется (мёртвая зависимость) |
| 25 | FCM notifications | **BLOCKER (отсутствует)** | нет `firebase_messaging` в pubspec; 0 ссылок в `lib/` | Нужны пакет, токены, permission, foreground/background/tap, backend-триггеры (DEPLOY_REQUIRED) |
| 26 | Diagnostics / Crashlytics | **PARTIAL / отсутствует** | health-панель заперта в мёртвом `demo_tools_screen.dart:256-346`; нет `firebase_crashlytics` | Нужен отдельный DiagnosticsScreen за pilot-флагом; Crashlytics init |
| 27 | App Check | **NOT_IMPLEMENTED** | нет `firebase_app_check`; сервер `index.ts:31-32` `enforceAppCheck:false` | debug/PlayIntegrity provider + staged rollout (enforcement НЕ включать) |
| 28 | Feature flags / AppEnvironment | **BLOCKER (отсутствует)** | только сырой `kDebugMode` в ~11 местах | Нужен единый AppEnvironment (debug/pilot/production) + флаги |
| 29 | Responsive / accessibility | **NOT_VERIFIED** | не проверялось системно | Нужны semantics, проверка overflow/large text/малый экран |
| 30 | Android store readiness | **PARTIAL** | applicationId `tj.tajgo.app` ✓, версия ✓, manifest/queries ✓ | SDK не запинены (`build.gradle.kts:23,35,36` наследуют Flutter); release-подпись падает на debug-ключ (`:59-64`) → `SIGNING_REQUIRED`; targetSdk 36 не подтверждён |
| 31 | iOS project readiness | **BLOCKER / MAC_REQUIRED** | bundleId `com.example.tajgo` (`project.pbxproj`, `firebase_options.dart:70,80`); нет `GoogleService-Info.plist`; нет `DEVELOPMENT_TEAM` | Переименовать bundleId, добавить plist, подпись; `geo:`-fallback внешних навигаторов не сработает на iOS |
| 32 | Store metadata | **BLOCKER (отсутствует)** | нет docs листингов | Нужны RU/TJ листинги, submission-гайды, скриншот-план |
| 33 | Flutter tests | **PARTIAL** | 77 тест-кейсов в 3 файлах | Сохранить 77; добавить design/customer/marketplace/courier/merchant/store тесты |
| 34 | Functions/Rules regression | **READY (база)** | unit+integration+rules suites существуют | Добавить тесты для merchant/deleteAccount/FCM privacy при реализации |
| 35 | E2E emulator smoke | **PARTIAL** | нет `scripts/run_v1_8_smoke_test.ps1` | Создать сценарии custom/catalog/merchant |
| 36 | Two-phone test plan | **DOC отсутствует** | — | Создать `docs/V1_8_TWO_PHONE_TEST.md` |
| 37 | Release build / artifact manifest | **DEPLOY/SIGNING** | версия поднимается до `1.8.0+32` | Пересборка + SHA-256 + manifest; production подпись отсутствует |
| 38 | GO/NO-GO | **DOC отсутствует** | — | `docs/V1_8_FINAL_GO_NO_GO.md` |
| 39 | Owner setup doc | **PARTIAL** | есть `V1_8_OWNER_FIREBASE_SETUP.md` | Нужен `V1_8_OWNER_FINAL_SETUP.md` |

## 4. Дизайн-система (Этап 2) — детально

| Токен/компонент | Статус | Пробел |
|---|---|---|
| TajGoColors | READY | `tajgo_colors.dart:3-20` — 20 цветов |
| TajGoTypography / Spacing / Radius / Durations / Shadows / IconSizes | **NOT_IMPLEMENTED** | магические числа по виджетам (радиусы 12/16/18/99, `Duration(250)`, inline shadows) |
| Theme | PARTIAL | `tajgo_theme.dart` только light, без `darkTheme`/`themeMode`/`TextTheme` |
| Компоненты (Scaffold/AppBar/PrimaryButton/Card/SectionHeader/SearchField/Price/PartnerCard/ProductCard/OrderCard/StatusChip/EmptyState/ErrorState/LoadingSkeleton/BottomSheet/ConfirmationDialog/OfflineBanner) | **NOT_IMPLEMENTED** | только `TajGoActionButton` близок к примитиву; остальное ad-hoc `Scaffold`/`AppBar`/`Card` |
| Shared widgets (12 шт.) | PARTIAL | визуально связны, но feature-display, не переиспользуемые примитивы; каждый импортит `TajGoColors` и хардкодит отступы |

## 5. Сводные RC-блокеры (по приоритету)

**P0 — store-policy и greenfield-функции (обязательны для RC):**
1. Удаление аккаунта (#22) — client + backend + web-страница.
2. Заявки магазинов (#16/#17) — новая подсистема + admin-раздел.
3. iOS identity (#31) — bundleId + GoogleService-Info.plist + подпись (MAC_REQUIRED для сборки).
4. Privacy/Terms/Support экраны (#23) + черновики.

**P1 — фундамент UI и оболочка:**
5. Дизайн-система (Этап 2) — токены + компоненты.
6. CustomerShell 5 табов + Marketplace search (#3/#5).
7. Feature flags / AppEnvironment (#28).
8. Saved addresses (#8), cart-persistence (#12).

**P2 — операционная надёжность:**
9. FCM (#25, код + флаг, backend DEPLOY_REQUIRED).
10. Crashlytics/Diagnostics (#26), App Check prep (#27).
11. Authoritative-split: перенести marketplace CRUD/import и `forceOffline` на Functions ИЛИ доказать rules-покрытие (#18b/#19/#20).

**P3 — release/store:**
12. Android signing (#30, SIGNING_REQUIRED), SDK pin.
13. Store metadata (#32), two-phone plan (#36), smoke (#35), GO/NO-GO (#38), owner setup (#39).

## 6. Watch-items (корректность, не блокеры)

- `deliveryFee < 10`: клиент показывает total ниже, чем спишет сервер (сервер floor 10). Синхронизировать клиентский расчёт.
- Цены — `num` в major-сомони, не minor units; kg-позиции дают дробные total и float-риск; нет общего money-форматтера.
- `TajGoOrder.fromDoc` парсит `confirmationCode` в модель (не отображается, но проверить rules-проекцию для курьера).
- Внешние навигаторы: `geo:`-fallback не запустится на iOS (нет Platform-guard).
- `CourierOrderEligibilityService` — мёртвый код, дублирует `<1000`; либо wired-in (staleness/accuracy гейты в UI), либо удалить.
- `demo_tools_screen.dart` — недостижимый мёртвый код (в release уже под `kDebugMode`).
- Courier onboarding: загрузка документов/фото и верификация телефона — честные заглушки (только личная встреча).

## 7. Что НЕ требует переписывания (READY — не трогать без необходимости)

Phone Auth, startup routing, order tracking, catalog checkout (backend-часть), offers realtime + selection, courier active delivery, delivery-code security, admin orders/couriers/dispatch/logs (Function-based actions), map new-order flow, external navigator URI-генерация (destination-only, без утечки кода/телефона).

## 8. Ограничения аудита

Не проверялось (по средам): реальная SMS/Console Phone Auth, поведение на физических Android/iOS, два телефона, deployed Rules/Functions/indexes, реальные production-данные, IPA-сборка (нет macOS), реальные внешние приложения-навигаторы. Эти пункты помечены PHONE_REQUIRED / DEPLOY_REQUIRED / MAC_REQUIRED и не могут получить статус выше на текущей среде.
