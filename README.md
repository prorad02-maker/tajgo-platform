# TajGo

Платформа доставки и каталога партнёров Худжанда на Flutter/Firebase.
Клиент выбирает адреса на карте, назначает цену и выбирает предложение курьера.
Курьер работает с геолокацией и дорожным маршрутом. Администратор управляет
заказами, проверкой курьеров и ассортиментом.

## Локальная проверка

Flutter 3.44.4 / Dart 3.12.2, Android SDK и Java из Android Studio.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Android package — `tj.tajgo.app`; конфигурация Firebase Android/Dart проверяется
регрессионным тестом. Дорожный routing включён по умолчанию. При недоступности
провайдера карта явно отмечает предварительный маршрут.

## Серверные команды заказов

`functions/` содержит callable `orderCommand` (Node.js 22, `europe-west1`).
В обычной сборке создание новых серверных заказов пока выключено до публикации
функции и правил. Заказы с `commandVersion=server-v1` всегда обслуживаются сервером.

```powershell
npm --prefix functions ci
firebase emulators:exec --only auth,functions,firestore --project demo-tajgo-readiness "npm --prefix functions test"
```

Для HTTP-теста callable перед запуском установите
`TAJGO_FUNCTIONS_EMULATOR_URL=http://127.0.0.1:5003/demo-tajgo-readiness/europe-west1/orderCommand`.
Тесты отказываются работать без Firestore Emulator и не используют реальные заказы.
Эмулятору требуется Java 21+. Публикация описана в
[SERVER_ORDER_COMMANDS.md](docs/SERVER_ORDER_COMMANDS.md).

## Настройки сборки

| Параметр | По умолчанию | Назначение |
|---|---|---|
| `TAJGO_SERVER_COMMANDS_ENABLED` | `false` | Создавать новые заказы через сервер после deploy |
| `TAJGO_FUNCTIONS_REGION` | `europe-west1` | Регион callable |
| `TAJGO_CATALOG_PREVIEW_ENABLED` | `false` | Явно включить демонстрационный каталог |
| `TAJGO_SUPPORT_URL` | пусто | HTTPS-ссылка реальной поддержки |
| `TAJGO_PRIVACY_POLICY_URL` | пусто | HTTPS-ссылка утверждённой политики владельца |

Пустые контакты не заменяются вымышленными. В приложении есть справка о заказах
и фактическом использовании данных. Для Google Play нужна официальная политика.
Настройки дорожного сервиса: [ROUTING_PROVIDER_SETUP.md](docs/ROUTING_PROVIDER_SETUP.md).

## Выпуск

Для Google Play требуется существующий ключ подписи и локальный
`android/key.properties`: [ANDROID_RELEASE_SIGNING.md](docs/ANDROID_RELEASE_SIGNING.md).
Без них сборка использует debug-подпись для проверки компиляции.
Ключи и service accounts не добавляются в Git.

Текущие результаты, проверенное состояние рабочего Firebase и ограничения:
[аудит 10 октября 2026](docs/PRODUCTION_READINESS_2026_10_10.md).
