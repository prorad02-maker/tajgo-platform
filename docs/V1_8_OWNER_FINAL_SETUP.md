# TajGo v1.8 — Owner Final Setup

Точные действия владельца для запуска RC. Deploy-команды приведены, но в этой
задаче не выполнялись (no deploy/push/tag). Firebase project: `tajgo-4fcd0`,
регион Functions `europe-west1`, package `tj.tajgo.app`.

## 1. Firebase проект и Auth
1. Проверить активный проект: `firebase use tajgo-4fcd0`.
2. Phone Auth: включить; добавить тестовые номера (Console → Auth → Sign-in →
   Phone → Test numbers).
3. SHA-1 и SHA-256 (debug и release keystore) → Console → Project settings →
   Android app.

## 2. Backend deploy (DEPLOY_REQUIRED)
```
cd functions
npm ci
npm run build
cd ..
firebase deploy --only firestore:indexes
firebase deploy --only functions
firebase deploy --only firestore:rules
```
Порядок важен: indexes → functions → rules. Delivery-code migration (legacy)
выполнить между functions и rules по `V1_8_DELIVERY_CODE_SECURITY.md`.

## 3. Cloud Messaging (FCM)
- Включить Cloud Messaging. iOS: загрузить APNs key (Mac).
- Триггеры `onOrderStatusChanged`, `onOfferCreated` активируются с deploy Functions.

## 4. App Check (не enforcement)
- Зарегистрировать Android (Play Integrity) и iOS (App Attest).
- Debug-токены для тестовых устройств. Enforcement НЕ включать (см.
  `V1_8_APP_CHECK_ROLLOUT.md`).

## 5. Данные
- Назначить admin (Console/Function по документированной процедуре).
- Создать тестового партнёра и товар через админку (Functions).

## 6. Android release
- Создать keystore, `android/key.properties` (см. `V1_8_ANDROID_SIGNING_GUIDE.md`).
- `flutter build appbundle --release` → Play Console internal testing.

## 7. iOS (MAC_REQUIRED)
- См. `V1_8_IOS_MAC_BUILD_GUIDE.md`: bundle id `tj.tajgo.app`,
  `GoogleService-Info.plist`, `flutterfire configure`, Signing & Capabilities,
  APNs, Archive, TestFlight.

## 8. Store
- Privacy URL, Deletion URL (хостинг `public/account-deletion.html`), Support URL.
- Data Safety / App Privacy (черновики в docs).
- Метаданные (RU/TJ), скриншоты, review notes.

## 9. Проверка
- Два телефона (`V1_8_TWO_PHONE_TEST.md`).
- Emulator smoke.
- GO/NO-GO (`V1_8_FINAL_GO_NO_GO.md`).

## Запрещено делать автоматически
Deploy, push, production tag выполняет владелец осознанно. Не коммитить keystore,
key.properties, service-account, GoogleService-Info.plist.
