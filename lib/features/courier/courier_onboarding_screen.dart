import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'courier_home_screen.dart';

class CourierOnboardingScreen extends StatefulWidget {
  const CourierOnboardingScreen({super.key});

  @override
  State<CourierOnboardingScreen> createState() =>
      _CourierOnboardingScreenState();
}

class _CourierOnboardingScreenState extends State<CourierOnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _busy = false;
  String? _error;

  static const _pages = [
    (
      Icons.sensors_rounded,
      'Выходите на линию',
      'Включите тумблер, когда готовы. Координаты передаются только во время работы.',
    ),
    (
      Icons.inventory_2_rounded,
      'Принимайте заказ',
      'Маршрут и доход видны до принятия. Одновременно — только один активный заказ.',
    ),
    (
      Icons.map_rounded,
      'Карта ведёт вас',
      'Сначала к точке A, затем к B. Кнопки работают рядом с нужной точкой и при включённом GPS.',
    ),
    (
      Icons.password_rounded,
      'Код — это деньги',
      'Передавайте заказ по коду клиента. Доход начисляется после подтверждения. Будьте вежливы и берегите данные клиента.',
    ),
  ];

  Future<void> _finish() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final scope = TajGoScope.of(context);
      final uid = scope.authService.currentUser!.uid;
      await scope.courierApplicationRepository.completeOnboarding(uid);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const CourierHomeScreen()),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Не удалось завершить знакомство. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Как работать с TajGo'),
      actions: [
        TextButton(
          onPressed: _busy ? null : _finish,
          child: const Text('Пропустить'),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) {
                final item = _pages[index];
                return Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: TajGoColors.mint,
                        child: Icon(
                          item.$1,
                          size: 54,
                          color: TajGoColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        item.$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.$3,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          color: TajGoColors.muted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => Container(
                width: index == _page ? 22 : 8,
                height: 8,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: index == _page
                      ? TajGoColors.darkGreen
                      : TajGoColors.soonBg,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text(
                _error!,
                style: const TextStyle(color: TajGoColors.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: FilledButton(
              onPressed: _busy
                  ? null
                  : _page == _pages.length - 1
                  ? _finish
                  : () => _controller.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
              child: _busy
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Text(
                      _page == _pages.length - 1
                          ? 'Выйти на линию 🟢'
                          : 'Дальше',
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}
