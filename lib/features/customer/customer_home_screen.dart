import 'package:flutter/material.dart';

import 'customer_shell.dart';

/// Корневой экран клиента. Сохранён как стабильная точка входа для роутера и
/// переключения режимов; вся навигация живёт в [CustomerShell].
class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const CustomerShell();
}
