# TajGo 1.4.0+29 — Full Pilot Completion

## Добавлено

- Клиентская витрина партнёров для категорий `Еда`, `Продукты`, `Цветы`.
- Каталог товаров с доступностью, единицами `шт. / кг / порция / букет`, ценой и старой ценой.
- Единая корзина одного партнёра, шаг `0,5 кг`, минимальная сумма и полный расчёт.
- Checkout с выбором точки доставки на карте, маршрутом, расстоянием, ETA и повторной Firestore-проверкой данных.
- `catalogOrder` со snapshot товаров, суммами и фиксированной стоимостью курьерской доставки.
- Краткий состав заказа в клиентском tracking.
- Admin-раздел партнёров и товаров с audit log и soft visibility controls.
- Debug seed: 3 партнёра и 6 товаров.
- Unit-тесты корзины, моделей заказа и фиксированной цены courier offer.

## Безопасность

- Firestore Rules дополнены коллекциями `partners` и `products`: чтение для signed-in, запись только admin, delete запрещён.
- Поля catalog order неизменяемы после создания.
- Для `priceNegotiable = false` courier offer обязан совпадать с client price.
- Rules локально компилируются в Firestore Emulator; deploy не выполнялся.

## Совместимость

- Существующий `customDelivery`, Customer MVP, Courier MVP, navigation, onboarding и Admin/Dispatch сохранены.
- Firebase project не изменялся; `firebase_options.dart` не изменялся.
- Локальный FlutterFire Android app id приведён к уже зарегистрированному client `tj.tajgo.app`.

## Ограничения пилота

- Товарный остаток — булев `isAvailable`, без количественного склада и резервирования.
- Оплата остаётся вне приложения; `total` — информационный расчёт.
- Маршрут зависит от внешнего provider и имеет direct-line fallback.
- Изображения задаются URL; Firebase Storage для партнёрского контента не добавлялся.
- Для production нужны release keystore, реальные fingerprints, ручной deploy Rules и физический multi-device тест.
