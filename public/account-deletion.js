(function () {
  "use strict";
  var supportEmail = "support@tajgo.ru";
  var form = document.getElementById("deletion-form");
  var status = document.getElementById("form-status");

  if (!form) return;

  form.addEventListener("submit", function (event) {
    event.preventDefault();
    if (!form.reportValidity()) return;

    var phone = document.getElementById("phone").value.trim();
    var reason = document.getElementById("reason").value.trim();
    var subject = "Запрос на удаление аккаунта TajGo";
    var body = [
      "Прошу удалить мой аккаунт TajGo и связанные персональные данные.",
      "",
      "Номер телефона аккаунта: " + phone,
      "Причина: " + (reason || "не указана"),
      "",
      "Я подтверждаю, что хочу удалить этот аккаунт. Готов(а) подтвердить владение номером."
    ].join("\n");

    status.textContent = "Открываем почтовое приложение. Если оно не открылось, напишите на " + supportEmail + ".";
    window.location.href = "mailto:" + supportEmail + "?subject=" + encodeURIComponent(subject) + "&body=" + encodeURIComponent(body);
  });
}());
