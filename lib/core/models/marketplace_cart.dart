import 'package:flutter/foundation.dart';

import 'marketplace_partner.dart';
import 'marketplace_product.dart';
import '../utils/money_formatter.dart';

class MarketplaceCartLine {
  const MarketplaceCartLine({required this.product, required this.quantity});

  final MarketplaceProduct product;
  final double quantity;

  num get total => ((product.price * 100).round() * quantity).round() / 100;

  MarketplaceCartLine copyWith({double? quantity}) => MarketplaceCartLine(
    product: product,
    quantity: quantity ?? this.quantity,
  );
}

class MarketplaceCartConflict implements Exception {
  const MarketplaceCartConflict(this.partnerName);
  final String partnerName;
}

class MarketplaceCart extends ChangeNotifier {
  MarketplacePartner? _partner;
  final Map<String, MarketplaceCartLine> _lines = {};

  MarketplacePartner? get partner => _partner;
  List<MarketplaceCartLine> get lines => List.unmodifiable(_lines.values);
  bool get isEmpty => _lines.isEmpty;
  int get itemKinds => _lines.length;
  double get itemCount =>
      _lines.values.fold(0, (sum, line) => sum + line.quantity);
  num get subtotal =>
      roundMoney(_lines.values.fold<num>(0, (sum, line) => sum + line.total));
  num get deliveryFee =>
      _partner == null ? 0 : _partner!.deliveryFee.clamp(10, 100000);
  num get total => roundMoney(subtotal + deliveryFee);

  void add(MarketplacePartner partner, MarketplaceProduct product) {
    if (product.partnerId != partner.id ||
        !partner.isOpen ||
        !product.isAvailable ||
        product.hidden) {
      throw StateError('Товар сейчас недоступен.');
    }
    if (_partner != null && _partner!.id != partner.id && _lines.isNotEmpty) {
      throw MarketplaceCartConflict(_partner!.name);
    }
    _partner = partner;
    final current = _lines[product.id];
    if ((current?.quantity ?? 0) + product.quantityStep > 100) {
      throw StateError('Максимум 100 единиц одного товара.');
    }
    _lines[product.id] = MarketplaceCartLine(
      product: product,
      quantity: (current?.quantity ?? 0) + product.quantityStep,
    );
    notifyListeners();
  }

  void replacePartner(MarketplacePartner partner, MarketplaceProduct product) {
    if (product.partnerId != partner.id ||
        !partner.isOpen ||
        !product.isAvailable ||
        product.hidden) {
      throw StateError('Товар сейчас недоступен.');
    }
    _lines.clear();
    _partner = null;
    add(partner, product);
  }

  void increment(String productId) {
    final line = _lines[productId];
    if (line == null || line.quantity + line.product.quantityStep > 100) return;
    _lines[productId] = line.copyWith(
      quantity: line.quantity + line.product.quantityStep,
    );
    notifyListeners();
  }

  void decrement(String productId) {
    final line = _lines[productId];
    if (line == null) return;
    final next = line.quantity - line.product.quantityStep;
    if (next <= 0) {
      _lines.remove(productId);
      if (_lines.isEmpty) _partner = null;
    } else {
      _lines[productId] = line.copyWith(quantity: next);
    }
    notifyListeners();
  }

  void remove(String productId) {
    _lines.remove(productId);
    if (_lines.isEmpty) _partner = null;
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _partner = null;
    notifyListeners();
  }
}

class MarketplaceCheckoutQuote {
  const MarketplaceCheckoutQuote({
    required this.subtotal,
    required this.deliveryFee,
    required this.minimumOrder,
  });

  final num subtotal;
  final num deliveryFee;
  final num minimumOrder;

  num get total => roundMoney(subtotal + deliveryFee);
  num get missingForMinimum =>
      roundMoney((minimumOrder - subtotal).clamp(0, double.infinity));
  bool get meetsMinimum => missingForMinimum == 0;
}
