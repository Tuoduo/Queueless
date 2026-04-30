class ProductModel {
  final String id;
  final String businessId;
  final String name;
  final String description;
  final double price;
  final double cost;
  final int stock;
  final bool isAvailable;
  final bool isOffSale;
  final String? imageUrl;
  final int durationMinutes;

  ProductModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.description,
    required this.price,
    this.cost = 0,
    this.stock = 0,
    this.isAvailable = true,
    this.isOffSale = false,
    this.imageUrl,
    this.durationMinutes = 0,
  });

  ProductModel copyWith({
    String? name,
    String? description,
    double? price,
    double? cost,
    int? stock,
    bool? isAvailable,
    bool? isOffSale,
    String? imageUrl,
    int? durationMinutes,
  }) {
    return ProductModel(
      id: id,
      businessId: businessId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      isAvailable: isAvailable ?? this.isAvailable,
      isOffSale: isOffSale ?? this.isOffSale,
      imageUrl: imageUrl ?? this.imageUrl,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  bool get isOutOfStock => stock <= 0;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      businessId: json['business_id'],
      name: json['name'],
      description: json['description'],
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
      cost: double.tryParse(json['cost']?.toString() ?? '0.0') ?? 0.0,
      stock: int.tryParse(json['stock']?.toString() ?? '0') ?? 0,
      isAvailable: json['is_available'] == 1 || json['is_available'] == true,
      isOffSale: json['is_off_sale'] == 1 || json['is_off_sale'] == true,
      imageUrl: json['image_url'],
      durationMinutes: int.tryParse(json['duration_minutes']?.toString() ?? '0') ?? 0,
    );
  }
}
