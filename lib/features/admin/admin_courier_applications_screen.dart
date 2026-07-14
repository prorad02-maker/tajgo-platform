import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/app_user.dart';
import '../../core/models/courier_application.dart';
import '../../shared/widgets/tajgo_badge.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'admin_courier_application_details_screen.dart';
import 'widgets/admin_access_gate.dart';

class AdminCourierApplicationsScreen extends StatefulWidget {
  const AdminCourierApplicationsScreen({super.key});

  @override
  State<AdminCourierApplicationsScreen> createState() =>
      _AdminCourierApplicationsScreenState();
}

class _AdminCourierApplicationsScreenState
    extends State<AdminCourierApplicationsScreen> {
  String _filter = CourierStatus.pending;

  @override
  Widget build(BuildContext context) => AdminAccessGate(
    child: Scaffold(
      appBar: AppBar(title: const Text('Заявки курьеров')),
      body: StreamBuilder<List<CourierApplication>>(
        stream: TajGoScope.of(
          context,
        ).courierApplicationRepository.applicationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Не хватает прав для чтения заявок. Проверьте Firestore Rules.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final all = snapshot.data ?? const <CourierApplication>[];
          final applications = _filter == 'all'
              ? all
              : all.where((app) => app.status == _filter).toList();
          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    _chip('На проверке', CourierStatus.pending),
                    _chip('Черновики', CourierStatus.draft),
                    _chip('Одобрены', CourierStatus.approved),
                    _chip('Исправить', CourierStatus.rejected),
                    _chip('Приостановлены', CourierStatus.suspended),
                    _chip('Все', 'all'),
                  ],
                ),
              ),
              Expanded(
                child: applications.isEmpty
                    ? const Center(child: Text('Заявок с таким статусом нет'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: applications.length,
                        itemBuilder: (context, index) =>
                            _ApplicationCard(application: applications[index]),
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _chip(String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    ),
  );
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application});
  final CourierApplication application;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: CircleAvatar(
        backgroundColor: TajGoColors.mint,
        child: const Icon(
          Icons.delivery_dining_rounded,
          color: TajGoColors.darkGreen,
        ),
      ),
      title: Text(
        application.displayName,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${application.phoneNumber ?? 'Телефон не указан'}\n'
        '${CourierTransport.label(application.transport)} · '
        '${_date(application.submittedAt)}',
      ),
      isThreeLine: true,
      trailing: TajGoBadge(
        text: _label(application.status),
        background: application.status == CourierStatus.pending
            ? TajGoColors.warning
            : TajGoColors.soonBg,
        foreground: TajGoColors.ink,
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              AdminCourierApplicationDetailsScreen(uid: application.uid),
        ),
      ),
    ),
  );

  String _date(DateTime? date) => date == null
      ? 'Не отправлена'
      : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  String _label(String status) => switch (status) {
    CourierStatus.pending => 'pending',
    CourierStatus.approved => 'approved',
    CourierStatus.rejected => 'исправить',
    CourierStatus.suspended => 'suspended',
    _ => 'draft',
  };
}
