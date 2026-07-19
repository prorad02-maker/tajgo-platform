import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/marketplace_partner.dart';
import '../../core/services/marketplace_import_service.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'widgets/admin_access_gate.dart';

class AdminMarketplaceImportScreen extends StatefulWidget {
  const AdminMarketplaceImportScreen({super.key});

  @override
  State<AdminMarketplaceImportScreen> createState() =>
      _AdminMarketplaceImportScreenState();
}

class _AdminMarketplaceImportScreenState
    extends State<AdminMarketplaceImportScreen> {
  final _service = const MarketplaceImportService();
  late final TextEditingController _json;
  MarketplaceCatalogImport? _preview;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _json = TextEditingController(text: _service.template());
  }

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  void _validate() {
    final repository = TajGoScope.of(context).marketplaceRepository;
    try {
      final catalog = _service.parse(
        _json.text,
        newPartnerId: repository.newPartnerId,
        newProductId: repository.newProductId,
      );
      setState(() {
        _preview = catalog;
        _error = null;
      });
    } catch (error) {
      setState(() {
        _preview = null;
        _error = error.toString();
      });
    }
  }

  Future<void> _publish() async {
    final preview = _preview;
    if (preview == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Записать каталог в Firestore?'),
        content: Text(
          'Партнёр «${preview.partner.name}» и ${preview.products.length} '
          'товаров будут созданы или обновлены. Удаления не выполняются.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Записать'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final scope = TajGoScope.of(context);
      final result = await scope.marketplaceRepository.importCatalog(
        catalog: preview,
        adminId: scope.authService.currentUser!.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.partnerCreated ? 'Партнёр создан' : 'Партнёр обновлён'} · '
            'товаров создано ${result.productsCreated}, '
            'обновлено ${result.productsUpdated}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminAccessGate(
    child: Scaffold(
      appBar: AppBar(title: const Text('Импорт каталога')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Card(
            color: TajGoColors.mint,
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Вставьте JSON одного заведения и его ассортимента. '
                'Сначала TajGo проверит данные и покажет preview; запись '
                'в Firestore начнётся только после подтверждения администратора.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _json,
            minLines: 16,
            maxLines: 28,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Catalog JSON · schemaVersion 1',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_preview != null || _error != null) {
                setState(() {
                  _preview = null;
                  _error = null;
                });
              }
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          _json.text = _service.template();
                          setState(() {
                            _preview = null;
                            _error = null;
                          });
                        },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Шаблон'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _validate,
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('Проверить'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFFFEBEE),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: TajGoColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (_preview case final preview?) ...[
            const SizedBox(height: 14),
            _ImportPreview(catalog: preview),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _publish,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(_busy ? 'Записываем…' : 'Записать в Firestore'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ImportPreview extends StatelessWidget {
  const _ImportPreview({required this.catalog});

  final MarketplaceCatalogImport catalog;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: TajGoColors.mint,
                child: Icon(
                  Icons.storefront_rounded,
                  color: TajGoColors.darkGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalog.partner.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${marketplaceCategoryLabel(catalog.partner.category)} · '
                      '${catalog.products.length} товаров · '
                      '${catalog.partner.address}',
                      style: const TextStyle(color: TajGoColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (catalog.warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final warning in catalog.warnings)
              Text(
                '⚠ $warning',
                style: const TextStyle(
                  color: TajGoColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
          const Divider(height: 24),
          for (final product in catalog.products.take(12))
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Expanded(child: Text(product.name)),
                  Text(
                    '${product.price} TJS',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          if (catalog.products.length > 12)
            Text(
              'Ещё товаров: ${catalog.products.length - 12}',
              style: const TextStyle(color: TajGoColors.muted),
            ),
        ],
      ),
    ),
  );
}
