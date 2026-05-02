// tests/flutter/models/product_model_test.dart
//
// QueueLess — ProductModel unit tests

import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/models/product_model.dart';

void main() {
  Map<String, dynamic> buildJson({
    int stock = 10,
    bool isAvailable = true,
    bool isOffSale = false,
    int durationMinutes = 0,
    String price = '12.50',
  }) {
    return {
      'id': 'prod-1', 'business_id': 'b-1',
      'name': 'Pistachio Baklava',
      'description': 'Classic Turkish baklava with pistachios.',
      'price': price, 'cost': '4.00',
      'stock': stock.toString(),
      'is_available': isAvailable ? 1 : 0,
      'is_off_sale': isOffSale ? 1 : 0,
      'duration_minutes': durationMinutes.toString(),
    };
  }

  group('ProductModel', () {
    // ── 29. fromJson parses all fields ─────────────────────────────────────
    test('fromJson creates a valid ProductModel', () {
      final model = ProductModel.fromJson(buildJson());
      expect(model.id, equals('prod-1'));
      expect(model.price, closeTo(12.50, 0.001));
      expect(model.stock, equals(10));
      expect(model.isAvailable, isTrue);
      expect(model.isOffSale, isFalse);
    });

    // ── 30. isOutOfStock ───────────────────────────────────────────────────
    test('isOutOfStock is true when stock is 0 and false when > 0', () {
      expect(ProductModel.fromJson(buildJson(stock: 0)).isOutOfStock, isTrue);
      expect(ProductModel.fromJson(buildJson(stock: 5)).isOutOfStock, isFalse);
    });

    // ── 31. copyWith ───────────────────────────────────────────────────────
    test('copyWith updates only the provided fields', () {
      final original = ProductModel.fromJson(buildJson());
      final updated  = original.copyWith(stock: 0, isOffSale: true, name: 'Sold Out');
      expect(updated.stock, equals(0));
      expect(updated.isOffSale, isTrue);
      expect(updated.name, equals('Sold Out'));
      expect(updated.id, equals(original.id));
    });

    // ── 32. durationMinutes defaults to 0 ─────────────────────────────────
    test('durationMinutes defaults to 0 when not in JSON', () {
      final json = {
        'id': 'p-2', 'business_id': 'b-1', 'name': 'Churros',
        'description': '', 'price': '5.00', 'cost': '1.50',
        'stock': '20', 'is_available': 1, 'is_off_sale': 0,
      };
      expect(ProductModel.fromJson(json).durationMinutes, equals(0));
    });

    // ── 33. isAvailable false ──────────────────────────────────────────────
    test('isAvailable is false when is_available is 0', () {
      final model = ProductModel.fromJson(buildJson(isAvailable: false));
      expect(model.isAvailable, isFalse);
    });
  });
}
