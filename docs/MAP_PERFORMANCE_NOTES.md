# Map Performance Notes

- Поиск: debounce 320 мс, remote не вызывается для пустой строки.
- Reverse geocoding: только после `MapEventMoveEnd`; устаревший ответ игнорируется.
- Маршрут: не строится в `build()`, одинаковые запросы объединяются.
- Cache: road 8 минут, fallback 45 секунд.
- Курьер: recalculation ≥20–25 секунд и движение ≥120 м/off-route.
- Камера: предыдущая анимация отменяется; одинаковые вызовы в пределах 250 мс
  игнорируются.
- Tracking клиента не подгоняет камеру под каждый courier update.
- Dispatch рисует маршрут только выбранного заказа.
- Admin-фильтры скрывают ненужные слои до построения маркеров.

Следующий performance-этап: marker clustering при 30+ объектах, tile cache,
polyline simplification, профилирование raster/UI threads на слабом Android.
