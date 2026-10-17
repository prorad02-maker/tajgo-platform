# TajGo Release Readiness Audit 2026

Дата аудита: 2026-08-04
Проект: `C:\Projects\tajgo`
Scope: ЭТАП 1 — диагностика без массового рефакторинга и без Firebase deploy.
Итог: **NO-GO для production / CONDITIONAL GO для локального smoke и дальнейшего исправления до Blaze**.

## Executive summary

Кодовая база заметно подготовлена к релизу: Android уже компилируется и target-ится на API 36, критические операции заказа/цены/статусов в основном заведены в callable Functions, Firestore Rules закрывают прямые записи в orders/offers/catalog, App Check enforcement не включён, debug и release/R8 APK собираются, `flutter analyze` чистый, 97 Flutter-тестов и 19 Functions unit-тестов проходят.

Production-релиз сейчас блокируют пять условий:

1. **P0 — Firebase Android identity drift.** Dart runtime и нативный Android слой используют разные Firebase Android App ID. Это должно быть согласовано владельцем до Phone Auth/FCM/Crashlytics/App Check smoke.
2. **P0 — Cloud Functions недоступны до Blaze/deploy.** Startup вызывает `ensureUserProfile`, а создание заказа, смена статусов, marketplace checkout, удаление аккаунта и другие authoritative команды зависят от Functions.
3. **P0 — production signing отсутствует.** Release APK успешно собран, но подписан `CN=Android Debug`.
4. **P0 — часть courier-admin authority остаётся в мобильном клиенте.** approve/reject/suspend/restore выполняются прямыми Firestore-транзакциями, а admin Rules дают широкие права на критические документы.
5. **P0 — Google Play legal web surface не готов.** Есть только локальный шаблон account-deletion; нет доказанного публичного URL и public Privacy/Terms/Support страниц, а support email требует подтверждения.

Карта функционально богата, но пока не production-grade: road routing выключен по умолчанию, direct-line fallback влияет на маршрут/цену, публичные OSM tiles жёстко зашиты, на части экранов отсутствует attribution, stale/poor GPS не блокируется, а новый заказ повторно создаёт Firestore stream при частых rebuild. Карту не переписывали; ниже дан отдельный план.

## Current baseline

### Git

| Поле | Значение |
|---|---|
| Branch | `main` |
| Upstream | `origin/main`, локально ahead 17 |
| HEAD | `f728210` |
| HEAD message | `diag(functions): log raw FirebaseFunctionsException before user-message mapping` |
| Stash | `stash@{0}: On main: wip v1.5.1 pilot hardening before v1.7 audit` — не тронут |

Последние 10 коммитов:

```text
f728210 diag(functions): log raw FirebaseFunctionsException before user-message mapping
1242123 fix(startup): AppStartupRouter reacts to authStateChanges after Phone Auth
20004bd fix(startup): setState no longer receives a Future-returning callback
da96c1a docs(v1.8-p2): artifact manifest, GO/NO-GO, two-phone, owner setup, smoke
e873e8c feat(v1.8-p2): Android release + iOS identity + store metadata (P4)
1a232fb feat(v1.8-p2): FCM, diagnostics, App Check prep (P3)
e5d58d9 feat(v1.8-p2): JSON/CSV/XLSX price import with dry-run (P2b)
6eb3261 feat(v1.8-p2): admin catalog via authoritative Functions (P2a)
6bfbc27 feat(v1.8-p2): full orders tab + marketplace UI polish (P1)
57c337b feat(v1.8-p2): saved addresses + cart persistence (P1)
```

### Предсуществующие локальные изменения

До текущего запуска аудита существовали два локальных объекта:

```text
M android/app/google-services.json
?? RELEASE_AUDIT_2026.md
```

`google-services.json` не изменялся аудитом. Существовавший untracked-черновик `RELEASE_AUDIT_2026.md` проверен по текущему HEAD и уточнён на месте без удаления его выводов. `stash@{0}` не применялся, не удалялся и не изменялся. Firebase deploy, git push и commit не выполнялись.

Диагностические команды создали/обновили только ignored build output и `functions/lib/`. Исходный код и tracked-конфигурация аудитом не менялись; единственный намеренно обновлённый пользовательский файл — этот untracked-отчёт.

## P0

| Issue | Evidence | Риск | Рекомендуемое исправление |
|---|---|---|---|
| Firebase Android App ID mismatch | `firebase.json:6-8`, `lib/firebase_options.dart:56-58`; выборочная проверка текущего `google-services.json` показала: `tj.tajgo.app` → appId `...:0ac2...`, а Dart Android options → `...:33da...`, связанный с `com.example.tajgo` | Phone Auth SHA/fingerprints, FCM, Crashlytics и App Check могут обращаться к разным Firebase app registrations; возможны auth failure, missing token и неверная телеметрия | Владелец выбирает единственную Android app registration для `tj.tajgo.app`, затем через FlutterFire CLI согласует `firebase_options.dart`, `firebase.json`, Console SHA-1/SHA-256 и `google-services.json`. Не менять вслепую и не коммитить до проверки diff |
| Functions required but unavailable | `lib/features/startup/app_router.dart:152-168`, `lib/core/services/user_repository.dart:18`, `lib/core/services/order_repository.dart:39`, `lib/shared/widgets/tajgo_scope.dart:39-42` | Вход до профиля и все authoritative команды не проходят; основной production flow недоступен | После Blaze deploy Functions в `europe-west1`, затем emulator/real-project smoke. До этого UI/offline/unit можно улучшать |
| No production signing | `android/app/build.gradle.kts:13-18,42-72`; `android/key.properties` отсутствует, keystore в repo отсутствует; собранный release APK имеет DN `CN=Android Debug` | Play AAB нельзя публиковать; неправильный upload key создаст долгосрочную проблему обновлений | Выполнить owner steps из Signing; включить Play App Signing; проверить сертификат AAB перед upload |
| Courier approval/suspension client-authoritative | `lib/core/services/courier_application_repository.dart:135-215,218-363`; вызовы `lib/features/admin/admin_courier_application_details_screen.dart:148-199`; широкие admin writes `firestore.rules:82-89,170-175,228-238,277-287` | Модифицированный/скомпрометированный admin-клиент задаёт role/status/courier public data и бизнес-переходы; серверного единого инварианта нет | Добавить backend commands approve/reject/suspend/restore, серверный `principal.uid`, transition validation и idempotency; после миграции запретить эти прямые admin writes Rules |
| Play legal URLs not production-ready | Есть `public/account-deletion.html`, но public privacy/terms/support HTML отсутствуют; `docs/V1_8_STORE_LISTING_RU.md:34-36` содержит предполагаемые URL; `docs/V1_8_SUPPORT_PAGE.md:9` требует заменить/подтвердить email | Play submission/review rejection; пользователь не может получить policy/support вне приложения | Опубликовать HTTPS Privacy, Terms, Support, Account deletion; проверить форму/почту и соответствие Data Safety; URL вне login и mobile-friendly |

## P1

| Issue | Evidence | Риск | Рекомендуемое исправление |
|---|---|---|---|
| Order detail can spin forever on error/not-found | `lib/features/customer/order_tracking_screen.dart:314-320`; `lib/features/courier/courier_order_screen.dart:506-512` | Permission-denied, deleted order или offline выглядит как вечная загрузка без retry/back | Разделить waiting/error/not-found/offline, дать retry/back/support |
| FCM token refresh listener leaks across enables/accounts | `lib/core/services/push_notification_service.dart:54-64`; listener не хранится/не отменяется; deletion logout в `account_deletion_screen.dart:160-161` не вызывает disable | Повторное включение создаёт duplicate writes; после смены аккаунта refresh может записать токен старому UID | Хранить одну `StreamSubscription`, отменять при disable/logout/delete, привязывать active UID и деактивировать старую запись |
| PII and identifiers in logs | UID: `lib/features/startup/app_router.dart:84,144,151,170`; full address/coordinates: `lib/features/map/screens/new_order_map_screen.dart:381-387`; raw Function details: `lib/core/services/authoritative_command_service.dart:19-32`; backend uid/error: `functions/src/notifications.ts:41-43` | Production logs/Crashlytics могут содержать stable IDs, адрес и provider/server details | Central redacted logger; полный адрес/координаты никогда не логировать; UID hash/mask; raw details только debug/emulator и без PII |
| Routing release configuration is inconsistent | Feature flag использует `TAJGO_ROUTING_ENABLED` (`lib/core/config/feature_flags.dart:93`), provider читает `ROUTING_ENABLED`/`TAJGO_ROUTE_ENABLED` (`lib/features/map/services/routing_config.dart:56-61`) | Один флаг может показывать routing enabled в диагностике, но фактически оставлять direct fallback | Оставить один typed config source; release build manifest должен фиксировать endpoint/profile/timeout и health probe |
| Direct-line fallback silently drives distance/price | `lib/features/map/services/direct_route_provider.dart:21-59`; `lib/features/map/screens/new_order_map_screen.dart:361-378,433-442`; road provider по умолчанию disabled `routing_config.dart:56-61` | Цена/ETA и линия могут пересекать реку/закрытые дороги и существенно занижать путь | До release выбрать production routing provider; direct fallback явно маркировать как оценку и не использовать как финальную tariff authority без server correction |
| OSM tile production/attribution gap | Hardcoded `tile.openstreetmap.org`: `map_point_picker_screen.dart:72-76`, `dispatch_map_screen.dart:205-210`, `admin_order_details_screen.dart:437-440`, `admin_marketplace_screen.dart:1015-1019`; в этих местах нет `RichAttributionWidget`; URL также есть на остальных экранах | Нарушение OSM attribution/usage policy, блокировка tile service, отсутствие SLA | Централизованный tile provider/config, видимый `© OpenStreetMap contributors` на каждом map viewport, корректный contactable User-Agent/cache; выбрать коммерческий/собственный production provider |
| GPS accepts stale/poor fixes | `lib/features/map/services/tajgo_location_service.dart:77-87,155-169`; new order лишь показывает weak flag `new_order_map_screen.dart:93-99,230-233` | Неверная pickup/dropoff, courier proximity и route progress | Валидировать `timestamp`, accuracy threshold и координаты; last-known только с age label; retry/accuracy state; server remains authoritative for critical proximity |
| Location stream remains active while app inactive | Courier observers реагируют только на resume: `courier_home_screen.dart:55-60`, `courier_order_screen.dart:85-88`; отмена только offline/dispose | Battery/privacy, Android background restrictions, непредсказуемый stop/error без background permission | На inactive/paused прекращать stream и публиковать policy-defined state. Background tracking добавлять только при доказанной необходимости с foreground service, disclosure и Play declaration |
| Map rebuild resubscribes Firestore stream | `lib/features/map/screens/new_order_map_screen.dart:548-550` вызывает `onlineCouriersStream()` прямо в build; тот же экран часто вызывает setState при map gestures/tile/GPS | Повторные listener subscriptions/network reads, marker recreation и jank | Кэшировать stream в state, отделить map/courier layers от bottom-panel state, обновлять marker sets только при data change |
| Startup can show no Flutter recovery UI if Firebase bootstrap throws | `lib/main.dart:16-28` вызывает `runApp` только после Firebase/Crashlytics/App Check awaits | Ошибка config/native init даёт нативный splash/blank screen без retry | Минимальный app shell до remote init либо guarded bootstrap state с retry/diagnostics |
| No runtime evidence for Android 16/map performance | В репозитории нет актуального Skipped frames/Choreographer/ANR trace; только кодовый `MapPerformanceMonitor` | Нельзя подтвердить smoothness, resume и API 36 behavior | Profile-mode physical-device run, DevTools frame chart, Android 16 edge-to-edge/back/permission/resume matrix; приложить trace и thresholds |

## P2

| Issue | Evidence | Риск | Рекомендуемое исправление |
|---|---|---|---|
| Very large stateful widgets | `new_order_map_screen.dart` 1568 lines, `courier_order_screen.dart` 1229, `order_tracking_screen.dart` 1012, `courier_home_screen.dart` 983, `admin_marketplace_screen.dart` 1066 | Сложно тестировать lifecycle, легко получить взаимные rebuild/race | После P0 разбить по state controller/use-case и визуальным секциям без смены всей архитектуры |
| Marketplace/admin queries not paginated | `marketplace_repository.dart:52-110`, `merchant_application_repository.dart:24-30`; admin caps 100/200 без cursor | Рост reads/memory, неполная выборка после лимита | Cursor pagination, explicit sort and empty/end state |
| Home hides backend errors as empty content | `customer_home_tab.dart:90-103,235-243,267-272`; new-order couriers `new_order_map_screen.dart:548-552` | Offline/permission error выглядит как «нет данных/курьеров» | Неблокирующий offline/error banner и retry; сохранять last-known UI |
| Cart persistence writes race | `lib/core/models/marketplace_cart.dart:115-118,159-182` запускает async persist без serialization | Быстрые increment/decrement могут завершить writes не по порядку и восстановить устаревшую корзину | Debounce/serialize writes, await flush on lifecycle pause, version cache |
| `MapPointPickerScreen` collapses location errors | `lib/features/map/screens/map_point_picker_screen.dart:31-52` | deniedForever/servicesDisabled не ведут в settings и не различаются | Использовать общий location issue UI и settings action |
| Route JSON parser trusts provider shape | `lib/features/map/services/road_route_provider.dart:77-85,144-218` | Bad/malformed response бросает CastError; общий fallback спасает route, но диагностика грубая | Defensive parsing, response size/content-type guard, typed provider errors |
| Tile/marker/polyline objects recreated in builds | Например `new_order_map_screen.dart:583-655`, `dispatch_map_screen.dart:170-290` | Allocation/jank при frequent state updates | Memoize immutable options/layers, isolate animated marker updates, RepaintBoundary where measured |
| No dedicated map widget/device tests | Основные map tests в `test/widget_test.dart` проверяют layout/model helpers, но не permission/resume/tile error/live gestures | Регрессии проявятся только на телефоне | Integration tests with fake location/route provider + physical matrix |
| Build toolchain warnings | Debug/release build: plugins `cloud_functions`, `firebase_app_check` применяют KGP; SDK XML v4 warning; Java 8 warnings in dependencies | Будущая Flutter/Gradle версия может сломать build | Зафиксировать known-good CI image; review compatible plugin patches; выровнять command-line tools/Android Studio |
| Brand metadata inconsistent | Android label `TajGo`, MaterialApp title `TajGo+` (`lib/app/tajgo_app.dart:28`), pubspec description всё ещё template (`pubspec.yaml:2`) | Store/OS branding inconsistency | Зафиксировать одно имя, описание и локализации перед listing |

## P3

- `permission_handler` объявлен в `pubspec.yaml`, но фактический location flow использует `geolocator`; проверить необходимость и удалить только отдельным safe cleanup.
- `Analytics` dependency/implementation отсутствует. Это не blocker; решение должно быть осознанным из-за consent/Data Safety.
- TODO/FIXME/HACK в `lib/`, `test/`, Android и Functions source не найдено. Deprecated notices идут из package lock/build dependencies.
- `pubspec.yaml:2` содержит шаблонное описание `A new Flutter project.`.
- `MainActivity` минимален и корректен: `android/app/src/main/kotlin/tj/tajgo/app/MainActivity.kt:1-5`.

## Map audit

### Что уже хорошо

- Различаются `serviceDisabled`, `denied`, `deniedForever`, `unavailable`: `tajgo_location_service.dart:8-20,28-54`.
- GPS request имеет high accuracy и 15 s time limit: `tajgo_location_service.dart:77-84`.
- New order не показывает permission prompt автоматически: `currentPositionIfAuthorized`, строки 57-74.
- Есть request IDs против stale reverse-geocode/route response: `new_order_map_screen.dart:51-52,199-207,365-378`.
- Camera animation коалесцирует близкие цели и отменяется по id: `tajgo_map_camera.dart:12-67`.
- Pickup/dropoff имеют отдельные стадии, центральный pin, search sheet, safe-area bottom panel, fit route и manual recenter.
- Route service имеет in-flight de-duplication, cache, sanity check, health/performance monitor и direct fallback: `lib/features/map/services/route_service.dart`.
- OSRM/GraphHopper calls имеют timeout и parsing; API key удаляется из diagnostic URL.
- Courier screens используют один shared native position stream и отменяют subscription в dispose.
- На основных customer/courier map экранах attribution уже есть.

### Недостатки по checklist

| Область | Статус | Наблюдение |
|---|---|---|
| Permission granted/denied/forever/services disabled | NEEDS WORK | Core service различает; picker collapse-ит; resume after settings не автоматизирован на всех экранах |
| GPS timeout/stale/accuracy/retry | NEEDS WORK | Timeout есть; stale/poor fix не отвергается; retry UI непоследователен |
| Initial camera/zoom/recenter | GOOD/NEEDS WORK | New order умеет passive center и animate; picker использует hard move; нет общего restore-on-resume contract |
| My-location | GOOD | Явная кнопка, progress и user-facing errors на главной карте |
| Pickup/dropoff/selected point | GOOD | Отдельные A/B и central selection, duplicate request guard |
| Keyboard/bottom sheet/safe area | GOOD | Sheet учитывает viewInsets; основные panel layout tests проходят |
| Polyline/fitBounds/padding | NEEDS WORK | Fit есть; padding фиксированный и не всегда учитывает dynamic panel; fallback — прямая линия |
| Empty/bad routes | GOOD/NEEDS WORK | Sanity/fallback есть, но UX недостаточно явно сообщает approximate route |
| OSRM production suitability | BLOCKER | Выключен default, endpoint не выбран, retry/rate-limit/SLA/provider terms не доказаны |
| Tile production suitability | BLOCKER | Public OSM URL hardcoded; attribution missing на части экранов; no SLA/config switch |
| Rebuilds/network calls/jank | NEEDS WORK | Firestore stream создаётся в build, крупные widgets и regenerated layers; profile trace отсутствует |

## Map release plan

### MAP P0

1. Выбрать production tile и routing providers: SLA, региональное покрытие Худжанда, профиль bike/car, quota/rate limit, privacy, стоимость, attribution.
2. Устранить routing flag split; записывать provider/config manifest в build artifacts без ключей.
3. Не использовать silent direct-distance как подтверждённый road route/финальную серверную цену.
4. Добавить attribution на каждый viewport и вынести tile config из widgets.
5. Провести field test A/B на физических телефонах: GPS off/denied/forever/poor/stale, route outage, app resume, slow network.

### MAP P1

1. Создать единый `MapSessionState`: permission, current fix age/accuracy, selected A/B, camera intent, route state, retry.
2. Кэшировать Firestore streams и marker/polyline models; уменьшить rebuild area.
3. Добавить provider retry с bounded backoff/jitter только для retryable errors; 429/5xx/offline различать.
4. Пересчитывать fit padding по реальной высоте panel/safe areas/keyboard.
5. На pause остановить live location; на resume перепроверить service/permission и восстановить camera без рывка.
6. Явно показывать `маршрут приблизительный` и не скрывать provider failure.

### MAP P2

1. Разделить `new_order_map_screen.dart` на controller + viewport + search + details panel.
2. Добавить integration/widget tests с fake GPS/geocoder/router и golden/layout matrix.
3. DevTools profile: target 60 fps, отсутствие repeated Firestore listeners, route/search latency metrics, memory after 10 open/close cycles.
4. Улучшить stale courier presentation, marker heading animation и accessible labels.

## Android / API 36

Фактические значения повторно извлечены из собранного текущим аудитом debug APK через `aapt`; pre-existing release artifact имеет ту же Gradle-конфигурацию:

| Параметр | Фактическое значение | Source |
|---|---:|---|
| applicationId/package | `tj.tajgo.app` | APK / `android/app/build.gradle.kts:29` |
| namespace | `tj.tajgo.app` | `build.gradle.kts:22` |
| minSdk | **24** | APK; Gradle `maxOf(flutter.minSdkVersion, 23)` фактически разрешился в 24 |
| compileSdk | 36 | APK / `build.gradle.kts:24` |
| targetSdk | 36 | APK / `build.gradle.kts:34` |
| versionCode | 32 | APK / `pubspec.yaml:19` |
| versionName | 1.8.0 | APK / `pubspec.yaml:19` |
| Java/Kotlin | JVM 17 | `build.gradle.kts:27-28,81-83` |
| AGP / Gradle | AGP 9.0.1 / Gradle 9.1.0 | `settings.gradle.kts`, wrapper |

С 31 августа 2026 новые приложения и updates в Google Play должны target API 36: [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-GB_ALL). Конфигурация проходит числовое требование, но API 36 readiness ещё требует physical smoke по target behavior changes: [Android 16 changes](https://developer.android.com/about/versions/16/behavior-changes-16).

### Permissions из текущего debug APK

- Declared by app: `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`.
- Merged from dependencies/FCM: `WAKE_LOCK`, `ACCESS_NETWORK_STATE`, `com.google.android.c2dm.permission.RECEIVE`, `READ_GSERVICES`, non-exported dynamic receiver permission.
- **Нет** camera, storage/media, foreground service, foreground service location и background location.
- Background location добавлять не нужно без нового доказанного product requirement. Текущий foreground stream следует останавливать на pause.

R8/resource shrink включены: `build.gradle.kts:56-61`; в workspace уже был pre-existing release APK со shrinking. Текущий аудит release build не повторял, потому что production signing отсутствует. ProGuard rules консервативны и сохраняют целиком Firebase/Play classes, поэтому размер/obfuscation можно улучшать только после production smoke.

## Firebase client

| Component | Статус | Evidence / action |
|---|---|---|
| Core | BLOCKER CONFIG | App ID mismatch, см. P0 |
| Auth | CODE READY / CLOUD BLOCKED | Phone auth, anonymous only debug, account conflict и reauth есть; нужен correct SHA + physical SMS test |
| Firestore | CONDITIONAL | Rules deny direct orders/offers/catalog writes; saved addresses/tokens/presence разрешены owner; courier admin authority требует backend migration |
| Functions | BLOCKER UNTIL BLAZE | Client and functions use `europe-west1`; deploy не выполнялся |
| Messaging | NEEDS WORK | Permission on demand и privacy-safe payload tests есть; token-refresh lifecycle bug; triggers inactive until deploy |
| Crashlytics | NEEDS CONFIG/PRIVACY QA | Enabled by default in non-debug; App ID alignment and redacted logs required |
| App Check | PREPARED/OFF | Feature default false; enforcement не включать до registration/metrics/rollout |
| Analytics | NOT IMPLEMENTED | Не blocker; если добавить — consent/Data Safety plan required |

Functions index и notification triggers используют `europe-west1`: `functions/src/index.ts:14-15`, `functions/src/notifications.ts:46-65`.

## Security

### Good

- Mobile clients cannot directly create/update/delete orders or offers: `firestore.rules:310-340`.
- Delivery secret read/write denied: `firestore.rules:344-359`.
- Catalog writes backend-only: `firestore.rules:389-415`.
- Functions recalculate/validate critical order price/state and use idempotency documents.
- Delivery codes use salted scrypt and constant-time comparison; unit tests pass.
- FCM unit tests assert no code/phone/address payload.
- Keystore, key.properties, service accounts and env files are ignored.

### Findings

1. P0 client-side courier admin decisions and broad admin Rules — migrate as above.
2. P1 FCM subscription can associate refresh with stale UID.
3. P1 PII logs: UID, coordinates, full address and raw error details.
4. P2 local saved/recent places and cart live in SharedPreferences, not encrypted. This is acceptable only if privacy model explicitly treats them as low-risk local convenience; full address/comment retention should be documented and cleared on account deletion/logout if required.
5. Firebase API keys in generated client config are identifiers, not server secrets, but provider API keys delivered via `--dart-define` can be extracted from APK. Production routing secrets should be backend/proxy scoped and quota-restricted.
6. `isAdmin()` accepts either custom claim or `users.role == admin` (`firestore.rules:17-22`). Prefer custom claims for authorization and Firestore role only for display; remove document-based fallback after migration.

## Performance

- Startup performs Firebase init, Crashlytics init and App Check activation before `runApp`; any slow/failing native init delays first Flutter frame.
- `TajGoScope` eagerly creates repositories and starts unawaited cart hydration; hydration not blocking is good, but write serialization is missing.
- Firestore lists generally have limits for orders/couriers, but marketplace/merchant and some admin streams remain unbounded or fixed-cap without pagination.
- Map screens recreate layers and, in new order, the Firestore stream on setState.
- Asset sizes are high: `app_icon.png` ~1.25 MB, splash images ~1.45 MB each, logo ~0.44 MB. Validate decoded memory and compress source assets without visual loss.
- Release tree shaking reduced Material Icons by 98.8%; APK is 65.8 MB. For Play use AAB and inspect download size/ABI split.
- No current Skipped frames trace was found. Therefore jank is **not disproved** by green unit tests.

## UX release audit

| Flow | Status | Причина / next step |
|---|---|---|
| Splash | NEEDS WORK | Внутренний splash retry есть, но pre-runApp Firebase failure has no UI |
| Onboarding/intent | GOOD | Customer/courier intent, no admin self-selection, tests pass |
| Login/Phone Auth | BLOCKER | Code flow good; Firebase App ID/SHA and real SMS/Functions startup not proven |
| Customer main | NEEDS WORK | Good shell/navigation; some backend errors silently disappear |
| Map/new custom order | BLOCKER | Provider/tile/GPS/P0 map plan required; layout tests pass |
| Address selection/saved addresses | NEEDS WORK | Manual fallback good; picker errors/settings and local privacy cleanup incomplete |
| Catalog/search | NEEDS WORK | Loading/error/empty mostly present; production data/provider and pagination need proof |
| Cart | GOOD/NEEDS WORK | Persistence and server price reconciliation exist; persistence race and Functions dependency |
| Order creation | BLOCKER | Backend-authoritative design good; unavailable until deploy/Blaze and real test |
| Orders list | GOOD | Error/empty/filter UI exists; pagination limited |
| Order details/tracking | BLOCKER | Infinite spinner on error/not-found; live Firebase/route not proven |
| Courier flow | BLOCKER | Background lifecycle, GPS field test, Functions and admin authority |
| Profile/settings | GOOD/NEEDS WORK | Logout, notifications and navigation settings exist; disabled pilot controls add polish debt |
| Account deletion | BLOCKER | In-app reauth/backend design exists; Function unavailable and public URL not deployed/proven |
| Privacy/Terms | NEEDS WORK | In-app documents and acceptance exist; public final legal documents/owner review required |
| Support | BLOCKER | Screen exists, but support mailbox/response process and public URL unverified |

## Google Play policy readiness

Google requires Data Safety disclosure and a privacy policy even for many testing/release situations: [Data Safety help](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en). Apps that create accounts need both an in-app deletion path and a web deletion request resource: [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN).

| Item | Status | Owner action |
|---|---|---|
| Privacy Policy | BLOCKER | Final legal review; publish HTTPS URL; match actual Firebase/location/crash/token processing |
| Terms | BLOCKER | Finalize operator entity, jurisdiction, support and publish |
| Support | BLOCKER | Confirm mailbox, SLA/runbook, public support URL |
| Account deletion in-app | CODE READY / CLOUD BLOCKED | Deploy/test `deleteAccountRequest`, auth deletion, retention/anonymization, active-order block |
| Account deletion web URL | BLOCKER | Publish/test `public/account-deletion.html`; no login requirement; verify request reaches owner |
| Data Safety | DRAFT | Reconcile `docs/V1_8_PLAY_DATA_SAFETY_DRAFT.md` with exact release flags/SDK behavior |
| App name | NEEDS WORK | Choose `TajGo` vs `TajGo+` consistently |
| Icon/splash | READY FOR VISUAL QA | Assets and adaptive icons exist; device/Play preview QA required |
| Package | READY/IRREVERSIBLE | `tj.tajgo.app`; confirm before first Play artifact |
| Version | READY FOR NEXT BUILD | `1.8.0+32`; ensure every uploaded AAB increments versionCode |
| Store listing docs | DRAFT READY | RU/TJ drafts exist; owner/legal/product review |
| Screenshots | PLAN ONLY | Capture production-like data, correct devices/locales, no PII/test labels |
| Content rating | OWNER REQUIRED | Declare delivery marketplace/user interaction/location; answer Console questionnaire honestly |
| Ads declaration | OWNER REQUIRED | No ads SDK found; declare “No ads” only after final dependency scan |
| Target audience | OWNER REQUIRED | Set intended adult/general audience; avoid child-directed claim unless full Families compliance |
| App access | OWNER REQUIRED | Provide review credentials/instructions for phone auth and gated roles |

Play Console автоматически не изменялся.

## Signing

**SIGNING_REQUIRED=YES**

- Debug: standard Android debug keystore.
- Release without `android/key.properties`: project intentionally falls back to debug signing and warns.
- Production keystore: not found in project; `android/key.properties` absent.
- Ignore rules: `.gitignore:49-55`, `android/.gitignore:10-14` correctly exclude `*.jks`, `*.keystore`, `android/key.properties`, service accounts/env.
- Pre-existing diagnostic release APK: R8 enabled, ранее проверенный signer `C=US, O=Android, CN=Android Debug`; текущим аудитом не пересобирался; **do not distribute/upload**.

Owner steps:

1. Enroll in Google Play App Signing and decide upload-key custody.
2. Generate upload keystore outside repository; store passwords in password manager; create encrypted offline backup.
3. Copy `android/key.properties.example` to ignored `android/key.properties` and use absolute external keystore path.
4. Build AAB (`flutter build appbundle --release`) only after Firebase identity is reconciled.
5. Verify AAB/APK certificate SHA-256; add release SHA-1/SHA-256 to the **same** Firebase Android app `tj.tajgo.app`.
6. Run R8 release smoke on physical API 24, representative API 33/35 and API 36 devices.
7. Never commit keystore, passwords, key.properties or service-account JSON.

## Dependencies

`flutter pub outdated` found patch/minor upgrades across FlutterFire and one direct major (`permission_handler 13`). Dependencies were not changed.

### SAFE NOW (отдельный PR + full test/build)

- `cloud_functions 6.3.5 → 6.3.6`
- `firebase_auth 6.5.6 → 6.5.7`
- `firebase_crashlytics 5.2.6 → 5.2.7`
- `firebase_app_check 0.4.5+2 → 0.4.6`

Даже patch обновления выполнять только после Firebase identity fix и с debug/release build, поскольку build уже предупреждает о KGP integration.

### REVIEW

- `cloud_firestore 6.7.1 → 6.8.0`
- `firebase_core 4.12.1 → 4.13.0`
- `firebase_messaging 16.4.3 → 16.5.0`
- associated transitive FlutterFire/platform packages
- `shared_preferences_android`, `package_info_plus`, `uuid`, iOS platform patches

Нужны changelog, Firebase smoke, token refresh/logout, R8 and API 36 build.

### DO NOT UPDATE BEFORE RELEASE

- `permission_handler 12 → 13` и `permission_handler_android 13 → 14` (major; сначала доказать, что dependency вообще нужна).
- Forced `win32` override и desktop ecosystem packages — не трогать в Android release stabilization.
- Analyzer/archive/image/xml/unicode and other large transitive major jumps — только отдельным maintenance cycle.
- Flutter/AGP/Gradle/Kotlin major changes — текущий APK уже строится; не смешивать с release blockers.

## Test results

| Проверка | Результат | Детали |
|---|---|---|
| `flutter doctor -v` | PASS для Android | Flutter 3.44.4/Dart 3.12.2; Android SDK 36.1; licenses accepted. Chrome/Visual Studio отсутствуют — не Android blocker |
| `flutter pub outdated` | PASS/info | 31 locked upgradable; 2 direct constraints behind resolvable major/minor |
| `flutter analyze` | PASS | No issues found, 74.5 s (80.9 s wall time) |
| `flutter test` | PASS | 97 tests |
| `functions/npm.cmd run build` | PASS | TypeScript compile |
| `functions/npm.cmd test` | PASS | 19 unit tests |
| `flutter build apk --debug` | PASS | `app-debug.apk`, ~202.5 MiB |
| `flutter build apk --release` | NOT RERUN | Pre-existing artifact ~65.8 MiB is DEBUG-SIGNED; production key отсутствует, upload запрещён |
| Firestore Rules emulator | NOT RUN by requested command set | Tests exist; must run before deploy/release |
| Functions integration emulator | NOT RUN by requested command set | Must run before deploy/release |
| Physical Android/API 36 | NOT RUN | Required |
| Real Firebase Phone Auth/Functions/FCM | BLOCKED | App identity + Blaze/deploy/setup required |

Build warnings:

- `cloud_functions` and `firebase_app_check` still apply KGP; future Flutter may reject this integration.

## What can be fixed before Blaze

- Firebase identity/config plan and Console app selection (без deploy Functions).
- Production signing owner setup and certificate inventory.
- All map P0/P1 client changes except provider secret/backend rollout.
- OSM attribution and provider abstraction.
- GPS stale/accuracy/lifecycle UX.
- Error/not-found/offline/retry states.
- FCM subscription lifecycle and log redaction.
- Migrate courier admin decisions into Functions source and emulator-test locally; cloud activation waits for Blaze.
- Public legal/support/deletion pages and store documentation.
- Pagination, widget decomposition, profile-mode performance tests.
- API 36 physical UI/permission/back/resume testing using flows that do not require cloud commands.

## What requires Blaze

- Deploy callable Functions and notification triggers in `europe-west1`.
- End-to-end startup `ensureUserProfile`.
- Real create/order/offers/status/completion/catalog/admin command flows.
- In-app account deletion authoritative flow.
- FCM backend triggers.
- Post-deploy App Check metrics/registration rollout. Enforcement остаётся выключенным до отдельного решения.
- Operational logging/alerts and production-like load/cost verification.

## Recommended implementation order

1. Freeze and reconcile Firebase Android identity; confirm package and Console app.
2. Fix P0 client-authoritative courier admin transitions in Functions source + Rules emulator tests.
3. Fix P1 infinite loading, FCM subscription lifecycle and PII logging.
4. Execute MAP P0, then MAP P1; field-test before visual polish.
5. Finalize public Privacy/Terms/Support/Deletion and Data Safety inventory.
6. Create production upload key, register SHA fingerprints, build/verify AAB.
7. After Blaze deploy Functions/Rules/indexes with explicit owner change window; run two-phone matrix.
8. Closed testing, Crashlytics/ops review, performance trace, policy pre-check.
9. Production staged rollout only after exit gates.

## Release decision

**NO-GO** for Google Play production today.

**CONDITIONAL GO** for continued pre-Blaze implementation and local/debug smoke because analyze/tests/builds pass. Closed testing becomes possible only after P0 Firebase identity, signing, backend authority, legal URLs and Blaze Functions are resolved.

## Phase table

| Phase | Scope | Exit gate | Current |
|---|---|---|---|
| PHASE 1 FIX BEFORE BLAZE | Firebase identity plan, backend-source authority, error states, FCM lifecycle, log redaction, legal pages | P0 code/config diffs reviewed; emulator tests green | COMPLETE (CODE) / OWNER+CLOUD GATES REMAIN |
| PHASE 2 MAP | Provider decision, attribution, GPS state, routing accuracy, rebuild/jank, field matrix | Map P0/P1 closed; physical profile trace and outage tests pass | NOT READY |
| PHASE 3 UX/POLISH | Main flows, offline/retry/empty, accessibility, branding, screenshots | UX table has no BLOCKER; device/layout/localization QA | NOT READY |
| PHASE 4 ANDROID RELEASE | API 36 smoke, signing, AAB, R8, Play metadata | Production-signed AAB verified; package/version/fingerprints correct | SIGNING BLOCKED |
| PHASE 5 AFTER BLAZE | Deploy Functions/Rules/indexes, App Check observe-only, FCM, deletion | Full real Firebase and two-phone tests pass; alerts ready | BLOCKED BY BLAZE |
| PHASE 6 CLOSED TESTING | Play closed track, tester feedback, ANR/crash/performance/policy | No P0/P1, acceptable vitals, Data Safety approved | NOT STARTED |
| PHASE 7 PRODUCTION | Staged rollout and monitoring | Owner GO, rollback/support/on-call ready | NO-GO |

## Official policy references used

- [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-GB_ALL)
- [Google Play Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
- [Google Play account deletion](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN)
- [Google Play background location requirements](https://support.google.com/googleplay/android-developer/answer/9799150?hl=en)
- [Android 16 target behavior changes](https://developer.android.com/about/versions/16/behavior-changes-16)
- [OpenStreetMap tile usage policy](https://operations.osmfoundation.org/policies/tiles/)

## Phase 1 progress/status — 2026-08-04

Исторические выводы аудита выше сохранены. Статус после реализации
`PHASE 1 — FIX BEFORE BLAZE`:

| Finding | Status after Phase 1 |
|---|---|
| P0 Firebase Android identity drift | **FIXED IN CODE**: Dart/FlutterFire metadata теперь используют native registration `tj.tajgo.app` / `1:784873463457:android:0ac2e36af2d8c1a0c91ae0`; regression test сверяет project/package/native/Dart identity. Предсуществующий `google-services.json` не редактировался и не удалял legacy client. |
| P0 courier admin client authority | **FIXED IN SOURCE**: approve/reject/suspend/restore перенесены в callable Functions; actor берётся из auth principal; forbidden role/status fields отвергаются; прямые admin writes закрыты Rules source. Activation ждёт Blaze и owner-approved Functions/Rules deploy. |
| P1 order details infinite loading | **FIXED**: customer/courier screens имеют loading/success/not-found/error/retry/back. |
| P1 FCM subscription leak | **FIXED**: одна UID-bound refresh subscription, cancel при rebind/logout/delete/dispose; background handler сохранён. |
| P1 PII/sensitive logs | **FIXED IN REVIEWED PATHS**: UID/address/coordinates/token/raw Function details удалены; central redaction helper и tests добавлены; Crashlytics пишет safe error code + stack. |
| P0 release debug-signing fallback | **FIXED BY GUARD**: release без owner key завершается явной ошибкой; debug build остаётся доступен. Production keystore всё ещё owner action. |
| P0 legal web surface | **CODE READY / NOT DEPLOYED**: canonical `https://tajgo.ru/{privacy,terms,support,account-deletion}`, public HTML, clean URL hosting config и Play checklist готовы. Hosting deploy, mailbox/legal review и browser verification остаются owner actions. |
| Android/API 36 quick pass | **PASS IN CODE**: package/API 36 сохранены; background/storage/camera permissions отсутствуют; launcher exported; POST_NOTIFICATIONS запрашивается on demand. Physical API 36 smoke остаётся отдельным gate. |

Phase 1 verification: `flutter analyze` PASS; `flutter test` PASS (105);
Functions build/unit PASS (20); Firestore Rules emulator PASS (17); Functions
integration emulator PASS (29); release guard PASS (expected safe failure);
debug APK PASS (`app-debug.apk`, 212,342,786 bytes, SHA-256
`16221798938809EDA15F9B47607D34262AF78AEBD8B435B3A7F12E1E6EA0D0A8`).

Решение остаётся **NO-GO для production**. Причины: Blaze/deploy отсутствуют,
production upload key не создан, public legal URLs ещё не опубликованы/проверены,
MAP phase не выполнена, нет physical API 36 и real Firebase two-phone smoke.
