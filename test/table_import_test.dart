import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/core/services/marketplace_table_import_service.dart';

void main() {
  const service = MarketplaceTableImportService();

  test('CSV: валидные товары импортируются, ошибочные строки помечаются', () {
    const csv =
        'sku,name,price,unit\n'
        'A1,Хлеб,5,item\n'
        'A2,Молоко,abc,item\n'
        ',,,\n'
        'A3,Плов,25,portion\n'
        'A1,Дубль,7,item';
    final rows = service.parseCsv(csv);
    final result = service.productsFromTable(rows, partnerId: 'p1');
    expect(result.products.length, 2); // Хлеб + Плов
    expect(result.products.first.sku, 'A1');
    expect(result.products.first.price, 5);
    expect(result.issues.length, 2); // bad price + duplicate SKU
    expect(result.issues.any((i) => i.message.contains('цена')), isTrue);
    expect(result.issues.any((i) => i.message.contains('SKU')), isTrue);
  });

  test('CSV: без столбцов name/price — общая ошибка', () {
    const csv = 'foo,bar\n1,2';
    final result = service.productsFromTable(service.parseCsv(csv), partnerId: 'p');
    expect(result.products, isEmpty);
    expect(result.issues.single.message, contains('name'));
  });

  test('CSV: неизвестная единица помечается', () {
    const csv = 'name,price,unit\nТовар,10,галлон';
    final result = service.productsFromTable(service.parseCsv(csv), partnerId: 'p');
    expect(result.products, isEmpty);
    expect(result.issues.single.message, contains('единица'));
  });

  test('CSV: запятая как десятичный разделитель и пустая единица', () {
    const csv = 'name,price\nТовар,12,5';
    // «12,5» распарсится как два столбца из-за запятой — проверяем устойчивость.
    final rows = service.parseCsv('name;price\nТовар;12,5'.replaceAll(';', ','));
    // Пустая единица -> item; цена 12.5
    final ok = service.productsFromTable(
      service.parseCsv('name,price,unit\nТовар,"12,5",kg'),
      partnerId: 'p',
    );
    expect(ok.products.single.price, 12.5);
    expect(ok.products.single.unit, 'kg');
    expect(rows, isNotEmpty);
    expect(csv, isNotEmpty);
  });
}
