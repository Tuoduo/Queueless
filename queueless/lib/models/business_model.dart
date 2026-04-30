enum BusinessCategory { 
  bakery, 
  barber, 
  restaurant, 
  clinic, 
  bank, 
  repair, 
  beauty, 
  dentist, 
  gym, 
  pharmacy, 
  grocery, 
  government, 
  cafe, 
  vet, 
  other 
}

enum ServiceType { queue, appointment, both }

class BusinessModel {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final BusinessCategory category;
  final ServiceType serviceType;
  final String address;
  final String phone;
  final bool isActive;
  final String approvalStatus;
  final double rating;
  final int ratingCount;
  final int totalCustomersServed;
  final double? latitude;
  final double? longitude;
  final int waitingCount;
  final int servingCount;
  final int avgServiceSeconds;
  final String? imageUrl;

  BusinessModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.category,
    this.serviceType = ServiceType.both,
    required this.address,
    this.phone = '',
    this.isActive = true,
    this.approvalStatus = 'approved',
    this.rating = 0.0,
    this.ratingCount = 0,
    this.totalCustomersServed = 0,
    this.latitude,
    this.longitude,
    this.waitingCount = 0,
    this.servingCount = 0,
    this.avgServiceSeconds = 300,
    this.imageUrl,
  });

  BusinessModel copyWith({
    String? name,
    String? description,
    BusinessCategory? category,
    ServiceType? serviceType,
    String? address,
    String? phone,
    bool? isActive,
    String? approvalStatus,
    double? rating,
    int? ratingCount,
    int? totalCustomersServed,
    double? latitude,
    double? longitude,
    int? waitingCount,
    int? servingCount,
    int? avgServiceSeconds,
    String? imageUrl,
  }) {
    return BusinessModel(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      serviceType: serviceType ?? this.serviceType,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      totalCustomersServed: totalCustomersServed ?? this.totalCustomersServed,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      waitingCount: waitingCount ?? this.waitingCount,
      servingCount: servingCount ?? this.servingCount,
      avgServiceSeconds: avgServiceSeconds ?? this.avgServiceSeconds,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  String get categoryDisplayName {
    switch (category) {
      case BusinessCategory.bakery: return 'Bakery';
      case BusinessCategory.barber: return 'Barber';
      case BusinessCategory.restaurant: return 'Restaurant';
      case BusinessCategory.clinic: return 'Clinic';
      case BusinessCategory.bank: return 'Bank';
      case BusinessCategory.repair: return 'Repair Shop';
      case BusinessCategory.beauty: return 'Beauty Salon';
      case BusinessCategory.dentist: return 'Dentist';
      case BusinessCategory.gym: return 'Gym';
      case BusinessCategory.pharmacy: return 'Pharmacy';
      case BusinessCategory.grocery: return 'Grocery';
      case BusinessCategory.government: return 'Gov. Office';
      case BusinessCategory.cafe: return 'Cafe';
      case BusinessCategory.vet: return 'Veterinary';
      case BusinessCategory.other: return 'Other';
    }
  }

  String get categoryIcon {
    switch (category) {
      case BusinessCategory.bakery: return '🍰';
      case BusinessCategory.barber: return '💈';
      case BusinessCategory.restaurant: return '🍽️';
      case BusinessCategory.clinic: return '🏥';
      case BusinessCategory.bank: return '🏦';
      case BusinessCategory.repair: return '🛠️';
      case BusinessCategory.beauty: return '💅';
      case BusinessCategory.dentist: return '🦷';
      case BusinessCategory.gym: return '🏋️';
      case BusinessCategory.pharmacy: return '💊';
      case BusinessCategory.grocery: return '🛒';
      case BusinessCategory.government: return '🏛️';
      case BusinessCategory.cafe: return '☕';
      case BusinessCategory.vet: return '🐾';
      case BusinessCategory.other: return '🏪';
    }
  }

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'],
      ownerId: json['owner_id'],
      name: json['name'],
      description: json['description'] ?? '',
      category: BusinessCategory.values.firstWhere(
        (c) => c.toString().split('.').last == json['category'],
        orElse: () => BusinessCategory.other,
      ),
      serviceType: ServiceType.values.firstWhere(
        (s) => s.toString().split('.').last == json['service_type'],
        orElse: () => ServiceType.both,
      ),
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      approvalStatus: json['approval_status']?.toString() ?? 'approved',
      rating: double.tryParse(json['rating']?.toString() ?? '0.0') ?? 0.0,
      ratingCount: int.tryParse(json['rating_count']?.toString() ?? '0') ?? 0,
      totalCustomersServed: int.tryParse(json['total_customers_served']?.toString() ?? json['total_served']?.toString() ?? '0') ?? 0,
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      waitingCount: int.tryParse(json['waiting_count']?.toString() ?? '0') ?? 0,
      servingCount: int.tryParse(json['serving_count']?.toString() ?? '0') ?? 0,
      avgServiceSeconds: int.tryParse(json['avg_service_seconds']?.toString() ?? '300') ?? 300,
      imageUrl: json['image_url'],
    );
  }
}
