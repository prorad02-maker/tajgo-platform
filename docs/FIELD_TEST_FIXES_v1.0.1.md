# v1.0.1 Field Test Fixes

## Почему маршрут шёл через дома

Сборка была запущена без `ROUTING_ENABLED=true` и `ROUTING_BASE_URL`, поэтому
правильно включился `DirectRouteProvider`. Он соединяет A/B прямой линией и не
является дорожной навигацией. Дополнительно UI некоторых экранов ошибочно
считал отсутствие route успешным road-route и писал «Маршрут построен».

В v1.0.1 только `RouteQuality.road` считается дорожным маршрутом. Road рисуется
сплошной зелёной линией. `directFallback`, `providerError`, `approximate` и
route `null` рисуются предупреждающим пунктиром и называются «Маршрут
предварительный». Техническая причина видна только в debug health.

Короткие дистанции теперь отображаются в метрах: `30 м`, `400 м`; начиная с
1 км — `1.2 км`. ETA не бывает меньше `≈ 1 мин`.

## Диагностика

Demo Tools → Routing & Map Health показывает enabled/configured, provider,
наличие base URL, безопасный request URL без API key, HTTP status, parse result,
points count, distance, ETA, route quality и fallback reason.

Для pilot debug используется проверенный велосипедный endpoint
`routing.openstreetmap.de/routed-bike` с `ROUTING_PROFILE=driving`. Локальный
конфиг передаётся при сборке через `--dart-define-from-file`; обычная сборка без
defines по-прежнему безопасно работает в fallback.

## Splash

PNG сохраняется как брендовый фон, но его нижняя статичная область закрывается
градиентной панелью. Поверх неё Flutter рисует единственный динамический
progress. Он стартует с 0, за 1.5 сек идёт к 90%, ждёт bootstrap при необходимости
и после готовности плавно завершается до 100%. Минимальный видимый интервал —
около 1.4–1.7 сек. После 100% открывается RoleScreen.
