# TajGo — Spec v2 для реализации: «Живая карта»

Это самодостаточное техническое задание. Выполняй его по порядку.
Перед началом прочитай `docs/ARCHITECTURE.md` (общая архитектура) и раздел 5
из `docs/SPEC_CODEX_V1.md` (дизайн-токены «Платформа TG+» — действуют и здесь).

---

## 1. Контекст

TajGo — Flutter-приложение доставки для Худжанда (Таджикистан). Итерация 1
завершена: работает сквозной поток заказа (клиент создаёт → курьер принимает →
забрал → доставил, realtime через Firestore `snapshots()`), дизайн «Платформа
TG+» применён, DI через `TajGoScope` (`lib/shared/widgets/tajgo_scope.dart`),
вся работа с Firestore — только в репозиториях `lib/core/services/`.

Сейчас адреса заказа — просто текст, который клиент печатает руками
(`fromText`/`toText`), у заказа нет координат, расстояние и цена не считаются,
курьеры не видны на карте.

В `lib/features/map/` лежит задел карты (flutter_map + OSM, центр — Худжанд
40.2833, 69.6222): экран `tajgo_map_screen.dart` с выбором точки по long-press.
Модуль не подключён к приложению и содержит мёртвые дубли — их чистка входит
в эту итерацию (Задача 0).

## 2. Цель итерации

Заказ создаётся через живую карту:

> Клиент жмёт «Заказать доставку» → открывается карта Худжанда, на ней зелёными
> точками видны курьеры онлайн и чип «N курьеров рядом» → клиент выбирает точку
> «Откуда», затем «Куда» (пин по центру карты) → приложение считает расстояние,
> время и предлагает цену → клиент подтверждает детали (тип, цена — можно
> изменить) → заказ создан с координатами. Курьер на линии автоматически
> транслирует свои координаты (пока приложение открыто), и клиент видит его
> точку на карте.

Главная клиента остаётся «Платформой TG+» — карта открывается по CTA
«Заказать доставку» и по тапам на категории.

## 3. Жёсткие ограничения

1. **Новые pub-пакеты: разрешён ровно один рантайм-пакет — `geocoding`
   (последняя стабильная версия)** для обратного геокодирования. Плюс
   dev-пакет `flutter_launcher_icons` — только по условию Задачи 7а.
   Больше ничего не добавлять.
2. **Не трогать** `lib/firebase_options.dart`, `firebase.json`,
   `android/app/google-services.json`.
3. **Не вводить** Bloc/Riverpod/Provider/go_router. Состояние — `setState` +
   `StreamBuilder`; зависимости — через `TajGoScope`; навигация — `Navigator`.
4. UI-обращения к Firestore/Auth — только через репозитории в
   `lib/core/services/`. Прямые `FirebaseFirestore.instance` в фичах запрещены.
5. Все записи времени — `FieldValue.serverTimestamp()`.
6. Геолокация — только пока приложение открыто (foreground). Никаких
   background-сервисов, WorkManager и т.п.
7. Комментарии и строки UI — на русском. Дизайн — токены `TajGoColors`
   (раздел 5 SPEC_CODEX_V1.md): CTA — лайм, карточки белые/mint, шапки —
   градиент darkGreen→green.
8. Тайлы карты — OpenStreetMap как в существующем экране
   (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`, с RichAttributionWidget).

## 4. Задачи

### Задача 0. Чистка модуля карты

Удалить мёртвое старое поколение:

- `lib/features/map/services/location_service.dart` (дубль класса
  `TajGoLocationService` со старым deprecated-API);
- `lib/features/map/models/tajgo_location.dart` (дубль модели);
- `lib/features/map/repositories/tajgo_map_repository.dart` (нарушает правило
  DI и пишет в неиспользуемую коллекцию `users/*/saved_locations`);
- `lib/features/map/map_module.dart` (экспортирует удаляемые файлы).

Остаются и дорабатываются: `models/tajgo_map_location.dart`,
`services/tajgo_location_service.dart`, `screens/tajgo_map_screen.dart`,
`widgets/tajgo_map_marker.dart`.

В оставшихся файлах заменить захардкоженные старые цвета (`0xFF0B8F4D`,
`0xFF617066`, `0xFFEAF7EF` и т.п.) на токены `TajGoColors`.

### Задача 1. Модели: координаты

**`lib/features/map/models/tajgo_map_location.dart`** — дополнить:

```dart
// добавить конверсию для Firestore и flutter_map:
GeoPoint toGeoPoint();
LatLng toLatLng();
factory TajGoMapLocation.fromGeoPoint(GeoPoint point, {String address});
```

**`lib/core/models/tajgo_order.dart`** — добавить поля
`fromLocation` / `toLocation` (`GeoPoint?`, читать/писать как geopoint),
включить их в `toCreateMap()` (если не null). Поля `distanceKm`, `etaMinutes`
уже есть — теперь они записываются при создании заказа.

**`lib/core/models/tajgo_courier.dart`** — добавить `location` (`GeoPoint?`)
и `locationUpdatedAt` (`DateTime?`).

### Задача 2. Геосервисы

**`lib/features/map/services/tajgo_location_service.dart`**:

- `determineCurrentPosition()` — уже реализован, не менять.
- `reverseGeocode(...)` — сейчас заглушка. Реализовать через пакет `geocoding`
  (`placemarkFromCoordinates`): собрать адрес из
  `street/subLocality/locality`, пустые части отбросить; при любой ошибке или
  пустом результате — существующий fallback на координаты. Обернуть вызов в
  `.timeout(const Duration(seconds: 5))` с тем же fallback.
- Новый метод — стрим позиции для курьера:
  ```dart
  Stream<Position> positionStream() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 30, // метров: не спамить Firestore
    ),
  );
  ```

Зарегистрировать `TajGoLocationService` в `TajGoScope` (по образцу остальных).

**`lib/core/services/courier_repository.dart`** — добавить:

```dart
/// Обновляет координаты курьера (вызывается только когда online).
Future<void> updateLocation({
  required String uid,
  required double latitude,
  required double longitude,
}); // set merge: location: GeoPoint, locationUpdatedAt: serverTimestamp

/// Курьеры на линии с известными координатами (для карты клиента).
Stream<List<TajGoCourier>> onlineCouriersStream();
// where('online', isEqualTo: true), limit(50),
// на клиенте отфильтровать тех, у кого location == null
```

**Разрешения платформ**: убедиться, что в
`android/app/src/main/AndroidManifest.xml` есть
`ACCESS_FINE_LOCATION` и `ACCESS_COARSE_LOCATION`, а в `ios/Runner/Info.plist` —
`NSLocationWhenInUseUsageDescription` с русским текстом
(«TajGo показывает курьеров рядом и помогает выбрать адрес доставки.»).
Добавить, если отсутствуют.

### Задача 3. Экран заказа на карте — `NewOrderMapScreen`

Новый файл `lib/features/map/screens/new_order_map_screen.dart`. Это главный
экран итерации: живая карта + пошаговый выбор точек + создание заказа.
Существующий `tajgo_map_screen.dart` больше не нужен как отдельный сценарий —
удалить его после переноса полезных виджетов (`_CurrentLocationMarker`,
`_RoundButton` и т.п. перенести в этот экран или в `widgets/`).

Экран принимает `initialType` (String, по умолчанию `'package'`).

**Состояние — enum этапов:**

```dart
enum _Stage { pickFrom, pickTo, details }
```

**Общий каркас (все этапы):**

- `FlutterMap`: центр Худжанд (40.2833, 69.6222), zoom 13, OSM-тайлы,
  attribution — как в старом экране.
- Слой курьеров: `StreamBuilder` на `onlineCouriersStream()`; каждый курьер —
  зелёная точка (кружок `TajGoColors.green` c белой обводкой, как маркер
  текущей позиции в старом экране, но меньше — 18px).
- Сверху по центру — белый чип-«пилюля» с тенью: «💚 N курьеров рядом»
  (N — размер списка из стрима; если 0 — «Пока нет курьеров рядом»).
- Кнопка «моё местоположение» справа снизу (перенести `_RoundButton` и логику
  `determineCurrentPosition` из старого экрана; ошибки геолокации показывать
  SnackBar, экран работает и без разрешения — просто без синей точки).
- Назад — `_RoundButton` со стрелкой слева сверху.

**Этапы pickFrom / pickTo — выбор точки пином по центру карты:**

- В центре карты нарисован неподвижный пин (`Icon(Icons.location_pin)`,
  48px: для «Откуда» — `TajGoColors.darkGreen`, для «Куда» — лаймовый
  `TajGoColors.lime` с тёмной обводкой). Пользователь двигает карту под пином.
- Нижняя панель (белая, скругление 20 сверху): заголовок «Откуда забрать?» /
  «Куда доставить?», строка адреса — результат `reverseGeocode` для текущего
  центра карты. Геокодировать по событию `onMapEvent` c `MapEventMoveEnd`
  (после остановки карты), пока считается — «Определяем адрес...».
- Кнопка «Подтвердить точку» (лайм): сохраняет `TajGoMapLocation` этапа,
  переход pickFrom → pickTo → details. Выбранная точка «Откуда» на этапах
  дальше отображается маркером на карте.

**Этап details — нижний лист деталей заказа:**

- На карте: оба маркера + `PolylineLayer` с прямой линией fromLocation →
  toLocation (`TajGoColors.green`, width 4). Карту отцентрировать так, чтобы
  обе точки были видны (`CameraFit.coordinates` с padding 60).
- Нижний лист (белый, скругление 20 сверху):
  - строки «Откуда» / «Куда» с адресами (текст `muted`, po тапу — вернуться на
    соответствующий этап и переизбрать точку);
  - чипы типа заказа (как в `OrderFormScreen`: package/food/shops/pharmacy/
    flowers/docs, выбранный — `darkGreen` с белым текстом), предвыбран
    `initialType`;
  - строка «~X км · ~Y мин» (расчёт — Задача 4);
  - поле «Цена, TJS» — предзаполнено рассчитанной ценой, редактируемое
    (валидация: положительное число);
  - кнопка «Найти курьера · N TJS» (лайм, N — текущая цена из поля):
    `_busy`-паттерн, вызывает `orderRepository.createOrder(...)` с новыми
    параметрами (Задача 4), после успеха — `Navigator.pop` на главную
    (карточка активного заказа там уже работает).

**Подключение:** в `customer_home_screen.dart` кнопка «Заказать доставку» и
тапы по категориям открывают `NewOrderMapScreen(initialType: ...)` вместо
`OrderFormScreen`. Сам `OrderFormScreen` удалить — он полностью заменён.

### Задача 4. Расчёт расстояния, времени и цены

Новый файл `lib/core/services/pricing.dart` — чистые функции без зависимостей
от Flutter/Firebase (легко тестировать):

```dart
/// Расстояние по прямой в км (пакет latlong2: Distance().as(...)), 1 знак.
double distanceKm(LatLng from, LatLng to);

/// Время доставки: скорость электровелосипеда ~18 км/ч + 5 минут на забор.
/// etaMinutes = ceil(distanceKm / 18 * 60) + 5
int etaMinutes(double distanceKm);

/// Цена: посадка 10 TJS + 4 TJS/км, округление вверх до целого, минимум 10.
num suggestedPrice(double distanceKm);
```

`OrderRepository.createOrder` — расширить необязательными параметрами
`fromLocation`, `toLocation` (`GeoPoint?`), `distanceKm` (`num?`),
`etaMinutes` (`int?`); писать в документ, если переданы.

### Задача 5. Трансляция координат курьера

В `lib/features/courier/courier_home_screen.dart`:

- Пока курьер online и экран открыт: подписка на
  `locationService.positionStream()`, каждая позиция →
  `courierRepository.updateLocation(...)`. Подписку создавать при
  `online == true`, отменять при `online == false`, в `dispose()` и при
  ошибке стрима (ошибку показать SnackBar один раз, не циклить).
- Перед первой подпиской вызвать `determineCurrentPosition()` — он корректно
  запрашивает разрешения; при отказе — SnackBar с текстом исключения, курьер
  остаётся на линии, но без трансляции.
- В шапке рядом со статусом линии — маленькая пометка: «📡 координаты
  передаются» когда подписка активна.

Троттлинг записи даёт `distanceFilter: 30` в сервисе — дополнительный не нужен.

### Задача 6. Данные заказа у курьера

В карточке заказа курьера (`_OrderCard`) показывать, если есть:
«~X км · ~Y мин» из `distanceKm`/`etaMinutes` (стиль `muted`, как цена).

### Задача 7. Светлый сплэш-экран (дизайн утверждён)

Переделать `lib/features/splash/splash_screen.dart`. Логика bootstrap
(вход, ensureUser, таймауты, обработка ошибок) НЕ меняется — только внешний вид.

Композиция (сверху вниз, фон — белый `#FFFFFF` с лёгким уходом в `#FAFCF7`):

1. **Логотип** по центру верхних двух третей экрана:
   - если существует ассет `assets/brand/tajgo_logo.png` — показать его
     (ширина ~60% экрана); объявить папку `assets/brand/` в `pubspec.yaml`;
   - если файла нет — оставить существующий виджет `TajGoLogo` + под ним
     текст «TajGo» (стиль: `Taj` цветом `#272B2E`, `Go` — `TajGoColors.green`,
     w900, ~44px, letterSpacing -1.5).
2. **Слоган**: «Проще. Быстрее. Честнее. Для своих.» — тёмный `#3A4440`,
   «Для своих.» — `TajGoColors.green`, w800.
3. **Полоса загрузки**: `LinearProgressIndicator` (indeterminate), ширина
   ~130, скруглённая, цвет `TajGoColors.green`, фон `#DFEDD8`; под ней —
   текущий `_status` (мелкий, `#7C8A80`).
4. **Пейзаж внизу** (нижняя треть, прижат к низу, edge-to-edge) — нарисовать
   `CustomPainter`-ом, слои сзади вперёд:
   - пастельные горы: плавная кривая, `#E3EEDC`;
   - солнце: круг `#F5D97E` (правее центра, на линии гор);
   - силуэт города (купола/минареты, можно упрощённо прямоугольники+дуги):
     два слоя, `#4E9455` и `#3E8447`;
   - холмы: две тёмно-зелёные кривые `#2E7C46` и `#1E5C33`;
   - дорога: белая линия шириной ~10, S-кривая от нижнего края вверх к центру
     пейзажа, `strokeCap: round`, цвет `#F4F9F1`.

Тёмного варианта сплэша нет. Ошибка подключения показывается как сейчас —
текстом в `_status`.

### Задача 7а. Иконка приложения (условная — только если есть файл)

Если в репозитории присутствует `assets/brand/app_icon_1024.png` (скруглённый
квадрат «TG+» с пейзажем): добавить в `dev_dependencies` пакет
`flutter_launcher_icons`, сконфигурировать в `pubspec.yaml` (android: true,
ios: true, image_path: assets/brand/app_icon_1024.png, adaptive_icon_background:
`#CBE5AF`, adaptive_icon_foreground: тот же файл) и выполнить
`dart run flutter_launcher_icons`. Это dev-инструмент, рантайм-зависимостей не
добавляет — ограничение №1 не нарушается. **Если файла нет — задачу пропустить
целиком** и написать об этом в итоговом отчёте.

### Задача 8. Тесты и финальная проверка

1. Юнит-тесты на `pricing.dart`: расстояние Худжанд-центр → Панчшанбе
   (известные координаты, допуск), `suggestedPrice` (0 км → 10; 2.5 км → 20),
   `etaMinutes`.
2. `flutter analyze` — ноль ошибок и warnings; `info` допустимы только если
   были до итерации.
3. `flutter test` — всё проходит.
4. В `lib/features/` нет прямых импортов `cloud_firestore` вне
   `core/models` (модели — можно, им нужен `GeoPoint`).

---

## 5. Модель данных (дельта)

### orders/{orderId} — новые поля

| Поле | Тип | Обязательное |
|---|---|---|
| fromLocation, toLocation | geopoint | нет (есть у заказов с карты) |
| distanceKm | number | нет |
| etaMinutes | number | нет |

`fromText`/`toText` остаются — теперь это адреса из обратного геокодирования.

### couriers/{uid} — новые поля

| Поле | Тип | Описание |
|---|---|---|
| location | geopoint | последняя позиция (пишется на линии, шаг ≥30 м) |
| locationUpdatedAt | timestamp | серверное время записи |

---

## 6. Критерии приёмки (ручной сценарий)

1. Главная клиента → «Заказать доставку» → карта Худжанда с чипом
   «N курьеров рядом» (или «Пока нет курьеров рядом»).
2. Этап «Откуда»: пин в центре, при остановке карты подставляется адрес
   (или координаты, если геокодер недоступен) → «Подтвердить точку» →
   этап «Куда» → «Подтвердить точку» → детали.
3. Детали: линия маршрута между точками, «~X км · ~Y мин», цена предзаполнена
   и редактируема, чипы типов работают. «Найти курьера · N TJS» → возврат на
   главную, карточка «🔎 Ищем курьера» появилась.
4. В Firestore у заказа: fromLocation/toLocation (geopoint), distanceKm,
   etaMinutes, fromText/toText с адресами.
5. Режим курьера → «Выйти на линию» → разрешение геолокации → пометка
   «📡 координаты передаются»; в Firestore couriers/{uid}.location появился и
   обновляется при перемещении (проверка на эмуляторе — сменить mock-позицию).
6. На карте нового заказа у клиента виден зелёный маркер этого курьера,
   чип показывает «1 курьеров рядом» (склонение не требуется).
7. Курьер видит в карточке заказа «~X км · ~Y мин».
8. Сквозной поток итерации 1 (принять → забрал → доставил → заработок) не
   сломан. `flutter analyze` и `flutter test` чистые.
9. Папок/файлов из Задачи 0 не существует; `OrderFormScreen` удалён.
10. Сплэш — светлый по Задаче 7: логотип, слоган с зелёным «Для своих»,
    анимированная полоса, пейзаж с городом и дорогой внизу. Никакого зелёного
    градиента на весь экран, как раньше.

---

## 7. Вне рамок этой итерации (НЕ делать)

- Фоновая геолокация курьера (когда приложение свёрнуто) и любые
  background-сервисы.
- Карта у курьера (заказы-пины, маршрут до точки) — итерация 3.
- Реальная маршрутизация OSRM/GraphHopper (линия — прямая).
- Живой маркер курьера в карточке активного заказа клиента.
- Зоны доставки, геохеши, поиск ближайшего курьера.
- Такси, кошелёк, таббар, история заказов, security rules, телефонный вход.
- Любые другие новые пакеты, кроме `geocoding` (и dev-пакета
  `flutter_launcher_icons` по Задаче 7а).
- Тёмная версия сплэша (отклонена — сплэш только светлый).
