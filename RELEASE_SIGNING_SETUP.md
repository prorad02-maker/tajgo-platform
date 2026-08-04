# TajGo Android release signing setup

Release-сборки TajGo не используют debug key как fallback. Пока owner не
создаст upload key и ignored `android/key.properties`, `assembleRelease`,
`bundleRelease`, `flutter build apk --release` и
`flutter build appbundle --release` обязаны завершаться явной ошибкой.

## 1. Включить Play App Signing

В Play Console при создании приложения включить **Play App Signing**. Google
хранит app-signing key, а владелец TajGo хранит отдельный upload key. Не
использовать debug key и не передавать upload key третьим лицам.

## 2. Создать upload key вне репозитория

Команда-шаблон (пути, alias и пароли выбрать владельцу):

```powershell
keytool -genkeypair -v -keystore C:\secure\tajgo-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias tajgo-upload
```

Пароли не указывать в командной строке, если shell сохраняет history: ввести их
в интерактивных prompts. Keystore хранить вне `C:\Projects\tajgo`, сделать
зашифрованную резервную копию и сохранить пароли в password manager.

## 3. Создать локальный key.properties

Скопировать `android/key.properties.example` в ignored
`android/key.properties` и заполнить:

```properties
storeFile=C:/secure/tajgo-upload.jks
storePassword=<OWNER_SECRET>
keyAlias=tajgo-upload
keyPassword=<OWNER_SECRET>
```

`android/key.properties`, `*.jks` и `*.keystore` уже исключены из Git. Перед
каждым commit проверить `git status` и `git diff --cached`.

## 4. Зарегистрировать Firebase fingerprints

Получить SHA без вывода паролей в документы/логи:

```powershell
keytool -list -v -keystore C:\secure\tajgo-upload.jks -alias tajgo-upload
```

Добавить показанные **SHA-1** и **SHA-256** в Firebase Console → project
`tajgo-4fcd0` → Android app package `tj.tajgo.app`, App ID
`1:784873463457:android:0ac2e36af2d8c1a0c91ae0`. После включения Play App
Signing отдельно добавить SHA-1/SHA-256 сертификата app-signing key из Play
Console, потому что он отличается от upload key.

## 5. Собрать и проверить

```powershell
flutter build appbundle --release
keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

Проверить package `tj.tajgo.app`, versionCode, SHA-256 signer и отсутствие
`CN=Android Debug`. Первый AAB загрузить в internal/closed track, затем пройти
Phone Auth, FCM, Crashlytics, App Check observe-only и API 36 smoke. Реальные
пароли, keystore и `key.properties` никогда не коммитить.
