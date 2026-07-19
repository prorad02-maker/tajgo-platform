import 'package:flutter/foundation.dart';

import 'marketplace_partner.dart';
import 'marketplace_product.dart';

class MarketplaceCartLine {
  const MarketplaceCartLine({required this.product, required this.quantity});

  final MarketplaceProduct product;
  final double quantity;

  num get total => product.price * quantity;

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
      _lines.values.fold<num>(0, (sum, line) => sum + line.total);
  num get deliveryFee => _partner?.deliveryFee ?? 0;
  num get total => subtotal + deliveryFee;

  void add(MarketplacePartner partner, MarketplaceProduct product) {
    if (!product.isAvailable || product.hidden) {
      throw StateError('Товар сейчас недоступен.');
    }
    if (_partner != null && _partner!.id != partner.id && _lines.isNotEmpty) {
      throw MarketplaceCartConflict(_partner!.name);
    }
    _partner = partner;
    final current = _lines[product.id];
    _lines[product.id] = MarketplaceCartLine(
      product: product,
      quantity: (current?.quantity ?? 0) + product.quantityStep,
    );
    notifyListeners();
  }

  void replacePartner(MarketplacePartner partner, MarketplaceProduct product) {
    _lines.clear();
    _partner = null;
    add(partner, product);
  }

  void increment(String productId) {
    final line = _lines[productId];
    if (line == null) return;
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

  num get total => subtotal + deliveryFee;
  num get missingForMinimum =>
      (minimumOrder - subtotal).clamp(0, double.infinity);
  bool get meetsMinimum => missingForMinimum == 0;
}
