import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/app_user.dart';
import '../../core/models/courier_application.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'widgets/admin_access_gate.dart';

class AdminCourierApplicationDetailsScreen extends StatefulWidget {
  const AdminCourierApplicationDetailsScreen({super.key, required this.uid});
  final String uid;

  @override
  State<AdminCourierApplicationDetailsScreen> createState() =>
      _AdminCourierApplicationDetailsScreenState();
}

class _AdminCourierApplicationDetailsScreenState
    extends State<AdminCourierApplicationDetailsScreen> {
  bool _busy = false;

  Future<void> _action(
    String title,
    Future<void> Function(String? reason) action, {
    bool reasonRequired = false,
  }) async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (_) =>
          _DecisionDialog(title: title, reasonRequired: reasonRequired),
    );
    if (reason == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action(reason.isEmpty ? null : reason);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Решение сохранено.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error is StateError ? error.message : '$error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    final adminUid = scope.authService.currentUser!.uid;
    return AdminAccessGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Заявка курьера')),
        body: StreamBuilder<CourierApplication?>(
          stream: scope.courierApplicationRepository.applicationStream(
            widget.uid,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return const Center(child: Text('Заявка не найдена'));
            }
            final app = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Header(app: app),
                _Section(
                  title: 'Профиль',
                  children: [
                    _row('Имя', app.displayName),
                    _row('Телефон', app.phoneNumber ?? '—'),
                    _row('Дата рождения', app.birthDate ?? 'Не указана'),
                  ],
                ),
                _Section(
                  title: 'Транспорт и зона',
                  children: [
                    _row('Транспорт', CourierTransport.label(app.transport)),
                    _row('Город', app.city),
                    _row('Район', app.workDistrict),
                    _row('Доступность', app.availability),
                  ],
                ),
                _Section(
                  title: 'Документы',
                  children: [
                    _row(
                      'Документ',
                      CourierDocumentType.label(app.documentType),
                    ),
                    _row('Номер', app.documentNumber),
                    _row(
                      'Проверка фото',
                      app.verificationMethod == 'personalMeeting'
                          ? 'Личная встреча · Storage не включён'
                          : 'Storage',
                    ),
                    _row(
                      'Согласия',
                      app.termsAccepted && app.dataConsent ? 'Да' : 'Нет',
                    ),
                  ],
                ),
                if (app.rejectionReason != null)
                  _Section(
                    title: 'Последний отказ',
                    children: [_row('Причина', app.rejectionReason!)],
                  ),
                if (app.suspensionReason != null)
                  _Section(
                    title: 'Приостановка',
                    children: [_row('Причина', app.suspensionReason!)],
                  ),
                if (app.history.isNotEmpty)
                  _Section(
                    title: 'История решений',
                    children: app.history.reversed
                        .map(
                          (item) => ListTile(
                            dense: true,
                            title: Text(item['action'] as String? ?? 'Решение'),
                            subtitle: Text(
                              item['reason'] as String? ??
                                  'Без дополнительной причины',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 12),
                if (_busy) const LinearProgressIndicator(),
                if (app.status == CourierStatus.pending) ...[
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _action(
                            'Одобрить курьера?',
                            (_) => scope.courierApplicationRepository.approve(
                              uid: app.uid,
                              adminUid: adminUid,
                            ),
                          ),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Одобрить'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _action(
                            'Отклонить заявку?',
                            (reason) =>
                                scope.courierApplicationRepository.reject(
                                  uid: app.uid,
                                  adminUid: adminUid,
                                  reason: reason!,
                                ),
                            reasonRequired: true,
                          ),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Вернуть на исправление'),
                  ),
                ],
                if (app.status == CourierStatus.approved)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _action(
                            'Приостановить курьера?',
                            (reason) =>
                                scope.courierApplicationRepository.suspend(
                                  uid: app.uid,
                                  adminUid: adminUid,
                                  reason: reason!,
                                ),
                            reasonRequired: true,
                          ),
                    icon: const Icon(Icons.pause_circle_rounded),
                    label: const Text('Приостановить'),
                  ),
                if (app.status == CourierStatus.suspended)
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _action(
                            'Вернуть курьерский доступ?',
                            (_) => scope.courierApplicationRepository.restore(
                              uid: app.uid,
                              adminUid: adminUid,
                            ),
                          ),
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Вернуть на линию'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(String title, String value) => ListTile(
    dense: true,
    title: Text(title),
    subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.app});
  final CourierApplication app;

  @override
  Widget build(BuildContext context) => Card(
    color: TajGoColors.mint,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.delivery_dining_rounded)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text('Статус: ${_statusLabel(app.status)}'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          ...children,
        ],
      ),
    ),
  );
}

class _DecisionDialog extends StatefulWidget {
  const _DecisionDialog({required this.title, required this.reasonRequired});
  final String title;
  final bool reasonRequired;

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: widget.reasonRequired
        ? TextField(
            controller: _reason,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Причина',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          )
        : const Text('Действие будет записано в журнал администратора.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          final reason = _reason.text.trim();
          if (widget.reasonRequired && reason.length < 3) {
            setState(() => _error = 'Минимум 3 символа');
            return;
          }
          Navigator.pop(context, reason);
        },
        child: const Text('Подтвердить'),
      ),
    ],
  );
}

String _statusLabel(String status) => switch (status) {
  CourierStatus.pending => 'На проверке',
  CourierStatus.approved => 'Одобрен',
  CourierStatus.rejected => 'Нужно исправить',
  CourierStatus.suspended => 'Приостановлен',
  _ => 'Черновик',
};
