import 'package:flutter/material.dart';

enum OrderDetailsLoadState { loading, success, notFound, error }

OrderDetailsLoadState resolveOrderDetailsLoadState<T>(
  AsyncSnapshot<T?> snapshot,
) {
  if (snapshot.hasError) return OrderDetailsLoadState.error;
  if (snapshot.data != null) return OrderDetailsLoadState.success;
  if (snapshot.connectionState == ConnectionState.waiting ||
      snapshot.connectionState == ConnectionState.none) {
    return OrderDetailsLoadState.loading;
  }
  return OrderDetailsLoadState.notFound;
}

class OrderDetailsTerminalView extends StatelessWidget {
  const OrderDetailsTerminalView({
    super.key,
    required this.notFound,
    required this.onRetry,
    required this.onBack,
  });

  final bool notFound;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              notFound ? Icons.search_off_rounded : Icons.cloud_off_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              notFound ? 'Заказ не найден' : 'Не удалось загрузить заказ',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              notFound
                  ? 'Возможно, заказ был удалён или больше недоступен.'
                  : 'Проверьте интернет и права доступа, затем повторите.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('order-details-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
            TextButton(onPressed: onBack, child: const Text('Назад')),
          ],
        ),
      ),
    );
  }
}
