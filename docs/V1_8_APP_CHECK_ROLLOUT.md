# TajGo v1.8 — App Check Rollout (P3.3)

Статус: клиентская активация готова (за флагом `appCheck`), **enforcement НЕ
включён**. Активация enforcement — отдельное owner-действие в Console после
мониторинга.

## Клиент

`lib/core/services/app_check_service.dart` — `activate(enabled)`:

- debug-сборка: `AndroidDebugProvider` / `AppleDebugProvider`;
- release: `AndroidPlayIntegrityProvider` / `AppleAppAttestProvider`;
- любая ошибка активации проглатывается (graceful).

Вызов — в `main.dart` за флагом `appCheck` (по умолчанию только в debug; в
pilot/production — off, включается через `--dart-define=TAJGO_FF_APP_CHECK=true`
после регистрации приложений).

Серверные callable: `enforceAppCheck: false`, `consumeAppCheckToken: false`
(`functions/src/index.ts`) — enforcement выключен намеренно.

## Rollout (owner)

1. **Регистрация приложений** в Firebase Console → App Check:
   - Android: Play Integrity (SHA-256 из Play Console);
   - iOS: App Attest / DeviceCheck (Mac + Apple account).
2. **Debug-токены** для тестовых устройств/эмуляторов (Console → App Check →
   Manage debug tokens).
3. Включить `TAJGO_FF_APP_CHECK=true` для pilot-сборки; проверить, что легитимные
   запросы получают валидный токен (метрики Console → Verified/Unverified).
4. **Monitoring-фаза**: наблюдать долю unverified в Console **без** enforcement
   (недели, а не часы).
5. **Enforcement** включается в Console по продуктам (Firestore, Functions)
   только когда доля verified стабильно высокая. В коде включить
   `enforceAppCheck: true` для callable и передеплоить.

## Rollback

- Выключить enforcement в Console (мгновенно) — запросы снова принимаются без
  токена.
- В коде вернуть `enforceAppCheck: false` и передеплоить.
- Флаг `TAJGO_FF_APP_CHECK=false` отключает клиентскую активацию.

## Риски

- Преждевременный enforcement блокирует легитимных пользователей со старыми
  сборками/без токена. Всегда проходить monitoring-фазу.
- iOS App Attest требует физических устройств и Apple-настройки (MAC_REQUIRED).
