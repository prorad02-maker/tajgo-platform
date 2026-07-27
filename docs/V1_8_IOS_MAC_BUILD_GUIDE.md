# TajGo v1.8 — iOS Build Guide (MAC_REQUIRED)

Статус: iOS-проект приведён к TajGo identity в коде; сборка/подпись/публикация —
**MAC_REQUIRED** (нужны macOS, Xcode, Apple Developer account). На Windows IPA
собрать нельзя — выполнена только статическая подготовка.

## Что уже сделано в репозитории

- Bundle ID переименован `com.example.tajgo` → **`tj.tajgo.app`** во всех
  конфигурациях `ios/Runner.xcodeproj/project.pbxproj` (и `.RunnerTests`).
- `Info.plist`: `CFBundleDisplayName = TajGo`; `NSLocationWhenInUseUsageDescription`;
  `LSApplicationQueriesSchemes` (yandexnavi, comgooglemaps, dgis) для внешних
  навигаторов; `UIBackgroundModes = remote-notification` для FCM.
- `ios/Runner/PrivacyInfo.xcprivacy` — privacy manifest (phone/name/precise
  location, required-reason API: UserDefaults, FileTimestamp, SystemBootTime,
  DiskSpace).
- `firebase_options.dart`: `iosBundleId` = `tj.tajgo.app`.
- Внешние навигаторы: `geo:`-fallback теперь под platform-guard (не вызывается на
  iOS, где схема не поддерживается).

## Шаги владельца на Mac

1. Установить актуальный Flutter, Xcode 26+, CocoaPods.
2. Зарегистрировать iOS-приложение в Firebase Console с bundle id
   `tj.tajgo.app`, скачать `GoogleService-Info.plist` в
   `ios/Runner/GoogleService-Info.plist` (НЕ коммитить). Затем выполнить
   `flutterfire configure` — он регенерирует `lib/firebase_options.dart` с
   корректными iOS `apiKey`/`appId` (сейчас там обновлён только `iosBundleId`,
   остальные iOS-поля — от старого placeholder-приложения).
3. `cd ios && pod install`.
4. Xcode → Runner → Signing & Capabilities: выбрать Team, проверить bundle id
   `tj.tajgo.app`, включить capability **Push Notifications** и
   **Background Modes → Remote notifications**.
5. APNs: загрузить APNs Auth Key в Firebase Console (Cloud Messaging → iOS).
6. Сборка на физическом iPhone: `flutter build ios --release` → Xcode Archive.
7. TestFlight → внутренние тестировщики.
8. App Store review: приложить reviewer notes (тестовый номер, роли, admin —
   см. `V1_8_APP_REVIEW_NOTES.md`).

## Проверка перед сборкой

- Убедиться, что privacy manifests сторонних SDK (Firebase, geolocator и т.д.)
  присутствуют — свежие версии их поставляют; при отсутствии App Store review
  предупредит.
- Проверить third-party privacy manifests: Xcode → отчёт при архивации.
- Минимальная версия iOS — по умолчанию Flutter (обычно iOS 13+); при
  необходимости поднять в Podfile.

## Ограничение

Windows-среда: IPA-сборка не выполнялась и не может быть выполнена. Статически
подготовлено всё, что не требует Mac.
