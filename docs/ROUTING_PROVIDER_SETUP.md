# Routing provider: настройка для пилота

Внешний routing по умолчанию выключен. Приложение всегда собирается и создаёт
заказы без него: `DirectRouteProvider` строит честно помеченный предварительный
маршрут. Firebase, Phone Auth и applicationId от routing не зависят.

## Переменные запуска

| Параметр | Значение |
|---|---|
| `ROUTING_ENABLED` | `true` включает road provider |
| `ROUTING_PROVIDER` | `osrm` или `graphhopper` |
| `ROUTING_BASE_URL` | абсолютный URL без ключа в строке |
| `ROUTING_API_KEY` | необязательный локальный секрет |
| `ROUTING_TIMEOUT_SECONDS` | обычно `7` |
| `ROUTING_MODE` | `walking`, `bicycle`, `scooter`, `car` |

Старые имена `TAJGO_ROUTE_*` сохранены для обратной совместимости. Новые
`ROUTING_*` имеют приоритет.

```powershell
flutter run -d <DEVICE_ID> `
  --dart-define=ROUTING_ENABLED=true `
  --dart-define=ROUTING_PROVIDER=osrm `
  --dart-define=ROUTING_BASE_URL=https://routing.example.tj `
  --dart-define=ROUTING_TIMEOUT_SECONDS=7 `
  --dart-define=ROUTING_MODE=bicycle
```

Можно скопировать `tool/routing.example.json` в `tool/routing.local.json`,
заполнить локально и выполнить:

```powershell
flutter run -d <DEVICE_ID> --dart-define-from-file=tool/routing.local.json
```

`routing.local.json` игнорируется Git. Ключи нельзя помещать в исходники,
скриншоты, issue или документацию.

## OSRM-совместимость

Запрос использует координаты `lng,lat`, `overview=full`,
`geometries=geojson`, `steps=true`, `language=ru`. Ответ разбирает geometry,
distance, duration, legs, steps и maneuver. Неуспешный HTTP, timeout, плохой
JSON или OSRM code не `Ok` переводятся в безопасный fallback.

## Debug Health

В debug-сборке откройте Demo Tools → **Routing & Map Health**. Карточка показывает
конфигурацию, число запросов, успехи, fallback, cache hits, latency и медленные
операции. Кнопка «Проверить routing provider» строит тестовый маршрут Худжанда.
Release-интерфейс эту диагностику не показывает.

Для production нужен управляемый endpoint/коммерческий SLA, rate limits,
server-side cache, мониторинг доступности и юридическая проверка условий
провайдера. Публичный demo OSRM нельзя считать production SLA.
