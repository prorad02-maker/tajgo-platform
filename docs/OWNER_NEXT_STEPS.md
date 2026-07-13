# TajGo v0.8.0 — следующие шаги владельца

## Уже готово

- v0.7.0 Customer, Courier, Navigation, Admin/Dispatch и debug-only Demo Tools сохранены.
- Android launcher name приведён к `TajGo`.
- Версия проекта подготовлена как `0.8.0+8`.
- Gradle поддерживает локальный release keystore через `android/key.properties`, не раскрывая секреты.
- Firestore rules закрывают неизвестные коллекции и разделяют customer/courier/admin доступ.
- Индекс customer orders описан в `firestore.indexes.json`.
- Подготовлены инструкции по Firebase, signing и финальным иконкам.

## Решения, которые должен подтвердить владелец

### 1. Финальный package

Рекомендуемый: `tj.tajgo.app`.

Альтернативы: `app.tajgo.delivery`, `tj.tajgo.delivery`.

Сейчас используется `com.example.tajgo`; он не подходит как финальная identity. При подтверждённой смене затрагиваются:

- `android/app/build.gradle.kts` (`applicationId`, `namespace`);
- package и путь `android/app/src/main/kotlin/.../MainActivity.kt`;
- `android/app/google-services.json`;
- Android app registration и SHA fingerprints в Firebase;
- `userAgentPackageName` в map-экранах;
- при необходимости Firebase-конфигурация других платформ.

`AndroidManifest.xml` и текущая конфигурация `flutter_launcher_icons` от package напрямую не зависят, но их надо перепроверить после сборки. Смена package создаёт для Android отдельное приложение: установленная версия `com.example.tajgo` не обновится поверх `tj.tajgo.app`, а Firebase Phone Auth не заработает без новой регистрации/config.

### 2. Firebase Console

Выполнить последовательно по `docs/FIREBASE_PRODUCTION_SETUP.md`:

1. Включить Phone Auth и тестовые номера.
2. Решить, когда отключать Anonymous fallback.
3. Зарегистрировать подтверждённый package.
4. Добавить debug/release SHA-1 и SHA-256.
5. Скачать подходящий `google-services.json`.
6. Назначить владельцу `users/{uid}.role = "admin"`.
7. Проверить отдельные customer/courier/admin аккаунты.
8. Только после подтверждения задеплоить rules/indexes.

## Как получить настоящий release APK

1. Создать и сохранить keystore вне репозитория по `docs/ANDROID_RELEASE_SIGNING.md`.
2. Создать локальный `android/key.properties`.
3. Убедиться, что его нет в `git status`.
4. Выполнить:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

5. Проверить сертификат через `apksigner` и установить APK на чистое тестовое устройство.

Готовый файл: `build/app/outputs/flutter-apk/app-release.apk`.

## Как передать APK закрытому тестеру

- Для технического smoke-test можно передать явно помеченный debug APK по защищённому каналу.
- Для клиента передавать только APK с финальным package и release-подписью.
- Перед передачей записать version/build, SHA-256 файла, дату, Firebase-проект и список известных ограничений.
- Не отправлять вместе с APK keystore, `key.properties`, Firebase service-account или пароли.
- Попросить тестера удалить старую сборку, если менялся package/подпись и Android не может установить обновление поверх неё.

## Как назначить admin

1. Пользователь входит по телефону.
2. В Firebase Authentication скопировать его UID.
3. В Firestore Console открыть `users/{uid}`.
4. Установить `role` строкой `admin`.
5. Перезапустить приложение и проверить Admin/Dispatch.

## Как откатиться к v0.7.0

Тег `v0.7.0` уже существует. Безопаснее не сбрасывать текущую ветку, а создать отдельную:

```powershell
git switch -c codex/rollback-v0.7.0 v0.7.0
```

Либо собрать тег в отдельном worktree:

```powershell
git worktree add ..\tajgo-v0.7.0 v0.7.0
```

## Нельзя делать перед показом

- Не менять `applicationId` частично: Gradle, Kotlin package и Firebase config должны совпасть.
- Не выполнять Firebase deploy без ревью и подтверждения владельца.
- Не раздавать debug-signed `app-release.apk` как production.
- Не включать Demo Tools или debug-назначение admin в клиентской сборке.
- Не очищать production Firestore и не тестировать destructive admin actions на реальных заказах.
- Не коммитить ключи, пароли, service-account JSON и персональные данные тестеров.
- Не менять Phone/Anonymous Auth непосредственно перед показом без полного smoke-test.
