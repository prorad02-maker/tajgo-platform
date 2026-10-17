import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../models/marketplace_product.dart';

/// Ошибка строки таблицы импорта (1-based номер строки данных).
class ImportRowIssue {
  const ImportRowIssue(this.row, this.message);
  final int row;
  final String message;
}

/// Результат dry-run табличного импорта (CSV/XLSX).
class TableImportResult {
  const TableImportResult({
    required this.products,
    required this.issues,
    this.warnings = const [],
  });

  /// Валидные товары (без id — id назначается по SKU/новый на этапе подтверждения).
  final List<MarketplaceProduct> products;
  final List<ImportRowIssue> issues;
  final List<String> warnings;

  bool get hasIssues => issues.isNotEmpty;
}

/// Импорт прайса из CSV/XLSX для выбранного партнёра.
///
/// Сам файл выбирается через file_selector; этот сервис только парсит и
/// валидирует. Ничего не пишет в Firestore — запись выполняет authoritative
/// Function после подтверждения.
class MarketplaceTableImportService {
  const MarketplaceTableImportService();

  static const int maxRows = 200;

  List<List<String>> parseCsv(String content) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = Csv().decode(normalized);
    return rows
        .map((row) => row.map((cell) => cell.toString()).toList())
        .toList(growable: false);
  }

  List<List<String>> parseXlsx(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return const [];
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) return const [];
    return sheet.rows
        .map(
          (row) => row
              .map((cell) => (cell?.value?.toString() ?? '').trim())
              .toList(),
        )
        .toList(growable: false);
  }

  /// Преобразует таблицу (первая строка — заголовки) в товары с валидацией.
  TableImportResult productsFromTable(
    List<List<String>> table, {
    required String partnerId,
  }) {
    final rows = table.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
    if (rows.isEmpty) {
      return const TableImportResult(
        products: [],
        issues: [ImportRowIssue(0, 'Файл пуст.')],
      );
    }
    final header = rows.first.map((c) => c.trim().toLowerCase()).toList();
    int col(List<String> names) {
      for (final name in names) {
        final index = header.indexOf(name);
        if (index >= 0) return index;
      }
      return -1;
    }

    final iSku = col(['sku', 'артикул']);
    final iName = col(['name', 'название', 'товар']);
    final iDesc = col(['description', 'описание']);
    final iPrice = col(['price', 'цена']);
    final iOld = col(['oldprice', 'old_price', 'старая цена']);
    final iUnit = col(['unit', 'единица', 'ед']);
    final iStock = col(['stockstatus', 'stock', 'status', 'наличие']);
    final iSort = col(['sortorder', 'sort', 'порядок']);
    final iPopular = col(['popularity', 'популярность']);

    if (iName < 0 || iPrice < 0) {
      return const TableImportResult(
        products: [],
        issues: [
          ImportRowIssue(0, 'Нужны как минимум столбцы «name» и «price».'),
        ],
      );
    }

    final dataRows = rows.skip(1).toList();
    if (dataRows.length > maxRows) {
      return TableImportResult(
        products: const [],
        issues: [ImportRowIssue(0, 'Не более $maxRows строк за импорт.')],
      );
    }

    final products = <MarketplaceProduct>[];
    final issues = <ImportRowIssue>[];
    final seenSku = <String>{};

    String cell(List<String> row, int index) =>
        (index >= 0 && index < row.length) ? row[index].trim() : '';

    for (var i = 0; i < dataRows.length; i++) {
      final rowNo = i + 1;
      final row = dataRows[i];
      final name = cell(row, iName);
      if (name.isEmpty) {
        issues.add(ImportRowIssue(rowNo, 'Пустое название.'));
        continue;
      }
      final priceRaw = cell(row, iPrice).replaceAll(',', '.');
      final price = num.tryParse(priceRaw);
      if (price == null || price < 0) {
        issues.add(ImportRowIssue(rowNo, 'Неверная цена: «${cell(row, iPrice)}».'));
        continue;
      }
      final oldRaw = cell(row, iOld).replaceAll(',', '.');
      final oldPrice = oldRaw.isEmpty ? null : num.tryParse(oldRaw);
      if (oldRaw.isNotEmpty && (oldPrice == null || oldPrice < price)) {
        issues.add(ImportRowIssue(rowNo, 'Старая цена неверна или ниже цены.'));
        continue;
      }
      final unit = _unit(cell(row, iUnit));
      if (unit == null) {
        issues.add(ImportRowIssue(rowNo, 'Неизвестная единица: «${cell(row, iUnit)}».'));
        continue;
      }
      final sku = cell(row, iSku);
      if (sku.isNotEmpty && !seenSku.add(sku.toLowerCase())) {
        issues.add(ImportRowIssue(rowNo, 'Повтор SKU: «$sku».'));
        continue;
      }
      final stock = cell(row, iStock).toLowerCase();
      final hidden = stock == 'hidden' || stock == 'скрыт';
      final unavailable = {
        'out',
        'unavailable',
        'нет',
        '0',
        'false',
      }.contains(stock);
      products.add(
        MarketplaceProduct(
          id: '',
          partnerId: partnerId,
          name: name,
          description: cell(row, iDesc),
          price: price,
          oldPrice: oldPrice,
          unit: unit,
          sku: sku,
          isAvailable: !unavailable,
          hidden: hidden,
          popularity: int.tryParse(cell(row, iPopular)) ?? 0,
          sortOrder: int.tryParse(cell(row, iSort)) ?? i,
        ),
      );
    }

    return TableImportResult(products: products, issues: issues);
  }

  String? _unit(String raw) {
    if (raw.trim().isEmpty) return 'item';
    final value = raw.trim().toLowerCase();
    return switch (value) {
      'item' || 'шт' || 'шт.' || 'штука' => 'item',
      'kg' || 'кг' => 'kg',
      'portion' || 'порция' => 'portion',
      'bouquet' || 'букет' => 'bouquet',
      _ => null,
    };
  }
}
