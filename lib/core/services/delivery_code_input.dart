bool isValidDeliveryCodeInput(String value) =>
    RegExp(r'^\d{4}$').hasMatch(value.trim());
