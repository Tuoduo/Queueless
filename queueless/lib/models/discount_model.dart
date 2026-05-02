class DiscountModel {
  final String id;
  final String businessId;
  final String code;
  final String type; // 'percentage' or 'fixed'
  final double value;
  final int maxUsageCount;
  final int usedCount;
  final DateTime? expiresAt;
  final bool isActive;

  DiscountModel({
    required this.id,
    required this.businessId,
    required this.code,
    required this.type,
    required this.value,
    this.maxUsageCount = 1,
    this.usedCount = 0,
    this.expiresAt,
    this.isActive = true,
  });

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().toLowerCase();
    return normalized == '1' || normalized == 'true';
  }

  factory DiscountModel.fromJson(Map<String, dynamic> json) {
    return DiscountModel(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? 'percentage',
      value: _toDouble(json['value']),
      maxUsageCount: _toInt(json['max_usage_count']),
      usedCount: _toInt(json['used_count']),
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
      isActive: _toBool(json['is_active']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'code': code,
      'type': type,
      'value': value,
      'max_usage_count': maxUsageCount,
      'used_count': usedCount,
      'expires_at': expiresAt?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }
}
