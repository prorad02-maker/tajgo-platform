# Routing provider: текущая настройка

Дорожный routing включён в обычной сборке: OSRM на
`https://routing.openstreetmap.de`, велосипедный режим. Для этого публичного
сервиса TajGo автоматически выбирает `routed-bike` / `routed-car` и URL-профиль
`driving`. При ошибке `DirectRouteProvider` показывает явно отмеченный
предварительный маршрут. Firebase и Phone Auth от routing не зависят.

## Переменные запуска

| Параметр | Значение |
|---|---|
| `ROUTING_ENABLED` | `true` по умолчанию; `false` выключает road provider |
| `ROUTING_PROVIDER` | `osrm` или `graphhopper` |
| `ROUTING_BASE_URL` | абсолютный URL без ключа в строке |
| `ROUTING_API_KEY` | необязательный локальный секрет |
| `ROUTING_TIMEOUT_SECONDS` | обычно `7` |
| `ROUTING_MODE` | `walking`, `bicycle`, `scooter`, `car` |
| `ROUTING_PROFILE` | необязательное имя profile в URL OSRM |

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

Пилотная debug APK с тем же конфигом:

```powershell
flutter build apk --debug --dart-define-from-file=tool/routing.pilot.json
```

`tool/routing.pilot.json` — публичная конфигурация лёгкого тестового OSRM без
секрета. `routing.local.json` игнорируется Git и предназначен для частного или
договорного endpoint. Ключи нельзя помещать в исходники,
скриншоты, issue или документацию.

Обычная команда `flutter run` уже использует дорожный provider. Define-файл
нужен только для выбора собственного сервиса или изменения настроек.

## OSRM-совместимость

Запрос использует координаты строго `longitude,latitude`, `overview=full`,
`geometries=geojson`, `steps=true`. Русские подсказки манёвров формируются
локально: параметр `language` намеренно не отправляется, потому что публичный
FOSSGIS OSRM отвечает HTTP 400 на неподдерживаемые query-параметры. Ответ разбирает geometry,
distance, duration, legs, steps и maneuver. Неуспешный HTTP, timeout, плохой
JSON или OSRM code не `Ok` переводятся в безопасный fallback.

По умолчанию профили: walking → `foot`, bicycle/scooter → `bike`, car →
`driving`. `ROUTING_MODE` выбирает режим. Некоторые серверы используют отдельный
URL для велосипедного графа, но требуют слово `driving` в OSRM API path. Для них
задайте `ROUTING_PROFILE=driving`. Endpoint обязан
поддерживать соответствующее имя профиля; иначе TajGo спокойно перейдёт на
fallback и запишет причину в debug health.

Пилотный пример использует `routing.openstreetmap.de/routed-bike`. Это публичный
FOSSGIS-сервис только для лёгкого тестирования: максимум один запрос в секунду,
валидный User-Agent, обязательная OpenStreetMap attribution, без scraping и
heavy usage. Для production нужен свой endpoint или договорной SLA.

## Debug Health

В debug-сборке откройте Demo Tools → **Routing & Map Health**. Карточка показывает
конфигурацию, число запросов, успехи, fallback, cache hits, latency и медленные
операции. Кнопка «Проверить routing provider» строит тестовый маршрут Худжанда.
Release-интерфейс эту диагностику не показывает.

Для production нужен управляемый endpoint/коммерческий SLA, rate limits,
server-side cache, мониторинг доступности и юридическая проверка условий
провайдера. Публичный demo OSRM нельзя считать production SLA.
