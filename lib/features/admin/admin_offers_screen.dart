import '../../core/design/tajgo_money.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import 'widgets/admin_access_gate.dart';

class AdminOffersScreen extends StatelessWidget {
  const AdminOffersScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminAccessGate(
    child: Scaffold(
      appBar: AppBar(title: const Text('Предложения курьеров')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collectionGroup('offers')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _Message(
              icon: Icons.lock_outline_rounded,
              text:
                  'Не удалось загрузить предложения. Проверьте admin-role и Rules.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const _Message(
              icon: Icons.local_offer_outlined,
              text: 'Предложений пока нет.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final orderId = doc.reference.parent.parent?.id ?? '—';
              final price = data['proposedPrice'] ?? data['price'] ?? '—';
              final status = data['status'] as String? ?? 'unknown';
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: TajGoColors.mint,
                    child: Icon(
                      Icons.local_offer_rounded,
                      color: TajGoColors.darkGreen,
                    ),
                  ),
                  title: Text(
                    '${data['courierName'] ?? 'Курьер'} · ${price is num ? TajGoMoney.format(price) : 'Цена не указана'}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text('Заказ $orderId\nСтатус: $status'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: TajGoColors.green),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
