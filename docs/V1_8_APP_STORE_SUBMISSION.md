# TajGo v1.8 — App Store Submission Checklist (MAC_REQUIRED)

## Предусловия (owner, Mac)
- Apple Developer account, App Store Connect app (bundle id `tj.tajgo.app`).
- Xcode archive + TestFlight (см. `V1_8_IOS_MAC_BUILD_GUIDE.md`).
- `GoogleService-Info.plist` + `flutterfire configure` для iOS.

## Шаги
1. **App Information**: имя TajGo, категория, RU/TJ локализации.
2. **App Privacy**: заполнить по `V1_8_APP_STORE_PRIVACY_DRAFT.md`; включить
   Account Deletion (URL + in-app). Data Used to Track You — нет.
3. **Privacy manifest**: `ios/Runner/PrivacyInfo.xcprivacy` уже в проекте;
   проверить, что third-party SDK (Firebase, geolocator) поставляют свои.
4. **Capabilities**: Push Notifications, Background Modes → Remote notifications.
5. **Screenshots**: 6.7"/6.5" по `V1_8_SCREENSHOT_PLAN.md`.
6. **Build**: Archive → загрузить в App Store Connect → TestFlight.
7. **App Review**: приложить `V1_8_APP_REVIEW_NOTES.md` (тестовые номера, роли,
   объяснение admin-доступа).

## Технические (в коде готово)
- bundle id `tj.tajgo.app`, display name TajGo.
- Info.plist: location usage string, LSApplicationQueriesSchemes (навигаторы),
  UIBackgroundModes remote-notification.
- Внешние навигаторы: iOS-безопасные схемы (comgooglemaps, Apple Maps fallback).

## Блокеры
- MAC_REQUIRED (сборка/архив/подпись).
- Apple Developer account, APNs key, iOS Firebase app.
- DEPLOY_REQUIRED (backend).
