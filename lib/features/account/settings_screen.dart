import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/external_navigator_service.dart';
import '../../core/services/user_error_message.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../../shared/widgets/tajgo_state_view.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.currentMode});
  final String currentMode;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  NavigatorPreference? _navigator;
  bool _started = false;
  bool _saving = false;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final value = await TajGoScope.of(
        context,
      ).externalNavigatorService.load();
      if (mounted) setState(() => _navigator = value);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _save(NavigatorPreference value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await TajGoScope.of(context).externalNavigatorService.save(value);
      if (mounted) setState(() => _navigator = value);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openLocationSettings() async {
    try {
      if (await Geolocator.openAppSettings()) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Откройте настройки телефона → TajGo → Геолокация.'),
        ),
      );
    }
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
      body: _error != null
          ? TajGoStateView(
              icon: Icons.settings_outlined,
              title: 'Не удалось открыть настройки',
              message: userErrorMessage(_error),
              onRetry: _load,
            )
          : ListView(
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
                  subtitle: Text(
                    'Координаты точки A или B — без телефона и кода',
                  ),
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
                      onTap: _saving
                          ? null
                          : () {
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
                    onChanged: _saving
                        ? null
                        : (value) => _save(
                            NavigatorPreference(
                              navigator: preference.navigator,
                              askEveryTime: value,
                              openAutomaticallyAfterAccept: false,
                            ),
                          ),
                  ),
                ],
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Геолокация'),
                  subtitle: const Text(
                    'Открыть разрешения TajGo в настройках телефона',
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: _openLocationSettings,
                ),
                const ListTile(
                  leading: Icon(Icons.brightness_auto_rounded),
                  title: Text('Тема'),
                  subtitle: Text('Светлая'),
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
