import 'package:flutter/material.dart';
import '../models/cart_model.dart';
import '../models/product_model.dart';

class CartProvider with ChangeNotifier {
  final Map<String, CartItemModel> _items = {};
  String? _businessId;

  Map<String, CartItemModel> get items => {..._items};

  int get itemCount => _items.length;

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.totalPrice;
    });
    return total;
  }

  String? get businessId => _businessId;

  bool requiresBusinessSwitch(ProductModel product) {
    return _items.isNotEmpty && _businessId != null && _businessId != product.businessId;
  }

  bool addItem(ProductModel product, {bool replaceExisting = false}) {
    if (requiresBusinessSwitch(product) && !replaceExisting) {
      return false;
    }

    if (_businessId != null && _businessId != product.businessId) {
      _items.clear();
    }
    _businessId = product.businessId;

    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
        (existing) => existing.copyWith(quantity: existing.quantity + 1),
      );
    } else {
      _items.putIfAbsent(
        product.id,
        () => CartItemModel(product: product),
      );
    }
    notifyListeners();
    return true;
  }

  void removeItem(String productId) {
    _items.remove(productId);
    if (_items.isEmpty) {
      _businessId = null;
    }
    notifyListeners();
  }

  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) return;

    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existing) => existing.copyWith(quantity: existing.quantity - 1),
      );
    } else {
      _items.remove(productId);
    }
    
    if (_items.isEmpty) {
      _businessId = null;
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _businessId = null;
    notifyListeners();
  }

  String get cartSummary {
    if (_items.isEmpty) return 'No items selected';
    return _items.values
        .map((item) => '${item.quantity}x ${item.product.name}')
        .join(', ');
  }

  int get totalDurationMinutes {
    var total = 0;
    _items.forEach((key, cartItem) {
      total += cartItem.product.durationMinutes * cartItem.quantity;
    });
    return total;
  }

  List<Map<String, dynamic>> get queueItems => _items.values
      .map((item) => {
            'productId': item.product.id,
            'quantity': item.quantity,
          })
      .toList();

  List<String> reconcileCatalog(List<ProductModel> products, {String? businessId}) {
    if (_items.isEmpty) return const <String>[];
    if (businessId != null && _businessId != businessId) return const <String>[];

    final latestProducts = <String, ProductModel>{
      for (final product in products) product.id: product,
    };
    final removedNames = <String>[];
    final updatedItems = <String, CartItemModel>{};

    for (final entry in _items.entries.toList()) {
      final latest = latestProducts[entry.key];
      if (latest == null || !latest.isAvailable || latest.isOffSale || latest.isOutOfStock) {
        removedNames.add(entry.value.product.name);
        _items.remove(entry.key);
        continue;
      }

      updatedItems[entry.key] = entry.value.copyWith(product: latest);
    }

    _items.addAll(updatedItems);
    if (_items.isEmpty) {
      _businessId = null;
    }

    if (removedNames.isNotEmpty || updatedItems.isNotEmpty) {
      notifyListeners();
    }
    return removedNames;
  }
}
