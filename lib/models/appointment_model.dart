enum AppointmentStatus { pending, confirmed, cancelled, completed }

class AppointmentModel {
  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final DateTime dateTime;
  final AppointmentStatus status;
  final String? notes;
  final String? serviceName;
  final double? finalPrice;
  final double? originalPrice;
  final double discountAmount;
  final String? discountCode;
  final int serviceDurationMinutes;

  AppointmentModel({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    required this.dateTime,
    this.status = AppointmentStatus.pending,
    this.notes,
    this.serviceName,
    this.finalPrice,
    this.originalPrice,
    this.discountAmount = 0,
    this.discountCode,
    this.serviceDurationMinutes = 0,
  });

  AppointmentModel copyWith({
    DateTime? dateTime,
    AppointmentStatus? status,
    String? notes,
  }) {
    return AppointmentModel(
      id: id,
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      dateTime: dateTime ?? this.dateTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      serviceName: serviceName,
      finalPrice: finalPrice,
      originalPrice: originalPrice,
      discountAmount: discountAmount,
      discountCode: discountCode,
      serviceDurationMinutes: serviceDurationMinutes,
    );
  }

  double? get displayPrice => finalPrice ?? originalPrice;

  String get durationLabel {
    if (serviceDurationMinutes <= 0) return '-';
    if (serviceDurationMinutes < 60) return '${serviceDurationMinutes} min';
    final hours = serviceDurationMinutes ~/ 60;
    final minutes = serviceDurationMinutes % 60;
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'],
      businessId: json['business_id'],
      customerId: json['customer_id'],
      customerName: json['customer_name'] ?? 'Customer',
      dateTime: DateTime.parse(json['date_time']),
      status: AppointmentStatus.values.firstWhere(
        (s) => s.toString().split('.').last == json['status'],
        orElse: () => AppointmentStatus.pending,
      ),
      notes: json['notes'],
      serviceName: json['service_name'],
      finalPrice: json['final_price'] != null ? double.tryParse(json['final_price'].toString()) : null,
      originalPrice: json['original_price'] != null ? double.tryParse(json['original_price'].toString()) : null,
      discountAmount: double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0,
      discountCode: json['discount_code'],
      serviceDurationMinutes: int.tryParse(json['service_duration_minutes']?.toString() ?? '0') ?? 0,
    );
  }
}
