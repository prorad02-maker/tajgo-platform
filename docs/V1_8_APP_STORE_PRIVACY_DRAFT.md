# TajGo v1.8 — App Store Privacy (черновик)

Черновик для App Privacy («Privacy Nutrition Labels») в App Store Connect. Не
юридическое заключение. Основано на `V1_8_PRIVACY_DATA_INVENTORY.md`.

## Data Used to Track You

Нет. TajGo не использует данные для трекинга между приложениями/сайтами и не
передаёт данные брокерам рекламы.

## Data Linked to You

| Data type | Category | Purpose |
|---|---|---|
| Phone Number | Contact Info | App Functionality |
| Name | Contact Info | App Functionality |
| Precise Location | Location | App Functionality (в сессии, доставка) |
| Order/Purchase History | Purchases | App Functionality |
| Product Interaction | Usage Data | App Functionality, Analytics (если включена) |
| Crash Data | Diagnostics | App Functionality (если Crashlytics включён) |
| Device Token (push) | Identifiers | App Functionality (при FCM) |

## Data Not Linked to You

- Обезличенная публичная проекция курьера (без телефона).

## Account Deletion

Поддерживается in-app (Профиль → Безопасность и данные → Удалить аккаунт) и через
web-страницу/поддержку. Указать deletion URL.

## App Review notes (privacy-related)

- Геолокация запрашивается только при активном действии (выбор точки / выход
  курьера на линию), не при старте — строка `NSLocationWhenInUseUsageDescription`
  в `Info.plist`.
- Код получения заказа не раскрывается курьеру.
- Оплата на этапе пилота вне приложения; финансовые данные не собираются.

## Перед подачей (владелец)

- Привести строки к фактическому состоянию флагов (Crashlytics/FCM) в релизной
  сборке.
- Добавить `NSUserTrackingUsageDescription` только если появится трекинг (сейчас
  не требуется).
- Заполнить privacy manifest (`PrivacyInfo.xcprivacy`) для приложения и SDK
  (см. iOS-этап).
