# Firebase production setup для TajGo

## Перед реальными пользователями

1. Firebase Authentication → Sign-in method → включить Phone.
2. Добавить SHA-1 и SHA-256 production/debug keystore в Android app Firebase.
3. Скачать актуальный `google-services.json` только из выбранного production-проекта.
4. Проверить SMS-квоты, тестовые номера и Play Integrity/reCAPTCHA.
5. Решить, оставлять ли Anonymous Auth fallback. Для production рекомендуется убрать fallback из UX после миграции тестовых аккаунтов.
6. Вручную установить владельцу `users/{uid}.role = "admin"`.

## Firestore

После ревью и отдельного подтверждения владельца:

```powershell
firebase.cmd deploy --only firestore:rules
firebase.cmd deploy --only firestore:indexes
```

Текущие Rules добавляют:

- ownership для users/orders/couriers;
- роль admin для диспетчерских чтений и транзакций;
- append-only `admin_logs`;
- запрет update/delete журналов;
- публичную GPS-проекцию `courier_public` без телефона и заработка.

Составной индекс `orders(customerId ASC, createdAt DESC)` уже описан в `firestore.indexes.json`. Остальные RC-запросы используют single-field индексы.

## Нельзя делать в production

- Не оставлять debug APK и Demo Tools на устройствах клиентов.
- Не назначать `role=admin` из клиентского приложения.
- Не открывать коллекции wildcard-правилом `auth != null`.
- Не хранить phoneNumber/earnings в `courier_public`.
- Не выполнять admin-действия без записи `admin_logs`.
- Не заменять `firebase_options.dart` или `google-services.json` файлами от другого проекта.
- Не включать background GPS без отдельного UX, политики конфиденциальности и Android-разрешений.
