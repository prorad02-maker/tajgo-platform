# TajGo v1.8 Part 2 — Artifact Manifest

Дата: 27 июля 2026. Версия: **1.8.0+32** (versionName 1.8.0, versionCode 32).
Package: `tj.tajgo.app`. Собрано на Windows (Android). iOS — MAC_REQUIRED, не
собиралось.

## Артефакты

| Артефакт | Путь | Размер (байт) | SHA-256 | Подпись | Назначение |
|---|---|---:|---|---|---|
| Debug APK | `build/app/outputs/flutter-apk/app-debug.apk` | 197 674 350 | `2903E04C050EEB9A663BAF3CBFB450B0210FDFE2A0E1CC816D61917BE9C5ACF3` | Android Debug | debug / smoke |
| Release APK | `build/app/outputs/flutter-apk/app-release.apk` | 68 965 869 | `CF6EB194EFE6A0757F856E4472DBED7EB6720F3328EA4FD1246A08EF9AFA0C87` | **Debug (fallback)** | pilot install (НЕ production) |
| Release AAB | `build/app/outputs/bundle/release/app-release.aab` | 68 522 019 | `AAD123415332A25E2E066F5D39B8F444165E585E4028A4EDF4D873AACBCFB084` | **Debug (fallback)** | Play (после production подписи) |

Release-артефакты собраны с R8 (code + resource shrinking), compileSdk/targetSdk 36,
minSdk 23. SHA-256 могут меняться между пересборками (не bit-for-bit reproducible).

## Signing status
- Production keystore ОТСУТСТВУЕТ → release APK/AAB подписаны **debug-ключом**.
- **НЕ выдавать за production-ready.** См. `V1_8_ANDROID_SIGNING_GUIDE.md`
  (SIGNING_REQUIRED).

## Проверки на момент сборки
- `flutter analyze`: No issues.
- `flutter test`: 93/93 passed.
- Functions: unit 19, rules 16, integration 27 (эмулятор, Java 21) — all green.
- Debug + Release APK + AAB собираются.

## Пригодность
| Канал | Готовность |
|---|---|
| Debug APK (smoke) | ✅ |
| Pilot install (debug-signed) | ✅ (осознавая debug-подпись) |
| Google Play internal/closed testing | ⛔ до production подписи + deploy |
| Production | ⛔ до подписи, deploy, two-phone, iOS |
