# TajGo — Доработка итерации 1: привести MVP к спеке v1.1

Это задание-доработка. Основная спека — `docs/SPEC_CODEX_V1.md` (версия 1.1),
раздел 5 «Дизайн "Платформа TG+"» — обязателен к прочтению перед началом.

Контекст: поток заказа реализован по ранней версии спеки (v1.0) и работает
корректно — модели, транзакции, `declinedBy`, форма заказа, realtime-статусы
менять НЕ нужно. Не выполнена часть v1.1: дизайн «Платформа TG+», замена типа
`taxi` на `docs`, удаление экрана роли, заработок курьера. Ошибки analyze в
`lib/features/map/` уже исправлены — модуль карты по-прежнему НЕ трогать.

Ограничения из основной спеки действуют полностью (никаких новых пакетов,
никаких Bloc/Riverpod/go_router, Firestore только через репозитории).

---

## Фикс 1. Убрать экран выбора роли

- Удалить папку `lib/features/role/`.
- В `lib/features/splash/splash_screen.dart` заменить переход: вместо
  `RoleScreen` → `CustomerHomeScreen` (импорт из `features/customer/`).
- Режим курьера открывается модулем «Стать курьером» с главной (Фикс 3).

## Фикс 2. Тип заказа: `taxi` → `docs`

Такси — будущий модуль платформы, а не тип доставки. Заменить в двух местах:

- `lib/features/customer/customer_home_screen.dart` — в мапе сервисов
  `'taxi': '🚕 Такси'` → `'docs': '📄 Документы'`.
- `lib/features/customer/order_form_screen.dart` — в `_types`
  `'taxi': 'Такси'` → `'docs': 'Документы'`.

## Фикс 3. Дизайн «Платформа TG+» (раздел 5 основной спеки)

### 3а. Токены — `lib/core/constants/tajgo_colors.dart`

Привести значения точно к таблице токенов раздела 5. Итоговый набор
(существующие имена сохранить, значения обновить, недостающие добавить):

```dart
static const green = Color(0xFF16A34A);
static const darkGreen = Color(0xFF15803D);
static const lime = Color(0xFF84CC16);
static const mint = Color(0xFFDCFCE7);
static const background = Color(0xFFF4F9F3);
static const card = Color(0xFFFFFFFF);
static const ink = Color(0xFF12301E);      // = text
static const text = ink;
static const muted = Color(0xFF54705E);
static const soonBg = Color(0xFFEDF0F4);
static const soonText = Color(0xFF64748B);
static const secondaryBtn = Color(0xFFEDF6EC);
static const navy = Color(0xFF0F172A);     // резерв под тёмную тему
static const warning = Color(0xFFF4B400);
```

### 3б. Тема — `lib/app/tajgo_theme.dart`

`scaffoldBackgroundColor: background`; CardTheme — белый, скругление 18,
мягкая тень (`rgba(18,48,30,0.1)`, blur 18, offset (0,6)); FilledButton по
умолчанию — лайм `lime` с текстом `ink`, скругление 12, минимальная высота 48,
`fontWeight: FontWeight.w800`.

### 3в. Главная клиента — `customer_home_screen.dart`

Переделать по ASCII-макету из раздела 5 основной спеки (сверху вниз):

1. **Шапка**: градиент `darkGreen → green`, скругление только снизу 24, без
   боковых отступов (AppBar убрать, шапка — часть скролла, edge-to-edge).
   Внутри: «📍 Худжанд», заголовок «TajGo — платформа вашего города 💚»
   (белый, w900).
2. **Карточка активного заказа** (существующий `_ActiveOrder` перекрасить):
   фон `mint`, статус-чип — скруглённый бейдж `darkGreen` с белым текстом.
   Логика статусов уже написана — не менять.
3. **Модуль «Доставка»**: белая карточка, рамка 2px `lime`, бейдж «Активно»
   (`mint`/`darkGreen`) в правом верхнем углу, «🚚 Доставка» (w800),
   подзаголовок «Посылки · Еда · Аптеки · Документы» (`muted`), внутри
   лаймовая кнопка «Заказать доставку» → `OrderFormScreen`. Существующую
   сетку категорий разместить внутри этого модуля (тап по категории открывает
   форму с предвыбранным типом — уже работает).
4. **Ряд «скоро»**: две карточки в ряд с opacity 0.7 и бейджем «скоро»
   (`soonBg`/`soonText`): «🚕 Такси — Поездки по городу», «💳 Кошелёк — Оплата
   и бонусы». Тап → SnackBar «Скоро на платформе TajGo 💚».
5. **Модуль «Стать курьером»**: белая карточка, «🚴 Стать курьером»,
   подзаголовок «Зарабатывайте с TajGo — свободный график». Тап → push
   `CourierHomeScreen`.

### 3г. Экран курьера — `courier_home_screen.dart`

- Верхнюю карточку заменить шапкой-градиентом как у клиента (снизу
  скругление 24): «📍 Худжанд», «Вы на линии 🟢» / «Готовы выйти на линию?»
  (белый, w900), строка «Сегодня заработано — N TJS» из
  `TajGoCourier.earningsToday`, кнопка тумблера — белая с текстом `darkGreen`.
- Карточку «Мой активный заказ» — фон `mint`.
- В `_OrderCard` кнопку «Отказаться» — фон `secondaryBtn`, текст `darkGreen`
  (вместо OutlinedButton).

## Фикс 4. Заработок курьера

В `lib/core/services/courier_repository.dart`, метод `_transition`: при
переходе `pickedUp → delivered` в той же транзакции увеличить
`couriers/{courierId}.earningsToday` на цену заказа:

```dart
transaction.update(_db.collection('couriers').doc(courierId), {
  'earningsToday': FieldValue.increment((data?['price'] ?? 0) as num),
});
```

(добавить только для перехода в `delivered`).

## Фикс 5. Чистота analyze

`flutter analyze` сейчас выдаёт `info`-замечания. Устранить:

- `curly_braces_in_flow_control_structures` (8 мест в новых файлах) — обернуть
  тела if в `{}`.
- `withOpacity` deprecated в `lib/shared/widgets/tajgo_logo.dart` — заменить
  на `.withValues(alpha: ...)`.
- Замечания внутри `lib/features/map/` — НЕ трогать (модуль карты).

---

## Критерии приёмки

1. Запуск → Splash → сразу главная-платформа (экрана выбора роли нет): зелёная
   шапка, модуль «Доставка» с лаймовой рамкой и категориями внутри, ряд
   «Такси»/«Кошелёк» с бейджами «скоро» (тап — SnackBar), модуль «Стать
   курьером» → экран курьера (назад — стрелкой).
2. В форме заказа чипы: Посылка/Еда/Магазины/Аптеки/Цветы/Документы (без такси).
3. Сквозной сценарий из основной спеки работает как раньше; после «Доставил»
   «Сегодня заработано» в шапке курьера увеличилось на цену заказа.
4. `flutter analyze` — ноль ошибок, ноль warning, из info остались только
   замечания в `lib/features/map/`.
5. `flutter test` проходит.
