import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import 'widgets/admin_access_gate.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminAccessGate(
    child: Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(
                Icons.security_rounded,
                color: TajGoColors.darkGreen,
              ),
              title: Text(
                'Защищённый режим',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Доступ определяется users/{uid}.role = admin или custom claim. '
                'Назначить admin из приложения нельзя.',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.cloud_done_rounded,
                color: TajGoColors.darkGreen,
              ),
              title: Text(
                'Authoritative Core',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Критические действия заказов выполняются Cloud Functions. '
                'Rules и Functions публикуются владельцем отдельно.',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
