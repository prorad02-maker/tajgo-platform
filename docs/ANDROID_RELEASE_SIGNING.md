# Android release signing для TajGo

Проект умеет читать локальный `android/key.properties`. Если файла нет, `flutter build apk --release` остаётся доступен, но APK подписывается debug-ключом и выводит предупреждение. Такой APK не является production-релизом.

## 1. Создать ключ вне репозитория

Создайте приватную папку, например `$env:USERPROFILE\.android-keys`, перейдите в неё и выполните требуемую команду:

```powershell
keytool -genkey -v -keystore tajgo-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias tajgo
```

Храните keystore и пароли в password manager/защищённом backup. Потеря ключа лишит возможности выпускать обновления приложения с той же подписью.

## 2. Создать локальный key.properties

Скопируйте `android/key.properties.example` в `android/key.properties` и замените placeholders:

```properties
storePassword=<секрет>
keyPassword=<секрет>
keyAlias=tajgo
storeFile=C:\\Users\\<user>\\.android-keys\\tajgo-release-key.jks
```

`android/key.properties`, `*.jks` и `*.keystore` уже исключены из Git. Перед каждым коммитом всё равно проверяйте `git status` и `git diff --cached`.

Никогда не коммитить:

- настоящий `key.properties`;
- keystore (`.jks`/`.keystore`);
- пароли, PIN или recovery-коды;
- приватные CI secrets.

## 3. Получить SHA-1 и SHA-256

Для release-ключа:

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android-keys\tajgo-release-key.jks" -alias tajgo
```

Для стандартного debug-ключа:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

Добавьте оба fingerprint в Android app Firebase после окончательного выбора `applicationId`.

## 4. Собрать и проверить

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`.

Проверить сертификат можно Android Build Tools:

```powershell
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
```

Production APK допустим к передаче только если сертификат совпадает с release SHA, добавленным в Firebase. Debug-подпись, даже у файла `app-release.apk`, для реального релиза не подходит.
