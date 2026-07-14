import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.currentMode});
  final String currentMode;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Настройки')),
    body: ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline_rounded),
          title: const Text('Режим аккаунта'),
          subtitle: Text(currentMode == 'courier' ? 'Курьер' : 'Клиент'),
        ),
        const ListTile(
          leading: Icon(Icons.location_on_outlined),
          title: Text('Геолокация'),
          subtitle: Text('Разрешение управляется в настройках телефона'),
        ),
        const ListTile(
          leading: Icon(Icons.brightness_auto_rounded),
          title: Text('Тема'),
          subtitle: Text('Системная'),
        ),
        const ListTile(
          leading: Icon(Icons.language_rounded),
          title: Text('Язык'),
          subtitle: Text('Русский'),
        ),
        const ListTile(
          leading: Icon(Icons.delete_outline_rounded),
          title: Text('Удалить аккаунт'),
          subtitle: Text(
            'Напишите в поддержку — данные не удаляются автоматически',
          ),
        ),
      ],
    ),
  );
}
