import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    _changed();
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
    _changed();
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
    _changed();
  }

  void remove(String productId) {
    _lines.remove(productId);
    if (_lines.isEmpty) _partner = null;
    _changed();
  }

  void clear() {
    _lines.clear();
    _partner = null;
    _changed();
  }

  void applyServerPrices(Map<String, num> prices) {
    var changed = false;
    for (final entry in prices.entries) {
      final line = _lines[entry.key];
      if (line == null || line.product.price == entry.value) continue;
      _lines[entry.key] = MarketplaceCartLine(
        product: line.product.copyWith(price: entry.value),
        quantity: line.quantity,
      );
      changed = true;
    }
    if (changed) _changed();
  }

  static const String _cacheKey = 'marketplace_cart_v1';

  void _changed() {
    notifyListeners();
    _persist();
  }

  /// Восстанавливает корзину из локального кэша при запуске (одна корзина = один
  /// партнёр). Безопасно игнорирует повреждённые/старые данные.
  Future<void> hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final partnerData = decoded['partner'];
      final linesData = decoded['lines'];
      if (partnerData is! Map || linesData is! List) return;
      final partner = MarketplacePartner.fromCacheMap(
        Map<String, dynamic>.from(partnerData),
      );
      if (partner.id.isEmpty) return;
      _partner = partner;
      _lines.clear();
      for (final entry in linesData) {
        if (entry is! Map) continue;
        final productData = entry['product'];
        final quantity = entry['quantity'];
        if (productData is! Map || quantity is! num) continue;
        final product = MarketplaceProduct.fromCacheMap(
          Map<String, dynamic>.from(productData),
        );
        if (product.id.isEmpty) continue;
        _lines[product.id] = MarketplaceCartLine(
          product: product,
          quantity: quantity.toDouble(),
        );
      }
      if (_lines.isEmpty) _partner = null;
      notifyListeners();
    } catch (_) {
      // Повреждённый кэш не должен ломать запуск.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_partner == null || _lines.isEmpty) {
        await prefs.remove(_cacheKey);
        return;
      }
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'partner': _partner!.toCacheMap(),
          'lines': _lines.values
              .map(
                (line) => {
                  'product': line.product.toCacheMap(),
                  'quantity': line.quantity,
                },
              )
              .toList(),
        }),
      );
    } catch (_) {
      // кэш не критичен
    }
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
