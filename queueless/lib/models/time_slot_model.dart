class TimeSlotModel {
  final String id;
  final String businessId;
  final DateTime startTime;
  final DateTime endTime;
  bool isBooked;

  TimeSlotModel({
    required this.id,
    required this.businessId,
    required this.startTime,
    required this.endTime,
    this.isBooked = false,
  });

  String get timeRange => 
    '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - '
    '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

  TimeSlotModel copyWith({
    bool? isBooked,
  }) {
    return TimeSlotModel(
      id: id,
      businessId: businessId,
      startTime: startTime,
      endTime: endTime,
      isBooked: isBooked ?? this.isBooked,
    );
  }

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) {
    return TimeSlotModel(
      id: json['id'],
      businessId: json['business_id'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      isBooked: json['is_booked'] == 1 || json['is_booked'] == true,
    );
  }
}
