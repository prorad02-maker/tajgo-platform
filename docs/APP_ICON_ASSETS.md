# TajGo app icon assets

Финальные PNG пока отсутствуют в `assets/brand/`, поэтому генерация launcher-иконок для v0.8.0 не запускалась. До получения утверждённых исходников Android продолжает использовать текущие файлы `mipmap-*/ic_launcher.png`.

## Какие файлы подготовить

Все исходники экспортировать в PNG, цветовой профиль sRGB, без внешних полей и артефактов сжатия:

| Файл | Размер | Требования |
| --- | ---: | --- |
| `app_icon.png` | 1024×1024 px | Полная квадратная иконка для legacy Android/iOS; без скругления углов в самом файле. |
| `app_icon_foreground.png` | 1024×1024 px | Прозрачный фон; важный знак внутри центральной safe-zone примерно 66% холста. |
| `app_icon_background.png` | 1024×1024 px | Непрозрачный фон adaptive icon, без мелких деталей. |
| `app_icon_monochrome.png` | 1024×1024 px | Одноцветный белый силуэт на прозрачном фоне для themed icon Android 13+. |

Положить файлы в:

```text
assets/brand/app_icon.png
assets/brand/app_icon_foreground.png
assets/brand/app_icon_background.png
assets/brand/app_icon_monochrome.png
```

## Генерация после утверждения дизайна

1. Проверить все четыре имени и размеры.
2. В `pubspec.yaml` заменить `adaptive_icon_background: "#CBE5AF"` на `adaptive_icon_background: assets/brand/app_icon_background.png`, если должен использоваться PNG-фон.
3. Запустить:

```powershell
flutter pub get
dart run flutter_launcher_icons
flutter build apk --debug
```

4. Установить APK и визуально проверить обычную, adaptive и themed icon на реальном Android-устройстве.

Не запускать генератор с временным логотипом: он перезаписывает все launcher-ресурсы.
