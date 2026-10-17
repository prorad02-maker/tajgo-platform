/// Единый форматтер денежных сумм TajGo.
///
/// Пользователю всегда показываем сомони. Внутренняя валюта данных — `TJS`,
/// но код валюты и символы `₽`/`$` в интерфейс не выводим (см. спецификацию
/// v1.8 Part 2, этап 11).
class TajGoMoney {
  const TajGoMoney._();

  static const String unit = 'сомони';

  /// Форматирует сумму как «15 сомони» / «12,5 сомони».
  ///
  /// Целые значения выводятся без дробной части. Дробные (например, товар на
  /// вес) — с запятой-разделителем и максимум двумя знаками, без хвостовых нулей.
  static String format(num value, {bool withUnit = true}) {
    final amount = _amount(value);
    return withUnit ? '$amount $unit' : amount;
  }

  /// Короткая форма без единицы — для мест, где единица подписана отдельно.
  static String amount(num value) => _amount(value);

  static String _amount(num value) {
    final normalized = value.isNaN || value.isInfinite ? 0 : value;
    if (normalized == normalized.roundToDouble()) {
      return normalized.round().toString();
    }
    var text = normalized.toStringAsFixed(2);
    // Убираем хвостовые нули: 12.50 -> 12.5, 12.00 -> 12.
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    return text.replaceAll('.', ',');
  }
}
