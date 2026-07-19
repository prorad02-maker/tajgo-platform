import 'package:flutter/material.dart';

import '../../core/services/external_navigator_service.dart';
import '../../shared/widgets/tajgo_scope.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.currentMode});
  final String currentMode;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  NavigatorPreference? _navigator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_navigator == null) {
      TajGoScope.of(context).externalNavigatorService.load().then((value) {
        if (mounted) setState(() => _navigator = value);
      });
    }
  }

  Future<void> _save(NavigatorPreference value) async {
    await TajGoScope.of(context).externalNavigatorService.save(value);
    if (mounted) setState(() => _navigator = value);
  }

  String _label(ExternalNavigator value) => switch (value) {
    ExternalNavigator.tajgo => 'TajGo',
    ExternalNavigator.yandex => 'Яндекс Навигатор',
    ExternalNavigator.google => 'Google Maps',
    ExternalNavigator.twoGis => '2GIS',
    ExternalNavigator.system => 'Системный навигатор',
  };

  @override
  Widget build(BuildContext context) {
    final preference = _navigator;
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: const Text('Режим аккаунта'),
            subtitle: Text(
              widget.currentMode == 'courier' ? 'Курьер' : 'Клиент',
            ),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.navigation_rounded),
            title: Text('Навигатор курьера'),
            subtitle: Text('Координаты точки A или B — без телефона и кода'),
          ),
          if (preference == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            ...ExternalNavigator.values.map(
              (value) => ListTile(
                leading: Icon(
                  value == preference.navigator
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                ),
                title: Text(_label(value)),
                onTap: () {
                  _save(
                    NavigatorPreference(
                      navigator: value,
                      askEveryTime: preference.askEveryTime,
                      openAutomaticallyAfterAccept: false,
                    ),
                  );
                },
              ),
            ),
            SwitchListTile(
              value: preference.askEveryTime,
              title: const Text('Спрашивать каждый раз'),
              onChanged: (value) => _save(
                NavigatorPreference(
                  navigator: preference.navigator,
                  askEveryTime: value,
                  openAutomaticallyAfterAccept: false,
                ),
              ),
            ),
            const SwitchListTile(
              value: false,
              onChanged: null,
              title: Text('Открывать автоматически после принятия'),
              subtitle: Text('Выключено для пилота'),
            ),
          ],
          const Divider(),
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
        ],
      ),
    );
  }
}
