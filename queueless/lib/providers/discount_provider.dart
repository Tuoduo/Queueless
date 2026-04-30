import 'package:flutter/foundation.dart';
import '../models/discount_model.dart';
import '../services/api_service.dart';

class DiscountProvider with ChangeNotifier {
  List<DiscountModel> _myDiscounts = [];
  bool _isLoading = false;
  String? _error;

  List<DiscountModel> get myDiscounts => _myDiscounts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMyDiscounts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService.get('/discounts/mine');
      _myDiscounts = (res as List)
          .map((j) => DiscountModel.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createDiscount({
    required String code,
    required String type,
    required double value,
    int maxUsageCount = 1,
    DateTime? expiresAt,
  }) async {
    try {
      final res = await ApiService.post('/discounts', {
        'code': code,
        'type': type,
        'value': value,
        'max_usage_count': maxUsageCount,
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      });
      _myDiscounts.insert(0, DiscountModel.fromJson(Map<String, dynamic>.from(res as Map)));
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to create discount: $e');
    }
  }

  Future<void> toggleDiscount(String discountId) async {
    try {
      await ApiService.put('/discounts/$discountId/toggle', {});
      final idx = _myDiscounts.indexWhere((d) => d.id == discountId);
      if (idx != -1) {
        // Toggle locally
        _myDiscounts[idx] = DiscountModel(
          id: _myDiscounts[idx].id,
          businessId: _myDiscounts[idx].businessId,
          code: _myDiscounts[idx].code,
          type: _myDiscounts[idx].type,
          value: _myDiscounts[idx].value,
          isActive: !_myDiscounts[idx].isActive,
          maxUsageCount: _myDiscounts[idx].maxUsageCount,
          usedCount: _myDiscounts[idx].usedCount,
          expiresAt: _myDiscounts[idx].expiresAt,
        );
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to toggle discount: $e');
    }
  }

  Future<void> deleteDiscount(String discountId) async {
    try {
      await ApiService.delete('/discounts/$discountId');
      _myDiscounts.removeWhere((d) => d.id == discountId);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete discount: $e');
    }
  }

  // Public method to validate a code (for checkout)
  Future<Map<String, dynamic>> validateCode(String businessId, String code, double baseAmount) async {
    try {
      final res = await ApiService.post('/discounts/validate', {
        'businessId': businessId,
        'code': code,
        'amount': baseAmount,
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      throw Exception('Invalid or expired coupon code: $e');
    }
  }
}
