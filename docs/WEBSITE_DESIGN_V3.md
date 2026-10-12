# TajGo: дизайн городской платформы

Новая версия опубликована 9 октября 2026 года в Firebase Hosting проекта `tajgo-4fcd0`: https://tajgo.ru/ (резервный адрес: https://tajgo-4fcd0.web.app/).

Сайт показывает предусмотренные приложением направления: каталог еды, продуктов и цветов, доставку посылок, работу с магазинами и курьерами. До выхода в Google Play на сайте указано, что приложение готовится к запуску. Обзор приложения выполнен в HTML/CSS и отмечен как иллюстрация возможностей; это не снимки экранов работающего заказа.

## Файлы

- `public/index.html` — главная страница.
- `public/styles.css` — адаптивная типографика, сетки и оформление всех страниц.
- `public/landing.js` — переключение обзора приложения с поддержкой клавиатуры.
- `public/tajgo-campaign-v3.jpg` — визуал главного экрана, 1122 × 1402, JPEG quality 88, около 213 КБ.
- `public/city-khujand.svg`, `public/city-dushanbe.svg` — иллюстрации городов, перенесённые из предыдущего варианта.
- `public/onest-variable.ttf`, `public/onest-OFL.txt` — локально обслуживаемый шрифт Onest и его лицензия SIL Open Font License. Источник: https://github.com/google/fonts/tree/main/ofl/onest.
- `build/website-preview/campaign-v3-source.png` — исходник брендового визуала.
- `build/website-preview/v2/` — предыдущие HTML, CSS и JavaScript. Полный предыдущий сайт также сохранён в ZIP `build/release/tajgo-site-20261009-141544.zip`.

## Генерация визуала

Использован встроенный инструмент `image_gen` по навыку `imagegen`, без CLI/API fallback. Оригинал сохранён также в `C:/Users/prora/.codex/generated_images/01a117d6-cdbb-7b43-bc32-03ac5998fb94/exec-60404fe0-ecef-432f-9f6f-7bb2bbcb1920.png`. JPEG — перекодирование для загрузки на сайте; композиция и размеры сохранены.

Финальный промпт:

> Use case: ads-marketing. Asset type: original premium brand photograph for the TajGo city delivery platform website. Create a sophisticated editorial campaign photograph, portrait 4:5 composition. Scene: warm sunlit Central Asian urban street with pale limestone facades, elegant arched entrance and a softly blurred distant mountain ridge, understated and believable. Subject: a young adult male courier, natural Central Asian appearance, standing casually at three-quarter angle, wearing an immaculate forest-green overshirt, neutral light T-shirt, lime-green cap, holding one clean kraft cardboard parcel; a lime delivery tote with the exact small word 'TajGo' rests next to him. Friendly composed expression, human and candid, not stock-photo smile. Cropped from mid thighs up, courier occupies center-right, plentiful calm negative space top and left. Style: high-end lifestyle editorial photography, 50mm lens, finely resolved linen and paper texture, soft film grain, warm muted stone and olive green palette, one crisp acid-lime accent, confident art direction and sculptural sunlight/shadows. Camera eye-level, elegant understated composition, background low detail. Constraints: photo only, no website interface or smartphone, no overlays, no badges, no headlines, no watermark, no other text except small TajGo on tote. No collage, no cartoon, no 3D rendering, no exaggerated neon, no generic futuristic skyline, no fake review or numbers. Generate an attractive realistic brand image suitable for a premium technology platform landing page.

## Проверка

`node scripts/check_website.mjs` проверяет страницы, локальные ресурсы, ссылки на якоря и canonical URL; проверено 135 ссылок. Мобильные размеры и переключение обзора проверены в браузере. После публикации главная страница на обоих доменах, CSS, JavaScript, брендовый визуал, шрифт и четыре страницы поддержки/юридической информации вернули HTTP 200; содержимое совпало с локальными файлами по SHA-256. Дизайн также проверен в браузере на `https://tajgo.ru/`.

Публикация выполнена командой `firebase.cmd deploy --only hosting --project tajgo-4fcd0 --non-interactive`. Для выгрузки на обычный статический хостинг: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/package_website.ps1`.

## Исправление мобильного отображения, 9 октября 2026 года

Ошибка со скриншотов воспроизведена при сочетании нового HTML со старым `styles.css` из Git HEAD: на ширине 390 px иконка логотипа получала стандартный размер SVG 300 × 150 px и чёрную заливку, шапка растягивалась до 403 px. До исправления сервер отдавал HTML и CSS с `Cache-Control: max-age=3600` по неизменным URL.

В ссылки на CSS и JavaScript добавлены версии по SHA-256 содержимого. `scripts/version_website_assets.mjs` обновляет эти ссылки перед каждой публикацией и упаковкой, а `scripts/check_website.mjs` отклоняет несовпадающие версии. Для HTML, CSS и JavaScript настроена перепроверка кеша; изображения и шрифт продолжают кешироваться. Настройка заголовков основана на [документации Firebase Hosting](https://firebase.google.com/docs/hosting/full-config#headers).

Все SVG-иконки получили собственные размеры и контур без заливки в HTML. Библиотека символов имеет нулевые размеры. Даже с принудительно подставленным старым CSS иконка теперь занимает 24 px вместо 300 px; с актуальным оформлением иконка логотипа — 20 px, шапка — около 75 px.

Проверены ширины 320, 360, 390, 412, 600, 768 и 1280 px: горизонтального переполнения нет. Проверены переключение сценариев, управление клавиатурой и FAQ. Это браузерная проверка адаптивных размеров, а не запуск на физическом Android-устройстве.

Исправление опубликовано в Firebase Hosting. На основном и резервном доменах проверены HTTP 200, совпадение файлов с локальными по SHA-256 и новые заголовки кеширования. Снимок опубликованной страницы на ширине 390 px: `build/website-preview/mobile-fix-published.png`. Для однократного обхода ранее сохранённого HTML: https://tajgo.ru/?v=20261009-mobile.
