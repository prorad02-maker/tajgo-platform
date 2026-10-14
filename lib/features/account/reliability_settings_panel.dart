import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/diagnostic_service.dart';
import '../../core/services/order_notification_service.dart';

class ReliabilitySettingsPanel extends StatefulWidget {
  const ReliabilitySettingsPanel({
    super.key,
    required this.notifications,
    required this.diagnostics,
  });
  final OrderNotificationService notifications;
  final DiagnosticService diagnostics;
  @override
  State<ReliabilitySettingsPanel> createState() =>
      _ReliabilitySettingsPanelState();
}

class _ReliabilitySettingsPanelState extends State<ReliabilitySettingsPanel> {
  @override
  void initState() {
    super.initState();
    widget.notifications.addListener(_changed);
    widget.diagnostics.addListener(_changed);
    unawaited(widget.notifications.initialize());
    unawaited(widget.diagnostics.initialize());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.notifications.removeListener(_changed);
    widget.diagnostics.removeListener(_changed);
    super.dispose();
  }

  Future<void> _openPermissions() async {
    try {
      if (await openAppSettings()) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Откройте настройки телефона → TajGo → Уведомления.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = widget.notifications,
        diagnostics = widget.diagnostics;
    return Column(
      children: [
        SwitchListTile(
          value: notifications.enabled,
          title: const Text('Уведомления о заказах'),
          subtitle: Text(
            !notifications.supported
                ? 'Доступны в Android-приложении'
                : notifications.permissionDenied
                ? 'Разрешите уведомления в настройках телефона'
                : 'Предложения курьеров и изменения доставки',
          ),
          onChanged:
              !notifications.supported ||
                  !notifications.allowed ||
                  notifications.busy
              ? null
              : notifications.setEnabled,
        ),
        if (notifications.permissionDenied)
          ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: const Text('Разрешения телефона'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: _openPermissions,
          ),
        if (notifications.error != null)
          ListTile(
            title: Text(notifications.error!),
            trailing: IconButton(
              tooltip: 'Повторить',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: notifications.busy ? null : notifications.refresh,
            ),
          ),
        SwitchListTile(
          value: diagnostics.enabled,
          title: const Text('Технические отчёты об ошибках'),
          subtitle: Text(
            diagnostics.supported
                ? 'Помогают исправлять сбои. Приложение не добавляет данные заказов в отчёты.'
                : 'Доступны в Android-приложении',
          ),
          onChanged:
              !diagnostics.supported || !diagnostics.allowed || diagnostics.busy
              ? null
              : diagnostics.setEnabled,
        ),
        if (diagnostics.error != null)
          ListTile(
            title: Text(diagnostics.error!),
            trailing: IconButton(
              tooltip: 'Повторить',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: diagnostics.busy ? null : diagnostics.retry,
            ),
          ),
      ],
    );
  }
}
