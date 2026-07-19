# Firebase production setup для TajGo

Финальный Android `applicationId` и namespace подтверждены владельцем: `tj.tajgo.app`.

Текущий `android/app/google-services.json` содержит Android client для `tj.tajgo.app` (Firebase app id `1:784873463457:android:0ac2e36af2d8c1a0c91ae0`) и совместимый legacy-client `com.example.tajgo`. Локальный `firebase.json` также указывает на новый client. При повторном скачивании конфигурации из Firebase Console обязательно сохранить client `tj.tajgo.app` и проверить fingerprints.

## 1. Authentication

1. Firebase Console → Authentication → Sign-in method → включить **Phone**.
2. Для безопасной проверки добавить отдельные тестовые номера и коды; реальные SMS расходуют квоту.
3. Проверить ограничения SMS, Play Integrity/reCAPTCHA и регионы доставки SMS.
4. Решить судьбу Anonymous fallback:
   - оставить на закрытом демо — проще восстановить существующий flow при проблеме с SMS, но появляются анонимные аккаунты и сложнее ownership/поддержка;
   - отключить перед production — понятнее идентичность и аудит, но сначала надо проверить миграцию/линковку текущих anonymous пользователей.
5. Не выключать Anonymous Auth внезапно, пока на нём есть тестовые данные и не пройден полный customer/courier сценарий.

## 2. Android app и fingerprints

1. Открыть **Firebase Console → Project settings** текущего проекта TajGo.
2. Нажать **Add app → Android**.
3. В поле **Android package name** указать точно `tj.tajgo.app`.
4. В поле **App nickname** указать `TajGo Android`.
5. Получить и добавить debug SHA-1/SHA-256:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

6. Зарегистрировать приложение и скачать предложенный `google-services.json`.
7. Создать release keystore по `docs/ANDROID_RELEASE_SIGNING.md`, получить release SHA-1/SHA-256 и позже добавить оба fingerprint в настройки этого же Android app:

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android-keys\tajgo-release-key.jks" -alias tajgo
```

8. Заменить файл `android/app/google-services.json` новым скачанным файлом.
9. Проверить, что в новом JSON `client.client_info.android_client_info.package_name` равен `tj.tajgo.app`.
10. Выполнить чистую сборку:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Не редактировать старый `google-services.json` вручную: простая замена строки package не создаёт Firebase Android app и не добавляет корректный OAuth client. `firebase_options.dart` не требуется менять, пока используется тот же Firebase-проект и добавляется только новая Android-регистрация; при повторном запуске FlutterFire CLI изменения этого файла надо отдельно проверить.

## 3. Пользователи и роли

1. Войти отдельными customer, courier и owner/admin аккаунтами по телефону.
2. Найти UID владельца в Authentication.
3. В Firestore Console открыть `users/{uid}` и вручную установить строковое поле `role = "admin"`.
4. Не назначать admin из клиентского UI и не оставлять debug-механизм повышения роли в production.
5. Проверить, что customer видит только свои заказы, courier — waiting и назначенный заказ, admin — диспетчерские экраны.

## 4. Firestore rules и indexes

Текущий `firestore.rules` предусматривает:

- owner-only доступ к `users` и приватному `couriers`, плюс доступ admin;
- customer create/read только собственных заказов;
- courier read waiting-заказов и собственных назначенных заказов;
- разрешённые переходы статусов без изменения цены/маршрута;
- безопасную публичную GPS-проекцию `courier_public` без телефона, activeOrderId и заработка;
- admin-доступ через `users/{uid}.role == "admin"`;
- append-only `admin_logs` для admin;
- авторизованное чтение витрины `partners`/`products`, а изменение — только admin;
- создание `catalogOrder` только владельцем заказа, с неизменяемым snapshot товаров и фиксированной стоимостью доставки;
- deny-all для неизвестных коллекций.

Составной индекс `orders(customerId ASC, createdAt DESC)` уже описан в `firestore.indexes.json`. Он нужен клиентскому списку заказов; дополнительные составные индексы текущим RC-запросам не требуются.

После ревью и отдельного подтверждения владельца:

```powershell
firebase.cmd deploy --only firestore:rules
firebase.cmd deploy --only firestore:indexes
```

До подтверждения deploy не выполнять.

## 5. Финальная проверка

1. Customer создаёт и читает свой заказ, но не чужой.
2. Courier видит waiting, принимает один заказ и обновляет GPS.
3. Customer назначенного заказа читает только публичный маркер курьера.
4. Courier не читает чужой активный заказ.
5. Admin открывает Orders/Couriers/Dispatch и действие создаёт `admin_logs`.
6. Неавторизованный запрос и неизвестная коллекция получают permission denied.
7. Phone Auth работает на APK, подписанном тем ключом, чей SHA добавлен в Firebase.

## Нельзя делать в production

- Не раздавать debug APK и не включать Demo Tools в release.
- Не коммитить keystore, `key.properties`, пароли или service-account JSON.
- Не назначать `role=admin` из клиентского приложения.
- Не открывать коллекции wildcard-правилом `auth != null`.
- Не хранить `phoneNumber`, `activeOrderId` или earnings в `courier_public`.
- Не заменять Firebase-конфиги файлами другого проекта.
- Не включать background GPS без отдельного UX, политики конфиденциальности и Android-разрешений.
