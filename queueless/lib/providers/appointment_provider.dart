import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/appointment_model.dart';
import '../models/time_slot_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class AppointmentProvider with ChangeNotifier {
  List<AppointmentModel> _customerAppointments = [];
  List<AppointmentModel> _businessAppointments = [];
  List<TimeSlotModel> _availableSlots = [];
  
  bool _isLoading = false;
  String? _error;
  String? _subscribedBusinessId;
  DateTime? _selectedBusinessDate;
  String? _subscribedCustomerId;
  bool _includeBookedSlots = false;

  final SocketService _socketService = SocketService();

  List<AppointmentModel> get customerAppointments => _customerAppointments;
  List<AppointmentModel> get appointments => _customerAppointments;
  List<AppointmentModel> get businessAppointments => _businessAppointments;
  List<TimeSlotModel> get availableSlots => _availableSlots;
  List<AppointmentModel> get activeCustomerAppointments => _customerAppointments
      .where((appointment) => appointment.status != AppointmentStatus.completed && appointment.status != AppointmentStatus.cancelled)
      .toList();
  
  bool get isLoading => _isLoading;
  String? get error => _error;

  void connectSocket() {
    _socketService.connect();
  }

  void subscribeToBusinessAppointments(String businessId, {DateTime? date}) {
    connectSocket();
    if (_subscribedBusinessId != null && _subscribedBusinessId != businessId) {
      _socketService.leaveBusiness(_subscribedBusinessId!);
    }

    _subscribedBusinessId = businessId;
    _selectedBusinessDate = date;
    _socketService.joinBusiness(businessId);
    _socketService.offAppointmentUpdate();
    _socketService.onAppointmentUpdate((_) {
      final currentBusinessId = _subscribedBusinessId;
      if (currentBusinessId != null) {
        loadBusinessAppointments(currentBusinessId, date: _selectedBusinessDate, silent: true);
      }
    });
  }

  void unsubscribeFromBusinessAppointments() {
    if (_subscribedBusinessId != null) {
      _socketService.leaveBusiness(_subscribedBusinessId!);
    }
    _subscribedBusinessId = null;
    _selectedBusinessDate = null;
    _socketService.offAppointmentUpdate();
  }

  void subscribeToCustomerAppointments(String userId) {
    connectSocket();
    _subscribedCustomerId = userId;
    _socketService.offAppointmentUpdate();
    _socketService.onAppointmentUpdate((_) {
      if (_subscribedCustomerId != null) {
        loadCustomerAppointments(silent: true);
      }
    });
  }

  void unsubscribeFromCustomerAppointments() {
    _subscribedCustomerId = null;
    _socketService.offAppointmentUpdate();
  }

  Future<void> loadAvailableSlots(String businessId, DateTime date, {bool includeBooked = false}) async {
    _isLoading = true;
    _error = null;
    _includeBookedSlots = includeBooked;
    notifyListeners();

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final availableOnly = includeBooked ? '0' : '1';
      final res = await ApiService.get('/appointments/slots?businessId=$businessId&date=$dateStr&availableOnly=$availableOnly');
      _availableSlots = (res as List).map((j) => TimeSlotModel.fromJson(j)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCustomerAppointments({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final res = await ApiService.get('/appointments');
      _customerAppointments = (res as List).map((j) => AppointmentModel.fromJson(j)).toList();
    } catch (e) {
      if (!silent) {
        _error = e.toString();
      }
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> loadBusinessAppointments(String businessId, {DateTime? date, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      String url = '/appointments/business/$businessId';
      if (date != null) {
        url += '?date=${DateFormat('yyyy-MM-dd').format(date)}';
      }
      final res = await ApiService.get(url);
      _businessAppointments = (res as List).map((j) => AppointmentModel.fromJson(j)).toList();
    } catch (e) {
      if (!silent) {
        _error = e.toString();
      }
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> bookAppointment({
    required String businessId,
    required DateTime dateTime,
    String? slotId,
    String? serviceName,
    String? notes,
    String? discountCode,
  }) async {
    try {
      final res = await ApiService.post('/appointments', {
        'business_id': businessId,
        'date_time': dateTime.toIso8601String(),
        if (slotId != null) 'slot_id': slotId,
        if (serviceName != null) 'service_name': serviceName,
        if (notes != null) 'notes': notes,
        if (discountCode != null) 'discount_code': discountCode,
      });

      // Add to local list
      final newAppt = AppointmentModel.fromJson(res);
      _customerAppointments.insert(0, newAppt);

      // Refresh slots
      if (slotId != null) {
         final index = _availableSlots.indexWhere((s) => s.id == slotId);
         if (index != -1) {
           if (_includeBookedSlots) {
             _availableSlots[index] = _availableSlots[index].copyWith(isBooked: true);
           } else {
             _availableSlots.removeAt(index);
           }
         }
      }
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to book appointment: $e');
    }
  }

  Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus status) async {
    try {
      await ApiService.put('/appointments/$appointmentId/status', {
        'status': status.toString().split('.').last,
      });
      // Optimistic update
      final idx = _businessAppointments.indexWhere((a) => a.id == appointmentId);
      if (idx != -1) {
        _businessAppointments[idx] = _businessAppointments[idx].copyWith(status: status);
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to update status: $e');
    }
  }

  Future<void> cancelAppointment(String appointmentId) async {
    try {
      await ApiService.delete('/appointments/$appointmentId');
      _customerAppointments.removeWhere((a) => a.id == appointmentId);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to cancel appointment: $e');
    }
  }

  Future<void> addSlot(TimeSlotModel slot) async {
    try {
      final res = await ApiService.post('/appointments/slots', {
        'business_id': slot.businessId,
        'start_time': slot.startTime.toIso8601String(),
        'end_time': slot.endTime.toIso8601String(),
      });
      final newSlot = TimeSlotModel.fromJson(res);
      _availableSlots.add(newSlot);
      _availableSlots.sort((a, b) => a.startTime.compareTo(b.startTime));
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to create slot: $e');
    }
  }
}
