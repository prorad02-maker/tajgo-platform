# TajGo v1.8 — Google Play Submission Checklist

## Предусловия (owner)
- Google Play Console account, app создан (package `tj.tajgo.app`).
- Production keystore + AAB (см. `V1_8_ANDROID_SIGNING_GUIDE.md`).
- Privacy policy URL, deletion URL, support email — действующие.

## Шаги
1. **App content**:
   - Privacy policy: указать URL.
   - Data safety: заполнить по `V1_8_PLAY_DATA_SAFETY_DRAFT.md`; Deletion URL —
     хостинг `public/account-deletion.html`.
   - Ads: нет.
   - Content rating: заполнить анкету (16+).
   - Target audience: 18+ (или 16+), не для детей.
   - Permissions: геолокация on-demand, POST_NOTIFICATIONS.
2. **Store listing**: RU (обяз.), TJ по возможности (`V1_8_STORE_LISTING_RU/TJ`).
   Иконка 512×512, feature graphic 1024×500, скриншоты (`V1_8_SCREENSHOT_PLAN`).
3. **Release → Testing → Internal testing**: загрузить AAB, добавить тестировщиков
   (email), опубликовать. targetSdk 36, versionCode 32.
4. **App integrity**: Play App Signing включён (Google хранит ключ подписи).
   Play Integrity — при включении App Check.
5. **Review notes**: `V1_8_APP_REVIEW_NOTES.md` (тестовые номера).
6. Пройти internal testing на двух телефонах → closed testing.

## Технические требования (проверено в коде)
- targetSdk 36, minSdk 23, package `tj.tajgo.app`.
- Exported components: только MainActivity (LAUNCHER).
- Foreground service: не используется.
- Cleartext: не разрешён явно.

## Блокеры до загрузки
- SIGNING_REQUIRED (production keystore).
- DEPLOY_REQUIRED (Functions/Rules/indexes) — иначе backend-операции не работают.
