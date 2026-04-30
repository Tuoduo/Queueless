import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ProductProvider with ChangeNotifier {
  List<ProductModel> _products = [];
  bool _isLoading = false;
  String? _error;
  String? _currentBusinessId;
  bool _showAllProducts = false;
  CartProvider? _cartProvider;

  final SocketService _socketService = SocketService();

  List<ProductModel> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ProductProvider attachCartProvider(CartProvider? cartProvider) {
    _cartProvider = cartProvider;
    return this;
  }

  Future<void> loadBusinessProducts(String businessId, {bool all = false, bool silent = false}) async {
    _currentBusinessId = businessId;
    _showAllProducts = all;
    _socketService.connect();
    _socketService.joinBusiness(businessId);
    _socketService.offProductUpdate(_handleProductUpdate);
    _socketService.onProductUpdate(_handleProductUpdate);

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final response = await ApiService.get('/products?businessId=$businessId');
      final List<dynamic> data = response;
      _products = data.map((json) => ProductModel.fromJson(json)).toList();
      
      if (!all) {
        _products = _products.where((p) => p.isAvailable).toList();
      }
      _cartProvider?.reconcileCatalog(_products, businessId: businessId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addProduct({
    required String businessId,
    required String name,
    required String description,
    required double price,
    required int stock,
    String? imageUrl,
    int durationMinutes = 60,
    double cost = 0,
  }) async {
    try {
      final response = await ApiService.post('/products', {
        'business_id': businessId,
        'name': name,
        'description': description,
        'price': price,
        'stock': stock,
        'duration_minutes': durationMinutes,
        'cost': cost,
        if (imageUrl != null) 'image_url': imageUrl,
      });
      _products.add(ProductModel.fromJson(response));
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to add product: $e');
    }
  }

  Future<void> updateProduct({
    required String productId,
    required String name,
    required String description,
    required double price,
    required int stock,
    required int durationMinutes,
    required double cost,
    bool? isOffSale,
  }) async {
    try {
      final index = _products.indexWhere((p) => p.id == productId);
      if (index == -1) return;
      final product = _products[index];
      final response = await ApiService.put('/products/$productId', {
        'name': name,
        'description': description,
        'price': price,
        'stock': stock,
        'is_available': product.isAvailable,
        'is_off_sale': isOffSale ?? product.isOffSale,
        'duration_minutes': durationMinutes,
        'cost': cost,
      });
      _products[index] = ProductModel.fromJson(response);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await ApiService.delete('/products/$productId');
      _products.removeWhere((p) => p.id == productId);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  Future<void> updateStock(String productId, int newStock) async {
    try {
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        final product = _products[index];
        final response = await ApiService.put('/products/$productId', {
          'name': product.name,
          'description': product.description,
          'price': product.price,
          'stock': newStock,
          'is_available': product.isAvailable,
          'is_off_sale': product.isOffSale,
          'duration_minutes': product.durationMinutes,
        });
        _products[index] = ProductModel.fromJson(response);
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to update stock: $e');
    }
  }

  Future<void> toggleAvailability(String productId) async {
    try {
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        final product = _products[index];
        final response = await ApiService.put('/products/$productId', {
          'name': product.name,
          'description': product.description,
          'price': product.price,
          'stock': product.stock,
          'is_available': product.isAvailable,
          'is_off_sale': !product.isOffSale,
          'duration_minutes': product.durationMinutes,
        });
        _products[index] = ProductModel.fromJson(response);
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to toggle availability: $e');
    }
  }

  void _handleProductUpdate(Map<String, dynamic> payload) {
    final businessId = payload['businessId']?.toString();
    if (_currentBusinessId == null || businessId != _currentBusinessId) return;
    loadBusinessProducts(_currentBusinessId!, all: _showAllProducts, silent: true);
  }

  @override
  void dispose() {
    _socketService.offProductUpdate(_handleProductUpdate);
    super.dispose();
  }
}
