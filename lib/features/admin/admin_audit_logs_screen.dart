import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import 'widgets/admin_access_gate.dart';

class AdminAuditLogsScreen extends StatelessWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminAccessGate(
    child: Scaffold(
      appBar: AppBar(title: const Text('Журнал действий')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('admin_logs')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Журнал недоступен. Проверьте server admin-role и Firestore Rules.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Записей пока нет.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final createdAt = data['createdAt'];
              final time = createdAt is Timestamp
                  ? createdAt.toDate().toLocal().toString().substring(0, 16)
                  : 'время не указано';
              final target =
                  data['orderId'] ?? data['courierId'] ?? data['targetUid'];
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.history_rounded,
                    color: TajGoColors.darkGreen,
                  ),
                  title: Text(
                    data['action'] as String? ?? 'adminAction',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    [
                      time,
                      if (target != null) 'Объект: $target',
                      if (data['reason'] != null) 'Причина: ${data['reason']}',
                    ].join('\n'),
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
