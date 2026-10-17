# TajGo v1.8 Part 1 — Firestore Rules

`firestore.rules` использует deny-by-default.

## Матрица доступа

| Resource | Customer | Approved courier | Admin |
|---|---|---|---|
| own user | read, safe profile update | read own | required admin reads |
| orders | own only | waiting non-test and assigned | read all |
| order writes | Functions only | Functions only | Functions only |
| offers | offers own orders | own offer | read all |
| offer writes | Functions only | Functions only | Functions only |
| couriers | — | own private read, safe presence write | read/manage |
| courier_public | authenticated safe shape | own presence write | read/manage |
| customer code | order owner only | denied | read |
| secret/idempotency | denied | denied | denied |
| catalog | published non-test only | published non-test only | manage |
| admin_logs | denied | denied | read/create |

Роль проверяется по `users/{uid}` либо admin custom claim. Пользователь не может изменить `role`, `roles` или courier approval безопасным profile-update.

Прямые create/update/delete orders и offers запрещены даже admin mobile-клиенту: admin mutations идут через Functions.

Legacy order с `confirmationCode` не виден курьеру, пока admin не выполнит защищённую миграцию.

## Проверка

`functions/test/rules/firestore.rules.test.ts` проверяет allow и deny для anonymous/customer/courier/admin, чужих ресурсов, direct critical writes, delivery code, preview/inactive catalog, hidden products, admin logs и неизвестных коллекций.

Локальный запуск:

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
cd functions
npm run test:rules
```

Tests используют только project `demo-tajgo` и Firestore Emulator.
