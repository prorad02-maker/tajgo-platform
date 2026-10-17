# tajgo

Flutter-приложение курьерской доставки, Firebase backend и сайт tajgo.ru.

Текущая версия: **1.8.0+32**, Android package: `tj.tajgo.app`.
Фактические результаты проверок, блокеры и инструкции загрузки приложения и сайта: [RELEASE_READY.md](RELEASE_READY.md).

```powershell
# Flutter + backend + emulator checks (JDK 21+)
./scripts/run_v1_8_core_tests.ps1
# Website links and resources
node scripts/check_website.mjs
# ZIP for ordinary static hosting
./scripts/package_website.ps1
# APK + AAB after upload key setup (RELEASE_SIGNING_SETUP.md)
./scripts/build_android_release.ps1
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
