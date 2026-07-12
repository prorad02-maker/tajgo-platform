# TajGo Map Interactive v2

Добавлено:
- текущее местоположение;
- центрирование карты;
- маркер пользователя;
- выбор точки долгим нажатием;
- преобразование координат в адрес;
- сохранение точки в Firestore;
- разделение на model / service / repository / screen.

Firestore: `users/{uid}/saved_locations/selected_delivery_point`

Следующий этап: «Откуда» → «Куда» → маршрут → расстояние → время → стоимость.
