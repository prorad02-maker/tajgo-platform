# TajGo — blockers по результатам аудита v1.7

Дата: 26 июля 2026  
Фактическая база: `1.5.0+30`, commit `89cbe411` плюс пустой локальный checkpoint `eaf581cb`.

Оценка сложности: `S` — до 1 дня, `M` — 2–4 дня, `L` — 1–2 недели, `XL` — больше двух недель. Это инженерная оценка, не обязательство по срокам.

## A. Блокирует запуск приложения

Автоматическая сборка не заблокирована: analyze, 66 tests, debug и release APK завершились успешно. Для обычного запуска на Android остаётся только непроверенный phone/device setup.

### A1. Реальная Phone Auth конфигурация не проверена

- Severity: `HIGH`
- Доказательство: `AuthService.requestPhoneCode` существует, но физического Android-устройства нет; Firebase Console provider/SHA/reCAPTCHA не проверялись.
- Риск: пользователь не получает SMS либо Android verification завершается ошибкой.
- Минимальный fix: включить Phone Auth, добавить SHA fingerprints, проверить Firebase test number на физическом устройстве.
- Рекомендуемый fix: сценарии new/existing/anonymous-link/resend/timeout на двух устройствах плюс Auth integration checklist.
- Сложность: `M`.
- Файлы: код менять может не потребоваться; `docs/FIREBASE_PRODUCTION_SETUP.md`, Firebase Console.
- Firebase: Console action required, deploy не требуется.

### A2. Release APK подписан debug key

- Severity: `HIGH`
- Доказательство: `android/key.properties` отсутствует; оба APK подписаны `CN=Android Debug`.
- Риск: невозможен безопасный upgrade path и публикация; debug certificate нельзя считать release identity.
- Минимальный fix: локальный release keystore и ignored `key.properties`.
- Рекомендуемый fix: защищённое резервное хранение keystore, CI secret signing, подпись AAB/APK и SHA registration в Firebase.
- Сложность: `S–M`.
- Файлы: `.gitignore`, локальный `android/key.properties`; секреты не коммитить.
- Firebase: добавить release SHA-1/SHA-256.

## B. Блокирует двухтелефонный тест

### B1. Deployed Firestore Rules не установлены и не протестированы

- Severity: `BLOCKER`
- Доказательство: локальные Rules компилируются, semantic emulator tests отсутствуют; deployed Rules version не считывалась. Документация прямо требовала deploy только с подтверждением.
- Риск: законный flow может быть заблокирован либо чужие данные могут быть доступны.
- Минимальный fix: emulator test matrix anonymous/customer/courier/admin/foreign.
- Рекомендуемый fix: CI test suite на каждую разрешённую и запрещённую операцию, затем review и controlled deploy.
- Сложность: `L`.
- Файлы: `firestore.rules`, новый rules test package, возможно `firebase.json`.
- Firebase: после подтверждения `firebase deploy --only firestore:rules`.

### B2. Второй local composite index отсутствует в deployed project

- Severity: `HIGH`
- Доказательство: local indexes содержат customer+createdAt и status+createdAt; Firebase CLI вернул только первый deployed index.
- Риск: конкретный order query может упасть с `failed-precondition`.
- Минимальный fix: проверить фактические queries на emulator/project и deploy только нужные indexes.
- Рекомендуемый fix: integration smoke всех списков orders/partners/products с production-like dataset.
- Сложность: `S–M`.
- Файлы: `firestore.indexes.json`.
- Firebase: `firebase deploy --only firestore:indexes` после подтверждения.

### B3. Admin flow не достижим

- Severity: `BLOCKER`
- Доказательство: `AdminHomeScreen`, admin screens и `DemoToolsScreen` не имеют import route от `lib/main.dart`.
- Риск: невозможно разрешить dispute, разблокировать courier или управлять каталогом с APK.
- Минимальный fix: защищённый admin destination после server role check.
- Рекомендуемый fix: отдельная admin navigation boundary, re-auth для опасных действий и полный authorization/E2E test.
- Сложность: `M–L`.
- Файлы: startup/router/profile navigation и admin screens; точный список после design review.
- Firebase: создать owner admin вручную; Rules tests/deploy.

### B4. Нет подтверждённого физического E2E

- Severity: `BLOCKER`
- Доказательство: `flutter devices` не показал Android; GPS, SMS, concurrent streams и external apps не запускались.
- Риск: permission, lifecycle, OEM battery, network и race проблемы проявятся только на устройствах.
- Минимальный fix: два Android-телефона, customer/courier accounts, один полный order.
- Рекомендуемый fix: повторяемая field-test матрица online/offline/restart/background/weak network.
- Сложность: `M`.
- Файлы: вначале не требуются.
- Firebase: test accounts/data, после безопасного Rules deploy.

## C. Блокирует закрытый пилот

### C1. Радиус `< 1000 м` можно обойти

- Severity: `BLOCKER`
- Доказательство: `CourierOrderEligibilityService` вычисляет `<1000`, age≤15s и accuracy≤50m только в Dart; Rules это не пересчитывают.
- Риск: modified client принимает любой заказ и подставляет location/distance.
- Минимальный fix: callable/transactional backend с server-side distance по доверенной server timestamp location.
- Рекомендуемый fix: backend accept/offer API, App Check, replay/idempotency protection, telemetry validation и audit event.
- Сложность: `L`.
- Файлы: новый `functions/`, client repository adapter, Rules/tests.
- Firebase: Functions setup/deploy, Rules deploy, App Check configuration.

### C2. Delivery code не является секретом и не проверяется сервером

- Severity: `BLOCKER`
- Доказательство: `confirmationCode` хранится в читаемом assigned courier order; Rules completion не сравнивает submitted code.
- Риск: courier завершает заказ без передачи клиенту.
- Минимальный fix: хранить salted hash вне courier-readable projection и проверять callable function.
- Рекомендуемый fix: one-time challenge, attempt/rate limits, expiration, audit logs и recovery через admin.
- Сложность: `M–L`.
- Файлы: order model/repositories/screens, Rules, новый Functions code/tests.
- Firebase: Functions + Rules deploy.

### C3. Критические транзакции доверены клиенту

- Severity: `BLOCKER`
- Доказательство: `OrderRepository`, `CourierOfferRepository`, `CourierRepository`, `MarketplaceRepository` пишут Firestore напрямую; `functions/` отсутствует.
- Риск: modified client меняет цену, статус, courier assignment и статистику в пределах пробелов Rules.
- Минимальный fix: перенести accept/select/complete/catalog checkout в callable Functions.
- Рекомендуемый fix: единый authoritative command layer с schema validation, idempotency keys, server timestamps и structured safe errors.
- Сложность: `XL`.
- Файлы: новый backend, repositories/API DTO, Rules, tests.
- Firebase: Functions initialization/deploy, possibly App Check enforcement.

### C4. Marketplace totals/items не authoritative

- Severity: `BLOCKER`
- Доказательство: checkout перечитывает products на клиенте; Rules сверяют totals между полями, но не каждую item с product document.
- Риск: forged basket, price и unavailable product попадают в order.
- Минимальный fix: server-side checkout с product reads и authoritative total.
- Рекомендуемый fix: availability/stock version, immutable order snapshot, idempotency and audit.
- Сложность: `L`.
- Файлы: `MarketplaceRepository`, checkout UI error mapping, Functions, Rules/tests.
- Firebase: Functions + Rules deploy.

### C5. Dispute может навсегда оставить courier busy

- Severity: `CRITICAL`
- Доказательство: customer disputed transition не очищает active order; admin UI недостижим.
- Риск: courier больше не получает orders.
- Минимальный fix: доступный admin resolution и согласованная transaction.
- Рекомендуемый fix: explicit dispute state machine, SLA/queue, atomic resolve outcomes и reconciliation job.
- Сложность: `M–L`.
- Файлы: admin route/repository, courier/order repositories, Rules/backend.
- Firebase: backend and Rules deploy.

### C6. Нет idempotency для create/offer/checkout

- Severity: `HIGH`
- Доказательство: random document id на новую попытку, UI busy guard только локален, operation ID отсутствует.
- Риск: duplicate order/offer/charge-equivalent после timeout и retry.
- Минимальный fix: stable client request id persisted before write.
- Рекомендуемый fix: backend idempotency table/document and deterministic transaction result.
- Сложность: `M–L`.
- Файлы: repositories/models/local persistence/backend.
- Firebase: new command documents/indexes/functions.

### C7. FCM отсутствует

- Severity: `HIGH`
- Доказательство: нет dependency, token flow, Android permission, handlers и sender.
- Риск: courier/customer пропускают offer/status при background/closed app.
- Минимальный fix: foreground/background FCM for offer selected and status events.
- Рекомендуемый fix: privacy-safe payload, token rotation, topic avoidance for private orders, retries/observability.
- Сложность: `L`.
- Файлы: pubspec, Android manifest, notification service, backend.
- Firebase: Messaging/Functions configuration and deploy.

### C8. Data migration не подготовлена

- Severity: `HIGH`
- Доказательство: fallbacks есть, но нет inventory/dry-run для existing orders/offers/catalog; unknown status становится waiting.
- Риск: старый или повреждённый order появляется как новый и участвует в offer flow.
- Минимальный fix: read-only inventory/report и quarantine unknown states.
- Рекомендуемый fix: versioned, repeatable migration with backup, dry-run, metrics and rollback.
- Сложность: `M–L`.
- Файлы: migration tool/script and schema docs.
- Firebase: read/export, controlled admin execution.

## D. Блокирует production

### D1. Firebase App Check отсутствует

- Severity: `CRITICAL`
- Доказательство: dependency/init/config/enforcement отсутствуют.
- Риск: scripts и modified clients напрямую вызывают Firebase API.
- Минимальный fix: Android App Check in monitoring mode.
- Рекомендуемый fix: Play Integrity, metrics review, enforcement after legitimate clients updated.
- Сложность: `M`.
- Firebase: Console App Check and enforcement rollout.

### D2. Production routing отсутствует

- Severity: `HIGH`
- Доказательство: default release routing disabled; pilot config использует public OSM endpoint без SLA и `driving` profile для bicycle mode.
- Риск: неверные ETA/routes, rate-limit, unavailable service.
- Минимальный fix: явно решить, что production v1.8 использует direct route.
- Рекомендуемый fix: controlled routing provider/own service, correct profiles, quotas, privacy, monitoring and fallback.
- Сложность: `L–XL`.
- Файлы: routing config/provider/docs/build pipeline.
- External action: provider/hosting setup.

### D3. Нет observability

- Severity: `HIGH`
- Доказательство: Crashlytics, Analytics и backend metrics отсутствуют.
- Риск: failures, fraud и stuck orders неизвестны владельцу.
- Минимальный fix: privacy-reviewed crash reporting and structured backend logs.
- Рекомендуемый fix: dashboards/alerts for auth, order latency, stuck state, function error, notification delivery.
- Сложность: `L`.
- Firebase: Crashlytics/Analytics/Functions logging.

### D4. Secret files не полностью игнорируются

- Severity: `HIGH`
- Доказательство: `.gitignore` не содержит `*.jks`, `*.keystore`, `android/key.properties`, service account/env patterns.
- Риск: случайный commit release key или privileged credential.
- Минимальный fix: добавить ignore patterns до генерации секретов.
- Рекомендуемый fix: secret scanning/pre-commit/CI, documented rotation.
- Сложность: `S`.
- Файлы: `.gitignore`, security docs.
- Firebase: не требуется.

### D5. Raw Firebase errors могут попадать в UI

- Severity: `MEDIUM`
- Доказательство: несколько customer/courier/admin widgets выводят `$error` или `snapshot.error`.
- Риск: technical details, confusing UX, возможная утечка internal paths/codes.
- Минимальный fix: centralized error mapper.
- Рекомендуемый fix: safe user messages + correlation ID + private structured logs.
- Сложность: `M`.
- Файлы: shared error service and affected screens.

### D6. Нет production release process/AAB

- Severity: `HIGH`
- Доказательство: AAB отсутствует; release APK debug-signed; tags отстают от source version.
- Риск: неподтверждённый artifact, невозможность воспроизведения/rollback.
- Минимальный fix: release signing and version/tag discipline.
- Рекомендуемый fix: reproducible CI pipeline, SBOM/checksums, signed AAB, staged rollout and rollback runbook.
- Сложность: `M–L`.

## E. Не блокирует ограниченный пилот после P0, но нужно для v1.8

### E1. Complete boundary tests радиуса неполные

- Severity: `MEDIUM`
- Доказательство: не все значения 0/500/998/999.99/1500 покрыты.
- Fix: parameterized unit + backend tests.
- Сложность: `S`.

### E2. `pickedUpAt`/`deliveredAt` не записываются

- Severity: `MEDIUM`
- Риск: неполная аналитика/SLA timeline.
- Fix: authoritative transition writes server timestamps.
- Сложность: `S–M`.

### E3. Marketplace error скрывается preview fallback

- Severity: `MEDIUM`
- Риск: permission/network issue маскируется demo-каталогом.
- Fix: fallback только при доказанно пустой тестовой базе; отдельный error state.
- Сложность: `S–M`.

### E4. SharedPreferences role cache не читается

- Severity: `MEDIUM`
- Риск: неопределённый offline startup.
- Fix: формализовать Firestore-only или versioned local cache reconciliation.
- Сложность: `M`.

### E5. Admin operations имеют consistency bugs

- Severity: `HIGH`
- Доказательство: current waitingOffers не входит в cancel allowlist; completed→disputed→complete может удвоить stats; clearActive не синхронизирует order.
- Fix: единая backend admin transition machine и tests.
- Сложность: `M–L`.

### E6. Status compatibility скрывает corruption

- Severity: `HIGH`
- Доказательство: unknown status → waiting.
- Fix: unknown/quarantined state plus telemetry/migration.
- Сложность: `M`.

## F. Можно оставить после v1.8

### F1. Storage для изображений

- Severity: `LOW`
- Сейчас images — URL. Допустимо для curated pilot catalog при HTTPS allowlist.
- Позже: Storage upload, transforms, moderation and lifecycle.

### F2. Полноценный turn-by-turn

- Severity: `LOW` для доставки MVP.
- Direct/road line, ETA и external navigation достаточны после production provider decision.

### F3. Расширенная аналитика продукта

- Severity: `LOW` после минимальной operational observability.
- Сначала нужны crash/function/stuck-order metrics, затем product funnels.

### F4. Очистка недостижимых helpers/widgets

- Severity: `LOW`.
- Выполнять после восстановления/удаления admin route, чтобы не удалить нужный код по ошибке.
