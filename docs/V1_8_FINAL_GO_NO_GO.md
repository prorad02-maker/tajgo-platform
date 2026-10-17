# TajGo v1.8 Part 2 — Final GO / NO-GO

Дата: 27 июля 2026. Версия 1.8.0+32. Основано на фактических проверках
(analyze/test/эмулятор/build), а не только на code review.

Легенда: PASS · NOT_VERIFIED · PHONE_REQUIRED · DEPLOY_REQUIRED · SIGNING_REQUIRED
· MAC_REQUIRED · STORE_ACCOUNT_REQUIRED.

## Матрица функций

| Функция | Статус | Flutter | Functions | Rules | Emulator | Phone | Deploy | Mac | Store acc |
|---|---|---|---|---|---|---|---|---|---|
| Phone Auth | PASS (code) | — | — | — | — | PHONE_REQUIRED | — | — | — |
| Дизайн-система + токены | PASS | ✅ | — | — | — | — | — | — | — |
| CustomerShell + поиск | PASS | ✅ | — | — | — | — | — | — | — |
| Удаление аккаунта | PASS | ✅ | ✅ | ✅ | ✅ | PHONE_REQUIRED | DEPLOY | — | — |
| Web deletion form | PASS | — | — | — | — | — | (hosting) | — | — |
| Privacy/Terms/Support | PASS | ✅ | ✅ | — | ✅ | — | DEPLOY | — | — |
| Merchant applications | PASS | ✅ | ✅ | ✅ | ✅ | — | DEPLOY | — | — |
| Saved addresses | PASS | ✅ | — | ✅ | ✅ | — | DEPLOY | — | — |
| Cart persistence | PASS | ✅ | — | — | — | — | — | — | — |
| Orders tab / tracking | PASS | ✅ | — | — | — | PHONE_REQUIRED | DEPLOY | — | — |
| Marketplace UI | PASS | ✅ | — | — | — | — | DEPLOY | — | — |
| Admin catalog (Functions) | PASS | ✅ | ✅ | ✅ | ✅ | — | DEPLOY | — | — |
| CSV/XLSX import | PASS | ✅ | ✅ | — | ✅ | — | DEPLOY | — | — |
| FCM | PASS (code) | ✅ | ✅ | ✅ | ✅ | PHONE_REQUIRED | DEPLOY | (iOS) | — |
| Diagnostics | PASS | ✅ | — | — | — | — | — | — | — |
| App Check prep | PASS (code) | ✅ | — | — | — | — | DEPLOY | — | — |
| Android release | PASS (build) | ✅ | — | — | — | — | — | — | SIGNING_REQUIRED |
| iOS readiness | NOT_VERIFIED | — | — | — | — | — | — | MAC_REQUIRED | STORE_ACCOUNT_REQUIRED |
| Store metadata | PASS (drafts) | — | — | — | — | — | — | — | STORE_ACCOUNT_REQUIRED |

Backend authoritative core (Part 1, 22 callables) — PASS, не переписан.

## Итоговые вердикты

- **GO** — debug APK для smoke.
- **GO** — pilot install release APK (debug-signed, осознавая подпись).
- **GO** — owner backend deploy (Functions/Rules/indexes код готов и протестирован
  в эмуляторе).
- **CONDITIONAL GO** — два телефона: после owner-deploy + Phone Auth (PHONE_REQUIRED,
  DEPLOY_REQUIRED).
- **CONDITIONAL GO** — closed pilot: после two-phone pass + production signing.
- **NO-GO (до действий владельца)** — Google Play internal testing: нужен
  production keystore (SIGNING_REQUIRED) + deploy + Play аккаунт.
- **NO-GO** — Google Play closed testing: те же + пройденный internal.
- **NO-GO** — TestFlight: MAC_REQUIRED + Apple account + iOS Firebase.
- **NO-GO** — production: все выше + отсутствие BLOCKER + observability review.

## Известные внешние блокеры (действия владельца)
1. Production Android keystore (SIGNING_REQUIRED).
2. Firebase deploy Functions/Rules/indexes + FCM + App Check registration
   (DEPLOY_REQUIRED).
3. iOS: Mac + Xcode + Apple Developer + GoogleService-Info + flutterfire configure
   (MAC_REQUIRED, STORE_ACCOUNT_REQUIRED).
4. Play/App Store аккаунты (STORE_ACCOUNT_REQUIRED).
5. Two-phone E2E (PHONE_REQUIRED).

Код-часть Part 2 завершена и зелёная. Оставшееся — исключительно owner-действия
(подпись, deploy, Mac, store-аккаунты, физические телефоны).
