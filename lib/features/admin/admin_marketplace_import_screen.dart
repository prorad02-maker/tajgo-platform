import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/models/marketplace_partner.dart';
import '../../core/models/marketplace_product.dart';
import '../../core/services/authoritative_command_service.dart';
import '../../core/services/marketplace_import_service.dart';
import '../../core/services/marketplace_table_import_service.dart';
import '../../shared/design/tajgo_components.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'widgets/admin_access_gate.dart';

/// Импорт прайса: JSON (партнёр + товары) или CSV/XLSX (товары для выбранного
/// партнёра). Dry-run с ошибками по строкам; запись — через authoritative
/// Function только после подтверждения.
class AdminMarketplaceImportScreen extends StatefulWidget {
  const AdminMarketplaceImportScreen({super.key});

  @override
  State<AdminMarketplaceImportScreen> createState() =>
      _AdminMarketplaceImportScreenState();
}

class _AdminMarketplaceImportScreenState
    extends State<AdminMarketplaceImportScreen> {
  final _jsonService = const MarketplaceImportService();
  final _tableService = const MarketplaceTableImportService();
  late final TextEditingController _json;

  MarketplacePartner? _selectedPartner;
  MarketplaceCatalogImport? _preview;
  List<ImportRowIssue> _issues = const [];
  int _newCount = 0;
  int _updateCount = 0;
  String? _fileName;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _json = TextEditingController(text: _jsonService.template());
  }

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  void _reset() {
    _preview = null;
    _issues = const [];
    _error = null;
    _newCount = 0;
    _updateCount = 0;
  }

  void _parseJsonText() {
    final repository = TajGoScope.of(context).marketplaceRepository;
    setState(() {
      try {
        final catalog = _jsonService.parse(
          _json.text,
          newPartnerId: repository.newPartnerId,
          newProductId: repository.newProductId,
        );
        _reset();
        _preview = catalog;
        _fileName = null;
      } catch (error) {
        _reset();
        _error = error.toString();
      }
    });
  }

  Future<void> _pickFile() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Прайс',
            extensions: ['json', 'csv', 'xlsx'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      final ext = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : '';
      if (ext == 'json') {
        final content = await file.readAsString();
        _json.text = content;
        _parseJsonText();
        setState(() => _fileName = file.name);
        return;
      }
      if (ext != 'csv' && ext != 'xlsx') {
        setState(() {
          _reset();
          _error = 'Поддерживаются файлы JSON, CSV и XLSX.';
        });
        return;
      }
      final partner = _selectedPartner;
      if (partner == null) {
        setState(() {
          _reset();
          _error = 'Сначала выберите партнёра для CSV/XLSX.';
        });
        return;
      }
      final table = ext == 'csv'
          ? _tableService.parseCsv(await file.readAsString())
          : _tableService.parseXlsx(await file.readAsBytes());
      final result = _tableService.productsFromTable(
        table,
        partnerId: partner.id,
      );
      await _prepareTablePreview(partner, result, file.name);
    } catch (error) {
      if (mounted) {
        setState(() {
          _reset();
          _error = 'Не удалось прочитать файл: $error';
        });
      }
    }
  }

  Future<void> _prepareTablePreview(
    MarketplacePartner partner,
    TableImportResult result,
    String fileName,
  ) async {
    final repository = TajGoScope.of(context).marketplaceRepository;
    // Сопоставляем товары по SKU с существующими (обновление) либо новый id.
    final existing = await repository.partnerProductsOnce(partner.id);
    final bySku = {
      for (final p in existing)
        if (p.sku.isNotEmpty) p.sku.toLowerCase(): p.id,
    };
    var created = 0;
    var updated = 0;
    final resolved = result.products.map((product) {
      final existingId = product.sku.isEmpty
          ? null
          : bySku[product.sku.toLowerCase()];
      if (existingId != null) {
        updated++;
        return product.copyWith(id: existingId);
      }
      created++;
      return MarketplaceProduct(
        id: repository.newProductId(),
        partnerId: product.partnerId,
        name: product.name,
        description: product.description,
        imageUrl: product.imageUrl,
        price: product.price,
        oldPrice: product.oldPrice,
        unit: product.unit,
        sku: product.sku,
        isAvailable: product.isAvailable,
        hidden: product.hidden,
        popularity: product.popularity,
        sortOrder: product.sortOrder,
      );
    }).toList(growable: false);
    if (!mounted) return;
    setState(() {
      _reset();
      _fileName = fileName;
      _issues = result.issues;
      _newCount = created;
      _updateCount = updated;
      _preview = resolved.isEmpty
          ? null
          : MarketplaceCatalogImport(
              partner: partner,
              products: resolved,
              warnings: result.warnings,
            );
      if (resolved.isEmpty && result.issues.isNotEmpty) {
        _error = 'Валидных строк нет — исправьте ошибки и повторите.';
      }
    });
  }

  Future<void> _publish() async {
    final preview = _preview;
    if (preview == null || _busy) return;
    final ok = await showTajGoConfirmation(
      context: context,
      title: 'Записать каталог?',
      message: 'Партнёр «${preview.partner.name}» и ${preview.products.length} '
          'товаров будут созданы или обновлены. Удаления не выполняются.',
      confirmLabel: 'Записать',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final scope = TajGoScope.of(context);
      await scope.marketplaceRepository.importCatalog(
        catalog: preview,
        adminId: scope.authService.currentUser!.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Импортировано товаров: ${preview.products.length}'),
        ),
      );
      setState(_reset);
    } on TajGoCommandException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Не удалось записать. Повторите.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = TajGoScope.of(context).marketplaceRepository;
    return AdminAccessGate(
      child: TajGoScaffold(
        appBar: const TajGoAppBar(title: 'Импорт каталога'),
        body: ListView(
          padding: const EdgeInsets.all(TajGoSpacing.lg),
          children: [
            Text(
              'JSON — заведение и товары. CSV/XLSX — товары для выбранного '
              'партнёра (столбцы: sku, name, price, unit, oldPrice, description, '
              'stockStatus, sortOrder).',
              style: TajGoTypography.caption,
            ),
            const SizedBox(height: TajGoSpacing.md),
            StreamBuilder<List<MarketplacePartner>>(
              stream: repo.allPartnersStream(),
              builder: (context, snapshot) {
                final partners = (snapshot.data ?? const <MarketplacePartner>[])
                    .where((p) => !p.isPreview)
                    .toList(growable: false);
                return DropdownButtonFormField<String>(
                  initialValue: _selectedPartner?.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Партнёр (для CSV/XLSX)',
                    filled: true,
                    fillColor: TajGoColors.card,
                    border: OutlineInputBorder(borderRadius: TajGoRadius.smAll),
                  ),
                  items: partners
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (id) => setState(() {
                    final match = partners.where((p) => p.id == id);
                    _selectedPartner = match.isEmpty ? null : match.first;
                  }),
                );
              },
            ),
            const SizedBox(height: TajGoSpacing.md),
            TajGoPrimaryButton(
              label: 'Выбрать файл (JSON/CSV/XLSX)',
              icon: Icons.upload_file_rounded,
              onPressed: _busy ? null : _pickFile,
            ),
            if (_fileName != null) ...[
              const SizedBox(height: TajGoSpacing.sm),
              Text('Файл: $_fileName', style: TajGoTypography.caption),
            ],
            const SizedBox(height: TajGoSpacing.lg),
            ExpansionTile(
              title: Text('Или вставьте JSON', style: TajGoTypography.bodyStrong),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              children: [
                TextField(
                  controller: _json,
                  minLines: 8,
                  maxLines: 20,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Catalog JSON · schemaVersion 1',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: TajGoSpacing.sm),
                TajGoSecondaryButton(
                  label: 'Проверить JSON',
                  onPressed: _busy ? null : _parseJsonText,
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: TajGoSpacing.md),
              Text(
                _error!,
                style: TajGoTypography.body.copyWith(color: TajGoColors.error),
              ),
            ],
            if (_issues.isNotEmpty) ...[
              const SizedBox(height: TajGoSpacing.md),
              TajGoCard(
                padding: const EdgeInsets.all(TajGoSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Пропущено строк: ${_issues.length}',
                      style: TajGoTypography.bodyStrong.copyWith(
                        color: TajGoColors.warning,
                      ),
                    ),
                    const SizedBox(height: TajGoSpacing.xs),
                    ..._issues
                        .take(20)
                        .map(
                          (i) => Text(
                            i.row == 0
                                ? '• ${i.message}'
                                : '• строка ${i.row}: ${i.message}',
                            style: TajGoTypography.caption,
                          ),
                        ),
                  ],
                ),
              ),
            ],
            if (_preview != null) ...[
              const SizedBox(height: TajGoSpacing.md),
              _previewCard(_preview!),
              const SizedBox(height: TajGoSpacing.md),
              TajGoPrimaryButton(
                label: 'Записать в каталог',
                loading: _busy,
                onPressed: _busy ? null : _publish,
              ),
            ],
            const SizedBox(height: TajGoSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _previewCard(MarketplaceCatalogImport preview) {
    return TajGoCard(
      accent: true,
      padding: const EdgeInsets.all(TajGoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Предпросмотр', style: TajGoTypography.subtitle),
          const SizedBox(height: TajGoSpacing.xs),
          Text('Партнёр: ${preview.partner.name}', style: TajGoTypography.body),
          Text(
            'Товаров: ${preview.products.length}'
            '${_updateCount + _newCount > 0 ? ' (новых $_newCount, обновлений $_updateCount)' : ''}',
            style: TajGoTypography.body,
          ),
          for (final warning in preview.warnings)
            Text('⚠ $warning', style: TajGoTypography.caption),
        ],
      ),
    );
  }
}
