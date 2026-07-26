# TajGo v1.8 Part 1 — Owner Firebase Setup

Production project: `tajgo-4fcd0`. Android package: `tj.tajgo.app`.

## 1. Phone Auth

1. Firebase Console -> Authentication -> Sign-in method -> Phone -> Enable.
2. Добавить только согласованные pilot test numbers и codes.
3. Проверить SHA-1/SHA-256 для debug и release Android app.
4. Проверить SMS quota, billing и список разрешённых регионов.
5. Anonymous оставить только для debug: release-код скрывает fallback через `kDebugMode`.

## 2. Первый owner-admin

1. Войти по телефону в TajGo.
2. Скопировать UID из Authentication.
3. В Firebase Console открыть `users/{uid}`.
4. Установить `role: "admin"`; `roles` не должен публично предлагать admin.
5. Перезапустить приложение и проверить защищённый admin route.

Firebase Console является доверенной owner-процедурой. Не создавайте кнопку `Стать админом`, не храните service-account JSON в репозитории. Custom claim `admin: true` можно добавить позже только доверенным Admin SDK процессом.

## 3. Локальные проверки

```powershell
.\scripts\check_environment.ps1
.\scripts\run_v1_8_core_tests.ps1
```

Если локальная ExecutionPolicy запрещает `.ps1`, используйте `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>`.

Эмуляторы используют `demo-tajgo`, не production:

```powershell
.\scripts\run_firebase_emulators.ps1
```

## 4. Deploy order

Deploy здесь не выполнялся. После отдельного подтверждения владельца:

1. Backup/export критичных production-данных.
2. Deploy indexes и дождаться `Enabled`.
3. Deploy Functions.
4. Установить v1.8 debug на два pilot-телефона.
5. Мигрировать legacy delivery codes через admin order details.
6. Проверить, что `courier_public` содержит только публичные поля из Rules; старые документы с телефоном/приватными полями очистить вручную после backup.
7. Проверить publication flags реального каталога: partner `isTest=false`, `isPreview=false`, `isPublished=true`; product `isTest=false`, `hidden=false`, `isAvailable=true`, `isPublished=true`.
8. Deploy Rules.
9. Пройти customer/courier/admin smoke.

Команды с явным подтверждением:

```powershell
.\scripts\deploy_firestore.ps1 -ProjectId tajgo-4fcd0 -Target indexes -Confirmation 'DEPLOY FIRESTORE INDEXES tajgo-4fcd0'
.\scripts\deploy_functions.ps1 -ProjectId tajgo-4fcd0 -Confirmation 'DEPLOY FUNCTIONS tajgo-4fcd0'
.\scripts\deploy_firestore.ps1 -ProjectId tajgo-4fcd0 -Target rules -Confirmation 'DEPLOY FIRESTORE RULES tajgo-4fcd0'
```

## 5. Два телефона

- Телефон A: новый customer, Phone Auth, custom и catalog orders.
- Телефон B: approved courier, online/GPS, offer/selection/status/code.
- Owner-admin: отдельный подтверждённый телефон/аккаунт.

Проверить слабую сеть, повторный tap, timeout после успешной Functions mutation, kill/restart, stale GPS, 999/1000 м, wrong code, price change и release courier.

## 6. Rollback

1. Не удалять документы.
2. Вернуть предыдущие Rules/Functions из backup commit.
3. Повторно deploy только после owner-confirmation.
4. APK откатить на проверенный build.
5. Новые schema fields совместимы и не требуют удаления.

Нельзя коммитить `key.properties`, `.jks`, `.keystore`, service-account JSON, `.env` или реальные SMS codes.
