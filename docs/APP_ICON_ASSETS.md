# Иконка приложения TajGo

В v0.8.3 launcher-иконки Android и iOS генерируются из финального мастер-файла `assets/brand/app_icon.png`. Знак объединяет маршрут, движение вперёд и горы Худжанда.

## Файлы

| Файл | Размер | Назначение |
| --- | ---: | --- |
| `app_icon.png` | 1024×1024 px | Полноцветная иконка для обычных Android-иконок и iOS. |
| `app_icon_foreground.png` | 1024×1024 px, RGBA | Прозрачный передний слой adaptive icon Android. Знак находится в safe zone. |
| `app_icon_background.png` | 1024×1024 px | Непрозрачный изумрудный фон adaptive icon. |
| `app_icon_monochrome.png` | 1024×1024 px, RGBA | Белый силуэт для themed icon Android 13+. |

Не скругляйте углы в исходном `app_icon.png`: форму и маску применяет операционная система.

## Повторная генерация

После замены исходников выполните из корня проекта:

```powershell
flutter pub get
dart run flutter_launcher_icons
flutter build apk --debug
```

Генератор обновляет ресурсы `android/app/src/main/res/mipmap-*` и каталог иконок iOS. Поэтому запускайте его только с утверждёнными файлами.

## Проверка на телефоне

1. Удалите прежнюю debug-версию TajGo или очистите кэш launcher.
2. Установите новый APK.
3. Проверьте обычную иконку, круглую маску и themed icon Android 13+.
4. Убедитесь, что под иконкой отображается название `TajGo`.
