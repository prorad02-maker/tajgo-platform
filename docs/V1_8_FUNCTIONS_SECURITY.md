# TajGo v1.8 Part 1 — Cloud Functions Security

## Callable Functions

Основной контракт:

- `createCustomDeliveryOrder`
- `submitCourierOffer`
- `updateCourierOffer`
- `withdrawCourierOffer`
- `selectCourierOffer`
- `cancelWaitingOrder`
- `updateDeliveryStatus`
- `completeDeliveryWithCode`
- `createCatalogOrder`
- `cancelCatalogOrder`
- `adminCancelOrder`
- `adminReleaseCourier`
- `adminResolveDispute`

Служебные безопасные команды:

- `ensureUserProfile`
- `completeUserProfile`
- `switchAccountMode`
- `completeCourierOnboarding`
- `ensureCourierProfile`
- `rejectCourierOffer`
- `resetTestOrderForCourier` — только `isTestOrder == true`
- `adminSetOrderNote`
- `adminMigrateLegacyDeliveryCode`

## Общие гарантии

Каждая критическая команда проверяет Firebase Auth, server role, ownership, входные данные, текущий статус и idempotency key. Mutation выполняется транзакцией и использует `FieldValue.serverTimestamp()`.

Разрешённые безопасные Https-коды: `unauthenticated`, `permission-denied`, `invalid-argument`, `failed-precondition`, `already-exists`, `not-found`, `aborted`; лимит кода также использует `resource-exhausted`.

Не возвращаются stack trace, внутренний Firestore path, секреты, полный телефон или delivery code. Неожиданная ошибка логируется только с названием команды и actor UID, а клиент получает общий `aborted`.

## Гео-проверки

- Offer/selection: `distanceMeters < 1000`.
- GPS не старше 30 секунд.
- Accuracy не хуже 50 м.
- Курьер online, не busy, без `activeOrderId`.
- Status-actions используют server-side радиус 2 км.

Клиентские `distanceKm` и `etaMinutes` не участвуют в решении о доступе.

## Runtime

- TypeScript, Node.js 20, region `europe-west1`.
- `maxInstances: 20`, `timeoutSeconds: 30`, `memory: 256MiB`.
- App Check пока не enforced: сначала нужны регистрация приложений и staged rollout. Это остаётся production-hardening задачей.

## Dependency note

Runtime-зависимости отделены от dev tooling. Финальный `npm audit --omit=dev` сообщает 8 moderate transitives в Firebase Admin 13 (`uuid`/Google Cloud chain), без high/critical. Автоматический fix требует Firebase Admin 14, который пока не входит в peer-range стабильного Firebase Functions 7.2.2. `--force` не применялся: обновление нужно сделать после выхода совместимой стабильной пары и полного повторного тестирования.
