# TajGo Phase 1 — Fix Before Blaze

Дата: 2026-08-04
Baseline: `main`, `f728210`
Scope: release P0/P1, безопасно исправимые без Blaze, deploy и map redesign.

## Итог

**Phase 1 code gate: PASS. Production: NO-GO.**

Исправлены Firebase identity drift, client-authoritative courier decisions,
вечная загрузка order details, FCM listener leak, sensitive logging и release
debug-signing fallback. Подготовлены canonical legal URLs/pages/checklist и
проверен Android/API 36 manifest surface.

## Firebase identity — до/после

| Поле | До | После |
|---|---|---|
| projectId | `tajgo-4fcd0` | `tajgo-4fcd0` |
| Android package/applicationId | `tj.tajgo.app` | `tj.tajgo.app` |
| Native Android Firebase App ID | `1:784873463457:android:0ac2e36af2d8c1a0c91ae0` | без изменений |
| Dart Android Firebase App ID | `1:784873463457:android:33da27eafa9432a4c91ae0` (`com.example.tajgo`) | `1:784873463457:android:0ac2e36af2d8c1a0c91ae0` |

Изменены только `lib/firebase_options.dart` и Android mapping в `firebase.json`.
`android/app/google-services.json` не редактировался и не будет staged. Старый
native client `com.example.tajgo` не удалялся.

## Исправленные P0/P1

1. **Courier admin authority (P0).** Flutter вызывает
   `adminApproveCourier`, `adminRejectCourier`, `adminSuspendCourier`,
   `adminRestoreCourier`. Backend проверяет auth/admin, состояние перехода,
   idempotency, формирует роли/статусы и audit log из `principal.uid`.
   Client-supplied `role`, `roles`, `status`, `adminUid` не принимаются.
2. **Firestore Rules source (P0).** Прямые admin writes в `users`,
   `courier_applications`, `couriers`, `courier_public` запрещены; Functions
   Admin SDK остаётся authoritative path. Owner draft/pending application flow
   остаётся узко ограниченным Rules и не выдаёт courier/admin capability.
3. **Order details (P1).** Customer/courier UI различает loading, success,
   not-found и error; terminal states имеют retry/back и не показывают spinner.
4. **FCM (P1).** Token refresh привязан к одному active UID; repeated enable
   не создаёт duplicate listener; смена пользователя, logout, delete и dispose
   отменяют подписку. Background messaging handler не изменён.
5. **Logging (P1).** Добавлен `SafeDiagnostics`; raw UID, phone, address,
   coordinates, delivery/token values и raw Functions details не логируются.
   Backend error logs не содержат actor UID или raw error string.
6. **Signing (P0).** Release task без полного ignored signing config падает с
   понятной ошибкой; fallback на debug key удалён. Debug build не блокируется.
7. **Legal URLs (P0 code readiness).** Приложение и документы используют:
   `https://tajgo.ru/privacy`, `/terms`, `/support`, `/account-deletion`.
   Добавлены public HTML, clean URL hosting config и owner browser checklist.
8. **Android/API 36 quick pass (P1).** `tj.tajgo.app`, compile/target 36,
   exported launcher и on-demand notification permission сохранены. Нет
   background location, foreground-service location, storage или camera.

## Основные изменённые файлы

- Firebase/Android: `lib/firebase_options.dart`, `firebase.json`,
  `android/app/build.gradle.kts`, `RELEASE_SIGNING_SETUP.md`.
- Backend authority: `functions/src/{core,domain,index}.ts`,
  `firestore.rules`, Functions unit/integration/rules tests.
- Flutter authority/lifecycle: courier application repository/admin screen,
  account migration service, push notification service, account deletion flow.
- Error states: customer/courier order screens,
  `lib/shared/widgets/order_details_load_state.dart`.
- Diagnostics: `lib/core/services/safe_diagnostics.dart`, auth/startup/functions,
  FCM/Crashlytics/App Check and route diagnostic call sites.
- Legal: `lib/core/legal/legal_documents.dart`, legal/support/deletion screens,
  `public/{privacy,terms,support,account-deletion}.html`, store/support docs,
  `GOOGLE_PLAY_LEGAL_CHECKLIST.md`.
- Regression tests: Firebase identity, Android config, courier callable path,
  order terminal states, FCM lifecycle, redaction and legal URLs.

## Verification

| Gate | Result |
|---|---|
| `flutter analyze` | PASS, 0 issues |
| `flutter test` | PASS, 105 tests |
| Functions `npm.cmd run build` | PASS |
| Functions `npm.cmd test` | PASS, 20 unit tests |
| Firestore Rules emulator | PASS, 17 tests (JDK 21) |
| Functions/Firestore emulator integration | PASS, 29 tests (JDK 21) |
| Release signing validation | PASS: expected exit 1; explicit signing-required error; no fallback/artifact |
| `flutter build apk --debug` | PASS; `build/app/outputs/flutter-apk/app-debug.apk`; 212,342,786 bytes; SHA-256 `16221798938809EDA15F9B47607D34262AF78AEBD8B435B3A7F12E1E6EA0D0A8` |

## Owner action: signing

Выполнить `RELEASE_SIGNING_SETUP.md`: включить Play App Signing, создать upload
keystore вне repo, заполнить ignored `android/key.properties`, сделать backup,
добавить upload и Play app-signing SHA-1/SHA-256 в Firebase Android app
`tj.tajgo.app`, затем собрать/проверить AAB. Секреты не создавались и не
коммитились.

## Что осталось до Blaze / после Blaze

- Подключить Blaze; owner-approved deploy Functions и отдельно Rules/indexes.
- После deploy выполнить real project smoke: startup/profile, admin courier
  actions, orders/status/code, FCM, account deletion и App Check observe-only.
- App Check enforcement не включать до метрик/rollout decision.

## Намеренно отложено

- Вся MAP phase: routing/tile provider, OSM attribution, direct fallback,
  stale/accuracy GPS, map rebuild/performance и visual polish.
- Полный UX/polish, массовые dependency updates и production AAB.
- Hosting deploy, legal/operator/mailbox approval и Play Console mutations.
- Physical API 36/profile-mode/two-phone matrix.

## GO/NO-GO

- **GO**: продолжение локального pre-Blaze work и debug smoke.
- **NO-GO**: production/Play upload до Blaze deploy + real smoke, owner signing,
  опубликованных legal URLs, MAP phase и physical API 36 verification.
