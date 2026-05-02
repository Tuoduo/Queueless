import '../core/utils/eta_utils.dart';

enum QueueEntryStatus { waiting, serving, completed, cancelled }

class QueueEntryModel {
  final String id;
  final String customerId;
  final String customerName;
  final String businessId;
  int position;
  final bool isVIP;
  final DateTime joinedAt;
  QueueEntryStatus status;
  final String? notes;
  final String? businessName;
  final double? businessLatitude;
  final double? businessLongitude;
  final int? peopleAhead;
  final int avgServiceSeconds;
  final int productDurationMinutes;
  final int itemCount;
  final int? estimatedWaitSeconds;
  final int? estimatedWaitMinMinutes;
  final int? estimatedWaitMaxMinutes;
  final DateTime? arrivalConfirmedAt;
  final int? arrivalDistanceMeters;
  final double totalPrice;
  final String paymentMethod;
  final String? discountCode;
  final double discountAmount;

  QueueEntryModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.businessId,
    required this.position,
    this.isVIP = false,
    DateTime? joinedAt,
    this.status = QueueEntryStatus.waiting,
    this.notes,
    this.businessName,
    this.businessLatitude,
    this.businessLongitude,
    this.peopleAhead,
    this.avgServiceSeconds = 300,
    this.productDurationMinutes = 0,
    this.itemCount = 1,
    this.estimatedWaitSeconds,
    this.estimatedWaitMinMinutes,
    this.estimatedWaitMaxMinutes,
    this.arrivalConfirmedAt,
    this.arrivalDistanceMeters,
    this.totalPrice = 0,
    this.paymentMethod = 'later',
    this.discountCode,
    this.discountAmount = 0,
  }) : joinedAt = joinedAt ?? DateTime.now();

  QueueEntryModel copyWith({
    int? position,
    bool? isVIP,
    QueueEntryStatus? status,
    int? peopleAhead,
  }) {
    return QueueEntryModel(
      id: id,
      customerId: customerId,
      customerName: customerName,
      businessId: businessId,
      position: position ?? this.position,
      isVIP: isVIP ?? this.isVIP,
      joinedAt: joinedAt,
      status: status ?? this.status,
      notes: notes,
      businessName: businessName,
      businessLatitude: businessLatitude,
      businessLongitude: businessLongitude,
      peopleAhead: peopleAhead ?? this.peopleAhead,
      avgServiceSeconds: avgServiceSeconds,
      productDurationMinutes: productDurationMinutes,
      itemCount: itemCount,
      estimatedWaitSeconds: estimatedWaitSeconds,
      estimatedWaitMinMinutes: estimatedWaitMinMinutes,
      estimatedWaitMaxMinutes: estimatedWaitMaxMinutes,
      arrivalConfirmedAt: arrivalConfirmedAt,
      arrivalDistanceMeters: arrivalDistanceMeters,
      totalPrice: totalPrice,
      paymentMethod: paymentMethod,
      discountCode: discountCode,
      discountAmount: discountAmount,
    );
  }

  String get waitTimeEstimate {
    if (estimatedWaitMinMinutes != null && estimatedWaitMaxMinutes != null) {
      return NonLinearEtaRange(
        minMinutes: estimatedWaitMinMinutes!,
        maxMinutes: estimatedWaitMaxMinutes!,
      ).label;
    }

    final posAhead = peopleAhead ?? (position > 0 ? position - 1 : 0);
    if (posAhead <= 0) return '<1 min';
    return estimateNonlinearEtaRange(
      unitCount: posAhead,
      avgServiceSeconds: productDurationMinutes > 0 ? productDurationMinutes * 60 : avgServiceSeconds,
    ).label;
  }

  bool get isArrivalConfirmed => arrivalConfirmedAt != null;

  String get durationLabel {
    if (productDurationMinutes <= 0) return '-';
    if (productDurationMinutes < 60) return '${productDurationMinutes} min';
    final hours = productDurationMinutes ~/ 60;
    final minutes = productDurationMinutes % 60;
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }

  double get originalPrice => totalPrice + discountAmount;

  String get paymentMethodLabel => paymentMethod == 'now' ? 'Paid with card' : 'Pay on arrival';

  factory QueueEntryModel.fromJson(Map<String, dynamic> json) {
    return QueueEntryModel(
      id: json['id'],
      customerId: json['customer_id'],
      customerName: json['customer_name'] ?? 'Customer',
      businessId: json['business_id'],
      position: int.tryParse(json['position']?.toString() ?? '0') ?? 0,
      isVIP: json['is_vip'] == 1 || json['is_vip'] == true,
      joinedAt: json['joined_at'] != null ? DateTime.parse(json['joined_at']) : null,
      status: (() {
        final rawStatus = json['status']?.toString();
        if (rawStatus == 'done') return QueueEntryStatus.completed;
        return QueueEntryStatus.values.firstWhere(
          (e) => e.toString().split('.').last == rawStatus,
          orElse: () => QueueEntryStatus.waiting,
        );
      })(),
      notes: json['product_name'],
      businessName: json['business_name'],
      businessLatitude: double.tryParse(json['latitude']?.toString() ?? ''),
      businessLongitude: double.tryParse(json['longitude']?.toString() ?? ''),
      peopleAhead: json['people_ahead'] != null ? int.tryParse(json['people_ahead'].toString()) : null,
      avgServiceSeconds: int.tryParse(json['avg_service_seconds']?.toString() ?? '300') ?? 300,
      productDurationMinutes: int.tryParse(json['product_duration_minutes']?.toString() ?? '0') ?? 0,
      itemCount: int.tryParse(json['item_count']?.toString() ?? '1') ?? 1,
      estimatedWaitSeconds: json['estimated_wait_seconds'] != null ? int.tryParse(json['estimated_wait_seconds'].toString()) : null,
      estimatedWaitMinMinutes: json['estimated_wait_min_minutes'] != null ? int.tryParse(json['estimated_wait_min_minutes'].toString()) : null,
      estimatedWaitMaxMinutes: json['estimated_wait_max_minutes'] != null ? int.tryParse(json['estimated_wait_max_minutes'].toString()) : null,
      arrivalConfirmedAt: json['arrival_confirmed_at'] != null ? DateTime.tryParse(json['arrival_confirmed_at'].toString()) : null,
      arrivalDistanceMeters: json['arrival_distance_meters'] != null ? int.tryParse(json['arrival_distance_meters'].toString()) : null,
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0,
      paymentMethod: json['payment_method']?.toString() == 'now' ? 'now' : 'later',
      discountCode: json['discount_code'],
      discountAmount: double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0,
    );
  }
}

class QueueModel {
  final String id;
  final String businessId;
  final List<QueueEntryModel> entries;
  final bool isActive;
  final bool isPaused;
  int currentServing;
  int waitingFromServer;
  int avgServiceSeconds;

  QueueModel({
    required this.id,
    required this.businessId,
    List<QueueEntryModel>? entries,
    this.isActive = true,
    this.isPaused = false,
    this.currentServing = 0,
    this.waitingFromServer = 0,
    this.avgServiceSeconds = 300,
  }) : entries = entries ?? [];

  QueueModel copyWith({bool? isPaused}) {
    return QueueModel(
      id: id,
      businessId: businessId,
      entries: entries,
      isActive: isActive,
      isPaused: isPaused ?? this.isPaused,
      currentServing: currentServing,
      waitingFromServer: waitingFromServer,
      avgServiceSeconds: avgServiceSeconds,
    );
  }

  List<QueueEntryModel> get waitingEntries =>
      entries.where((e) => e.status == QueueEntryStatus.waiting).toList();

  List<QueueEntryModel> get completedEntries =>
      entries.where((e) => e.status == QueueEntryStatus.completed).toList();

  int get waitingCount => entries.isEmpty ? waitingFromServer : waitingEntries.length;

  QueueEntryModel? get currentEntry =>
      entries.where((e) => e.status == QueueEntryStatus.serving).isEmpty
          ? null
          : entries.firstWhere((e) => e.status == QueueEntryStatus.serving);

  factory QueueModel.fromJson(Map<String, dynamic> json) {
    return QueueModel(
      id: json['id'] ?? '',
      businessId: json['business_id'] ?? '',
      entries: [],
      isActive: json['is_open'] == 1 || json['is_open'] == true || json['is_active'] == 1 || json['is_active'] == true,
      isPaused: json['is_paused'] == 1 || json['is_paused'] == true,
      currentServing: int.tryParse(json['serving_count']?.toString() ?? '0') ?? 0,
      waitingFromServer: int.tryParse(json['waiting_count']?.toString() ?? '0') ?? 0,
      avgServiceSeconds: int.tryParse(json['avg_service_seconds']?.toString() ?? '300') ?? 300,
    );
  }
}
