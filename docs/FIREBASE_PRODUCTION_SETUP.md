# Firebase production setup для TajGo

Текущий Android `applicationId` и Firebase package: `com.example.tajgo`. Предпочтительный финальный идентификатор — `tj.tajgo.app`, альтернативы — `app.tajgo.delivery` и `tj.tajgo.delivery`. Не менять package в коде до отдельного решения владельца и регистрации соответствующего Android app в Firebase.

## 1. Authentication

1. Firebase Console → Authentication → Sign-in method → включить **Phone**.
2. Для безопасной проверки добавить отдельные тестовые номера и коды; реальные SMS расходуют квоту.
3. Проверить ограничения SMS, Play Integrity/reCAPTCHA и регионы доставки SMS.
4. Решить судьбу Anonymous fallback:
   - оставить на закрытом демо — проще восстановить существующий flow при проблеме с SMS, но появляются анонимные аккаунты и сложнее ownership/поддержка;
   - отключить перед production — понятнее идентичность и аудит, но сначала надо проверить миграцию/линковку текущих anonymous пользователей.
5. Не выключать Anonymous Auth внезапно, пока на нём есть тестовые данные и не пройден полный customer/courier сценарий.

## 2. Android app и fingerprints

1. Зафиксировать финальный `applicationId` владельцем.
2. В Firebase Project Settings зарегистрировать Android app с точно таким же package. Для нового package это новая Android-регистрация, а не простое переименование старой.
3. Получить debug SHA-1/SHA-256:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

4. Создать release keystore по `docs/ANDROID_RELEASE_SIGNING.md` и получить release SHA-1/SHA-256:

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android-keys\tajgo-release-key.jks" -alias tajgo
```

5. Добавить debug и release fingerprints в выбранный Firebase Android app.
6. Скачать новый `google-services.json` именно для выбранного package и проекта.
7. Заменить `android/app/google-services.json` и проверить, что `client.client_info.android_client_info.package_name` равен Gradle `applicationId`.
8. Если package изменён, синхронно обновить `namespace`, package/path `MainActivity.kt` и значения `userAgentPackageName` в коде. `firebase_options.dart` менять только осознанной повторной конфигурацией того же Firebase-проекта.

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
