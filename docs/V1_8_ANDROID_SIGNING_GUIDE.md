# TajGo v1.8 — Android Signing Guide

Статус: scaffolding готов. Production-подпись — **SIGNING_REQUIRED** (owner
создаёт keystore). Без `android/key.properties` release-сборка подписывается
**debug-ключом** и НЕ является production-артефактом.

## Что уже настроено

- `android/app/build.gradle.kts`: читает `android/key.properties`, при наличии
  использует release-подпись, иначе — debug (с предупреждением).
- R8 + resource shrinking для release (`isMinifyEnabled`, `isShrinkResources`) с
  `android/app/proguard-rules.pro`.
- `compileSdk`/`targetSdk` ≥ 36, `minSdk` ≥ 23, `applicationId = tj.tajgo.app`.
- `.gitignore` закрывает `*.jks`, `*.keystore`, `key.properties`.
- `android/key.properties.example` — шаблон.

## Шаги владельца (SIGNING_REQUIRED)

1. Создать upload keystore (один раз):
   ```
   keytool -genkey -v -keystore tajgo-upload.jks -keyalg RSA -keysize 2048 \
           -validity 10000 -alias tajgo-upload
   ```
   Хранить `.jks` вне репозитория, сделать резервную копию. Потеря ключа ломает
   будущие обновления в Play.
2. Скопировать `android/key.properties.example` → `android/key.properties`,
   заполнить `storeFile/storePassword/keyAlias/keyPassword`.
3. Получить SHA-1 и SHA-256 подписи и добавить в Firebase Console (для Phone
   Auth и App Check Play Integrity):
   ```
   keytool -list -v -keystore tajgo-upload.jks -alias tajgo-upload
   ```
4. Собрать артефакты:
   ```
   flutter build appbundle --release   # AAB для Play
   flutter build apk --release         # APK для прямой установки
   ```
5. Проверить подпись:
   ```
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
   ```
   Сертификат НЕ должен быть `CN=Android Debug`.
6. Загрузить AAB в Play Console (internal testing). Google Play подписывает
   приложение своим ключом (Play App Signing); upload-ключ — ваш.

## Runtime-проверка R8

R8-shrunk release-сборку нужно проверить на физическом устройстве
(PHONE_REQUIRED): запуск, вход, заказ, каталог, уведомления — убедиться, что
ничего не сломано shrinking'ом. При проблеме — расширить `proguard-rules.pro`
или временно `isMinifyEnabled = false`.
