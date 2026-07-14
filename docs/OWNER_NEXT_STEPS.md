# TajGo — следующие шаги владельца

## После v1.2.0 Courier Product Completion

1. В Firebase Console убедиться, что Phone provider включён и Android-приложение
   зарегистрировано как `tj.tajgo.app` с актуальными debug SHA-1/SHA-256.
2. Проверить тестовый номер Firebase Auth либо реальный `+992` номер на
   физическом Android-устройстве.
3. До deploy отдельно просмотреть изменения `firestore.rules`: правила заявки,
   admin-решений и courier/public-проекций подготовлены локально, но не разворачивались.
4. Настроить безопасное назначение тестового admin UID и пройти полный сценарий
   `PRODUCT_V1_OWNER_TEST_PLAN.md` на двух физических устройствах.
5. Настроить Firebase Storage и его Rules до приёма реальных документов. Сейчас
   приложение честно использует проверку документов при личной встрече.
6. После успешного field test подготовить release signing и пилотную группу курьеров.

## Уже готово

- v0.7.0 Customer, Courier, Navigation, Admin/Dispatch и debug-only Demo Tools сохранены.
- Android launcher name приведён к `TajGo`.
- Финальный Android package применён: `tj.tajgo.app`.
- Интегрированная версия проекта подготовлена как `1.2.0+27`.
- Реализованы анкета курьера, draft/pending/approved/rejected/suspended,
  admin-модерация и одноразовый onboarding.
- Gradle поддерживает локальный release keystore через `android/key.properties`, не раскрывая секреты.
- Firestore rules закрывают неизвестные коллекции и разделяют customer/courier/admin доступ.
- Индекс customer orders описан в `firestore.indexes.json`.
- Подготовлены инструкции по Firebase, signing и финальным иконкам.

## Ручные действия владельца

### 1. Зарегистрировать финальный package в Firebase

Gradle namespace/applicationId, Kotlin `MainActivity` и Android runtime-ссылки уже переведены на `tj.tajgo.app`. Текущий `google-services.json` относится к старому `com.example.tajgo` и должен быть заменён файлом из Firebase Console.

Смена package создаёт для Android отдельное приложение. Установленная версия `com.example.tajgo` не обновится поверх `tj.tajgo.app`: перед установкой нужно вручную удалить старое приложение либо оставить обе версии как отдельные приложения. Локальные данные старого Android package автоматически не переносятся.

### 2. Firebase Console

Выполнить последовательно по `docs/FIREBASE_PRODUCTION_SETUP.md`:

1. Открыть Firebase Console → Project settings.
2. Add app → Android.
3. Указать package `tj.tajgo.app`.
4. Указать nickname `TajGo Android`.
5. Добавить debug SHA-1/SHA-256.
6. После создания release keystore добавить release SHA-1/SHA-256.
7. Скачать новый `google-services.json`.
8. Заменить `android/app/google-services.json`.
9. Выполнить `flutter clean`, `flutter pub get` и `flutter build apk --debug`.
10. Включить Phone Auth, назначить admin и проверить customer/courier/admin аккаунты.
11. Только после отдельного подтверждения задеплоить rules/indexes.

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
- Перед первой установкой `tj.tajgo.app` удалить старую сборку `com.example.tajgo`, если не требуется сохранять обе версии рядом.

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

- Не возвращать `applicationId` назад из-за ожидаемой ошибки старого `google-services.json`; зарегистрировать `tj.tajgo.app` и заменить конфиг.
- Не выполнять Firebase deploy без ревью и подтверждения владельца.
- Не раздавать debug-signed `app-release.apk` как production.
- Не включать Demo Tools или debug-назначение admin в клиентской сборке.
- Не очищать production Firestore и не тестировать destructive admin actions на реальных заказах.
- Не коммитить ключи, пароли, service-account JSON и персональные данные тестеров.
- Не менять Phone/Anonymous Auth непосредственно перед показом без полного smoke-test.
