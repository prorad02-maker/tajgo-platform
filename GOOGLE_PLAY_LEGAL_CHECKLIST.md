# Google Play legal URL checklist

Hosting deploy в Phase 1 не выполняется. После будущего owner-approved deploy
открыть каждую ссылку в обычном и инкогнито-окне телефона, без входа в TajGo.

- [ ] `https://tajgo.ru/privacy` — HTTP 200, HTTPS без warning, видны дата и
  версия, категории данных (phone/profile/address/location/order/FCM/crash),
  цели, Firebase processors, retention, права, удаление и контакт.
- [ ] `https://tajgo.ru/terms` — HTTP 200, указаны сервис, аккаунт, правила
  курьеров/заказов/цен, запреты, отмена/споры, доступность, контакт и версия.
- [ ] `https://tajgo.ru/support` — HTTP 200, виден рабочий email, инструкция по
  заказам/аккаунту, предупреждение не отправлять SMS/delivery codes и ссылка на
  удаление. Владелец подтверждает mailbox, часы и SLA ответа.
- [ ] `https://tajgo.ru/account-deletion` — HTTP 200 без login, форма открывает
  письмо на подтверждённый mailbox, описаны in-app path, данные удаления,
  retention и срок обработки. Проверить copy button на Android Chrome.
- [ ] Все четыре страницы mobile-friendly, имеют взаимные ссылки только на
  `https://tajgo.ru/*`, не содержат localhost, `example.invalid`, Firebase
  preview URL или текст «замените перед публикацией».
- [ ] Текст совпадает с фактическим Data Safety form, Firebase SDK flags,
  retention и in-app документами; legal/owner одобрили оператора, юрисдикцию,
  mailbox и дату вступления в силу.
- [ ] URL внесены в Play Console: Privacy Policy, Support URL и Account
  deletion URL; проверены из Play Console pre-launch report.
