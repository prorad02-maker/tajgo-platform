# TajGo Foundation v4

Первая версия TajGo, которая реально подключается к Firebase.

## Что добавлено

- Firebase Core initialization через `lib/firebase_options.dart`.
- Anonymous demo login для тестирования без SMS.
- Firestore service.
- Создание базовых документов:
  - `cities/khujand`
  - `settings/app`
  - `orders/{demoOrder}`
- Курьерский сценарий:
  - выйти на линию;
  - записать `online: true` в `couriers/{uid}`;
  - увидеть заказы со статусом `waiting`;
  - принять заказ;
  - обновить заказ в Firestore.
- Клиентский сценарий:
  - создать тестовый заказ.

## Важно

В ZIP нет файла `lib/firebase_options.dart`, потому что он создаётся локально командой:

```bash
flutterfire configure
```

Не удаляйте этот файл из проекта.

## Нужные зависимости

```bash
flutter pub add firebase_core firebase_auth cloud_firestore
```

## Проверка

1. Запустить приложение.
2. Выбрать курьера.
3. Нажать «Выйти на линию».
4. Проверить Firestore: `couriers/{uid}`.
5. Создать заказ на экране клиента.
6. Вернуться к курьеру и принять заказ.
7. Проверить Firestore: `orders/{orderId}.status = accepted`.
