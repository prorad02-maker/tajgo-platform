import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajgo/core/models/marketplace_cart.dart';
import 'package:tajgo/core/models/marketplace_partner.dart';
import 'package:tajgo/core/models/marketplace_product.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final partner = MarketplacePartner(
    id: 'p1',
    name: 'Магазин',
    category: 'food',
    address: 'ул. Ленина',
    location: const GeoPoint(40.28, 69.62),
    deliveryFee: 15,
    minimumOrder: 30,
  );
  const product = MarketplaceProduct(
    id: 'x1',
    partnerId: 'p1',
    name: 'Товар',
    price: 12,
  );

  test('корзина восстанавливается после перезапуска', () async {
    final cart = MarketplaceCart();
    cart.add(partner, product);
    cart.add(partner, product);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final restored = MarketplaceCart();
    await restored.hydrate();

    expect(restored.partner?.id, 'p1');
    expect(restored.itemKinds, 1);
    expect(restored.itemCount, 2.0);
    expect(restored.subtotal, 24);
    expect(restored.deliveryFee, 15);
  });

  test('очистка корзины стирает кэш', () async {
    final cart = MarketplaceCart();
    cart.add(partner, product);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    cart.clear();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final restored = MarketplaceCart();
    await restored.hydrate();
    expect(restored.isEmpty, isTrue);
    expect(restored.partner, isNull);
  });

  test('повреждённый кэш не ломает hydrate', () async {
    SharedPreferences.setMockInitialValues({
      'marketplace_cart_v1': '{not valid json',
    });
    final restored = MarketplaceCart();
    await restored.hydrate();
    expect(restored.isEmpty, isTrue);
  });
}
