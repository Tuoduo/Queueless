import 'package:uuid/uuid.dart';
import '../models/appointment_model.dart';
import '../core/events/event_bus.dart';

import '../models/time_slot_model.dart';

class AppointmentService {
  static final AppointmentService _instance = AppointmentService._internal();
  factory AppointmentService() => _instance;
  AppointmentService._internal() {
    _seedMockData();
  }

  final _uuid = const Uuid();
  final EventBus _eventBus = EventBus();
  
  // Mock DB lists
  final List<AppointmentModel> _appointments = [];
  final Map<String, List<TimeSlotModel>> _availability = {};

  /// Seed initial slots for appointment-based businesses
  void _seedMockData() {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    // Mahmut Barbershop (b2) - appointment based
    _availability['b2'] = [
      TimeSlotModel(id: 'slot_1', businessId: 'b2', startTime: DateTime(today.year, today.month, today.day, 9, 0), endTime: DateTime(today.year, today.month, today.day, 9, 30)),
      TimeSlotModel(id: 'slot_2', businessId: 'b2', startTime: DateTime(today.year, today.month, today.day, 10, 0), endTime: DateTime(today.year, today.month, today.day, 10, 30)),
      TimeSlotModel(id: 'slot_3', businessId: 'b2', startTime: DateTime(today.year, today.month, today.day, 11, 0), endTime: DateTime(today.year, today.month, today.day, 11, 30)),
      TimeSlotModel(id: 'slot_4', businessId: 'b2', startTime: DateTime(today.year, today.month, today.day, 13, 0), endTime: DateTime(today.year, today.month, today.day, 13, 30)),
      TimeSlotModel(id: 'slot_5', businessId: 'b2', startTime: DateTime(today.year, today.month, today.day, 14, 0), endTime: DateTime(today.year, today.month, today.day, 14, 30)),
      TimeSlotModel(id: 'slot_6', businessId: 'b2', startTime: DateTime(today.year, today.month, today.day, 15, 0), endTime: DateTime(today.year, today.month, today.day, 15, 30)),
      // Tomorrow slots
      TimeSlotModel(id: 'slot_7', businessId: 'b2', startTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0), endTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 30)),
      TimeSlotModel(id: 'slot_8', businessId: 'b2', startTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 11, 0), endTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 11, 30)),
      TimeSlotModel(id: 'slot_9', businessId: 'b2', startTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 14, 0), endTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 14, 30)),
    ];

    // Akdeniz Clinic (b4) - appointment based
    _availability['b4'] = [
      TimeSlotModel(id: 'slot_c1', businessId: 'b4', startTime: DateTime(today.year, today.month, today.day, 8, 0), endTime: DateTime(today.year, today.month, today.day, 8, 30)),
      TimeSlotModel(id: 'slot_c2', businessId: 'b4', startTime: DateTime(today.year, today.month, today.day, 9, 0), endTime: DateTime(today.year, today.month, today.day, 9, 30)),
      TimeSlotModel(id: 'slot_c3', businessId: 'b4', startTime: DateTime(today.year, today.month, today.day, 10, 0), endTime: DateTime(today.year, today.month, today.day, 10, 30)),
      TimeSlotModel(id: 'slot_c4', businessId: 'b4', startTime: DateTime(today.year, today.month, today.day, 14, 0), endTime: DateTime(today.year, today.month, today.day, 14, 30)),
      TimeSlotModel(id: 'slot_c5', businessId: 'b4', startTime: DateTime(today.year, today.month, today.day, 15, 0), endTime: DateTime(today.year, today.month, today.day, 15, 30)),
    ];
  }

  Future<List<AppointmentModel>> getAppointmentsForBusiness(String businessId, DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _appointments.where((a) => 
      a.businessId == businessId && 
      a.dateTime.year == date.year && 
      a.dateTime.month == date.month && 
      a.dateTime.day == date.day
    ).toList();
  }

  Future<List<AppointmentModel>> getAppointmentsForCustomer(String customerId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _appointments.where((a) => a.customerId == customerId).toList();
  }

  // --- SLOT MANAGEMENT ---

  Future<List<TimeSlotModel>> getAvailableSlots(String businessId, DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final slots = _availability[businessId] ?? [];
    return slots.where((s) => 
      s.startTime.year == date.year && 
      s.startTime.month == date.month && 
      s.startTime.day == date.day
    ).toList();
  }

  Future<void> addSlot(TimeSlotModel slot) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_availability.containsKey(slot.businessId)) {
      _availability[slot.businessId] = [];
    }
    _availability[slot.businessId]!.add(slot);
  }

  Future<AppointmentModel> bookAppointment({
    required String businessId,
    required String customerId,
    required String customerName,
    required DateTime dateTime,
    String? slotId,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Mark slot as booked if provided
    if (slotId != null && _availability.containsKey(businessId)) {
      final slotIndex = _availability[businessId]!.indexWhere((s) => s.id == slotId);
      if (slotIndex != -1) {
        _availability[businessId]![slotIndex].isBooked = true;
      }
    }

    final newAppointment = AppointmentModel(
      id: _uuid.v4(),
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      dateTime: dateTime,
      notes: notes,
    );
    
    _appointments.add(newAppointment);
    
    _eventBus.fire(AppointmentEvent(
      appointmentId: newAppointment.id, 
      action: 'created'
    ));
    
    return newAppointment;
  }

  Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus status) async {
    final index = _appointments.indexWhere((a) => a.id == appointmentId);
    if (index != -1) {
      final updated = _appointments[index].copyWith(status: status);
      _appointments[index] = updated;
      
      _eventBus.fire(AppointmentEvent(
        appointmentId: appointmentId, 
        action: status.name
      ));
    }
  }
}
