import 'package:flutter/material.dart';

import '../customer/customer_home_screen.dart';

class CourierApplicationStatusScreen extends StatelessWidget {
  const CourierApplicationStatusScreen({super.key, this.status = 'draft'});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (title, message, icon) = switch (status) {
      'pending' => (
        'Заявка на проверке',
        'Пока мы проверяем данные, клиентский режим доступен.',
        Icons.hourglass_top_rounded,
      ),
      'rejected' => (
        'Заявку нужно уточнить',
        'Причина и повторная отправка появятся вместе с анкетой в задаче 2.',
        Icons.info_outline_rounded,
      ),
      'suspended' => (
        'Режим курьера приостановлен',
        'Клиентский режим и ваши заказы остаются доступными.',
        Icons.pause_circle_outline_rounded,
      ),
      _ => (
        'Осталась короткая анкета — 3 минуты',
        'Анкета и проверка документов будут реализованы в задаче 2.',
        Icons.delivery_dining_rounded,
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Зарабатывать с TajGo')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 76),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => const CustomerHomeScreen(),
                  ),
                  (_) => false,
                ),
                child: const Text('Перейти к доставке'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
