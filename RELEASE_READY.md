# TajGo — Google Play и tajgo.ru

## Обновление 10 октября 2026: серверная часть входа

Blaze подключён. В `tajgo-4fcd0`, регион `europe-west1`, опубликованы
`ensureUserProfile`, `completeUserProfile`, `acceptLegalDocuments` на Node.js 22.
Все три функции имеют статус ACTIVE и корректно отклоняют запросы без авторизации.
Прошли 80 серверных/эмуляторных и 13 целевых Flutter-тестов. Проверка входа
на реальном телефоне после публикации ожидается. Остальные серверные команды
не опубликованы; готовность доставки этим этапом не подтверждена.
Подробности: [FIREBASE_PROFILE_RELEASE.md](docs/FIREBASE_PROFILE_RELEASE.md).

Ниже сохранён исходный отчёт от 7 октября; последующие изменения сайта описаны
в `docs/WEBSITE_DESIGN_V3.md`.

Проверено 7 октября 2026. Версия **1.8.0+32**, package **tj.tajgo.app**. Цель: загрузка Android AAB в Internal testing и подготовка сайта. Публичный запуск доставки требует закрытия блокеров ниже.

## Фактические проверки

| Проверка | Результат |
|---|---|
| Flutter analyze | PASS, 0 замечаний |
| Flutter tests | PASS, 121 |
| Functions build / unit | PASS, 28 |
| Firestore Rules emulator | PASS, 17 |
| Functions integration emulator | PASS, 32 |
| Debug APK | Собран для локальной установки |
| Сайт: локальные ссылки и ресурсы | PASS, 66 ссылок |
| Release AAB | Не собран: отсутствует android/key.properties |
| Физические телефоны / Play build | Не проверено |
| Production deploy / DNS / HTTPS | Не выполнено |

Всего 198 автоматических тестов. Эмуляторы работали с JDK Android Studio. Backend проверен на Node 24 при настроенном Node 20; совместимость production runtime этим не доказана.

## 1. AAB для Play Console

1. Если приложение уже загружалось, использовать существующий upload key и проверить максимальный versionCode в Console. Следующий номер должен быть больше; доступность номера 32 пока не подтверждена.
2. Для первого приложения создать upload key по `RELEASE_SIGNING_SETUP.md`. Keystore хранить вне репозитория. Заполнить ignored `android/key.properties`; секреты в чат не передавать.
3. Выполнить `./scripts/build_android_release.ps1`. Скрипт останавливается при любой ошибке анализа, тестов или сборки; debug-подпись не подставляется.
4. Загрузить `build/app/outputs/bundle/release/app-release.aab` в Internal testing. Debug APK для загрузки не подходит.
5. Включить Play App Signing и добавить SHA fingerprints upload и Play app-signing сертификатов в Firebase. Проверить Phone Auth и App Check именно на Play-сборке.
6. Добавить тестировщиков. До подключения серверных маршрутов предупредить их, что оформление доставки недоступно.

Официальный порядок: https://support.google.com/googleplay/android-developer/answer/9845334 . Для новых личных аккаунтов перед production требуется closed test с 12 участниками непрерывно 14 дней; проверить применимость в своей Console: https://support.google.com/googleplay/android-developer/answer/14151465 . Это не условие локальной сборки AAB.

## 2. Сайт tajgo.ru

Готовы главная, privacy, terms, support, account-deletion, favicon, OG image, robots и sitemap. Форма удаления открывает почтовое приложение, а не отправляет запрос на сервер. Почта `support@tajgo.ru` должна принимать обращения; отличие домена почты .tj от сайта .ru требует подтверждения владельца.

### Обычный хостинг

```powershell
./scripts/package_website.ps1
```

ZIP появляется в `build/release/`. Распаковать его содержимое в document root, чтобы `index.html` был прямо в корне. Юридические страницы упакованы в `privacy/index.html` и аналогичные папки, поэтому чистые адреса работают на хостинге с directory index. Абсолютные ссылки рассчитаны на корень домена, не подпапку. Перенаправление `/privacy` → `/privacy/` допустимо.

Привязать tajgo.ru в панели хостинга. DNS-записи взять у выбранного хостинга; универсального IP нет. Включить HTTPS и редирект HTTP → HTTPS. www, если используется, перенаправить на основной домен.

### Firebase Hosting

Для Firebase использовать исходную `public/`, не ZIP для обычного хостинга. В `firebase.json` уже включены cleanUrls. После входа владельца:

```powershell
firebase deploy --only hosting --project tajgo-4fcd0
```

В Hosting → Add custom domain добавить tajgo.ru, подтвердить владение и внести предложенные Firebase DNS-записи. Дождаться HTTPS. Эта команда не развёртывает backend.

### Перед публикацией

- Подтвердить оператора (имя/наименование, страна), рабочую почту, сроки хранения и правила обработки данных. Тексты требуют подтверждения владельца.
- Сверить политику с `docs/V1_8_PRIVACY_DATA_INVENTORY.md` и реальным приложением. Проверить путь удаления аккаунта на телефоне.
- Пройти `TAJGO_WEBSITE_RELEASE_CHECKLIST.md` и `GOOGLE_PLAY_LEGAL_CHECKLIST.md`. Визуальная проверка на телефоне, публичные URL и HTTPS пока не подтверждены.
- Кнопку «Скоро в Google Play» заменить только после получения действующей ссылки.

## 3. Карточка Play Console

Сайт: `https://tajgo.ru/`; privacy: `https://tajgo.ru/privacy`; deletion: `https://tajgo.ru/account-deletion`. Support email — после подтверждения.

Материалы: `docs/V1_8_PLAY_DATA_SAFETY_DRAFT.md`, `docs/V1_8_APP_REVIEW_NOTES.md`, `docs/V1_8_SCREENSHOT_PLAN.md`. Data Safety сверить с фактическими SDK, маршрутным провайдером и retention. Возрастной рейтинг определяется анкетой Console, не числом из старого черновика.

Старые RU/TJ тексты обещают еду, магазины и live-tracking. Не копировать их без проверки доступности функций. Для текущей карточки использовать доставку посылок, карту и статусы; скриншоты делать из актуальной сборки.

## 4. Блокеры работающей доставки

1. В `functions/src/index.ts` ядро создаётся без routeResolver; default в `core.ts` возвращает null. Серверный расчёт доставки недоступен. Нужны выбранный велосипедный провайдер для Таджикистана, адаптер, server-only credentials и проверки. Тесты с инъекцией маршрута не снимают этот блокер.
2. Публикация остальных Functions/Rules/indexes и проверка Phone Auth/FCM/Crashlytics/App Check в production. Blaze и три функции входа подключены 10 октября; см. обновление выше.
3. Миграция runtime выполнена 10 октября: Node.js 22 согласован в package.json, lockfile, firebase.json и проверен на Node.js 22.23.3. Этот блокер снят.
4. Пройти `PHASE3A_DEVICE_GATE.md` и two-phone сценарий на Play-сборке. Автотесты не проверяют реальные GPS, SMS и push.

Изменение пользователя в `android/app/google-services.json` сохранено; тест Firebase identity прошёл. До отчёта от 7 октября внешняя инфраструктура не изменялась; последующие публикации указаны выше.
