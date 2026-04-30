import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../core/events/event_bus.dart';

class ProductService {
  final _uuid = const Uuid();
  final EventBus _eventBus = EventBus();
  
  // Mock DB
  final List<ProductModel> _products = [
    // Pre-seed some data for testing
    ProductModel(
      id: 'p1',
      businessId: 'b1',
      name: 'Fresh Baklava',
      description: 'Daily baked traditional turkish baklava',
      price: 15.0,
      stock: 50,
    ),
    ProductModel(
      id: 'p2',
      businessId: 'b1',
      name: 'Men Haircut',
      description: 'Standard hair cut and wash',
      price: 25.0,
      stock: 100, // Unlimited stock basically for services
    )
  ];

  Future<List<ProductModel>> getProductsForBusiness(String businessId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _products.where((p) => p.businessId == businessId && p.isAvailable).toList();
  }

  Future<List<ProductModel>> getAllProductsForBusiness(String businessId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _products.where((p) => p.businessId == businessId).toList();
  }

  Future<ProductModel> addProduct({
    required String businessId,
    required String name,
    required String description,
    required double price,
    int stock = 0,
  }) async {
    final newProduct = ProductModel(
      id: _uuid.v4(),
      businessId: businessId,
      name: name,
      description: description,
      price: price,
      stock: stock,
    );
    
    _products.add(newProduct);
    return newProduct;
  }

  Future<void> updateStock(String productId, int newStock) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index] = _products[index].copyWith(stock: newStock);
      _eventBus.fire(StockChangedEvent(productId: productId, newStock: newStock));
    }
  }

  Future<void> orderProduct(String productId, int quantity) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final currentStock = _products[index].stock;
      if (currentStock >= quantity) {
        final newStock = currentStock - quantity;
        _products[index] = _products[index].copyWith(stock: newStock);
        _eventBus.fire(StockChangedEvent(productId: productId, newStock: newStock));
      } else {
        throw Exception('Not enough stock');
      }
    }
  }
}
