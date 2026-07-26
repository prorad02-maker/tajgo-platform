import 'package:flutter/material.dart';

import '../../shared/design/tajgo_components.dart';
import 'account_deletion_screen.dart';

/// Раздел «Безопасность и данные»: точка входа к удалению аккаунта и краткая
/// сводка по данным. Политика/Условия добавляются рядом в блоке Privacy.
class SecurityDataScreen extends StatelessWidget {
  const SecurityDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TajGoScaffold(
      appBar: const TajGoAppBar(title: 'Безопасность и данные'),
      body: ListView(
        padding: const EdgeInsets.all(TajGoSpacing.lg),
        children: [
          TajGoCard(
            padding: const EdgeInsets.all(TajGoSpacing.lg),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: TajGoColors.green,
                  size: TajGoIconSizes.xl,
                ),
                const SizedBox(width: TajGoSpacing.md),
                Expanded(
                  child: Text(
                    'Мы храним минимум данных, необходимых для доставки. '
                    'Вы можете удалить аккаунт в любой момент.',
                    style: TajGoTypography.body,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TajGoSpacing.lg),
          TajGoCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.delete_forever_rounded,
                color: TajGoColors.error,
              ),
              title: Text(
                'Удалить аккаунт',
                style: TajGoTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: TajGoColors.error,
                ),
              ),
              subtitle: Text(
                'Обезличивание данных и завершение входа',
                style: TajGoTypography.caption,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AccountDeletionScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
