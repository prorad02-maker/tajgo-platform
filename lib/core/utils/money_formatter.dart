String formatMoney(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

num roundMoney(num value) => (value * 100).round() / 100;
