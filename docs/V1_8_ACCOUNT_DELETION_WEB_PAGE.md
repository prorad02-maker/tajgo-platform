# TajGo v1.8 — Account Deletion Web Page

Статус: страница готова (`public/account-deletion.html`), требует хостинга владельцем.

## Назначение

Google Play и App Store требуют публичный URL, где пользователь может узнать, как
удалить аккаунт и данные, **без установки приложения**. Этот URL указывается в
Google Play Data Safety («Account deletion») и в App Store App Privacy / App
Review notes.

## Файл

`public/account-deletion.html` — самодостаточная статическая страница:

- объясняет два способа удаления (в приложении и через поддержку);
- перечисляет удаляемые/обезличиваемые и сохраняемые категории данных;
- указывает срок обработки (в приложении — сразу; через поддержку — до 30 дней) и
  срок хранения обезличенных записей (до 24 месяцев);
- содержит краткий текст на таджикском;
- **не собирает** пароли, коды из SMS или иные учётные данные;
- theme-aware (светлая/тёмная), адаптивная.

## Что заменить перед публикацией (владелец)

1. `support@tajgo.tj` — на действующий адрес поддержки (в двух местах: mailto и
   футер).
2. Домен/бренд контакт при необходимости.
3. Срок хранения (24 месяца) — привести в соответствие с финальной политикой
   хранения (`V1_8_PRIVACY_DATA_INVENTORY.md`).

## Хостинг (варианты для владельца)

- Firebase Hosting: положить файл как `account-deletion.html` (или
  `index.html` в отдельном сайте) и задеплоить (`firebase deploy --only
  hosting`). Firebase-хостинг не входит в текущий репозиторий и требует отдельной
  настройки владельцем — deploy в этой задаче не выполняется.
- Любой статический хостинг (GitHub Pages, Netlify, собственный сервер).

Итоговый URL, например: `https://tajgo.tj/account-deletion` или
`https://<project>.web.app/account-deletion.html`.

## Куда вписать URL

- Google Play Console → App content → Data safety → «Provide a way for users to
  request that their data be deleted» → Deletion URL.
- App Store Connect → App Privacy → (при необходимости) Account deletion.
- В приложении: раздел «Безопасность и данные» уже даёт in-app-удаление; ссылка
  на web-страницу может быть добавлена в блок Privacy/Support (P0.2).

## Согласованность с приложением

Формулировки категорий на странице совпадают с `AccountDeletionScreen` и с
Function `deleteAccountRequest` (см. `V1_8_ACCOUNT_DELETION_ARCHITECTURE.md`).
При изменении политики обновлять оба места.
