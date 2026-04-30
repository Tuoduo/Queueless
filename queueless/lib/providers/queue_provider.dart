import 'package:flutter/foundation.dart';
import '../models/queue_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/home_widget_service.dart';

class QueueProvider with ChangeNotifier {
  List<QueueEntryModel> _businessQueue = [];
  QueueModel? _currentQueueState;
  List<QueueEntryModel> _userActiveQueues = [];
  List<QueueEntryModel> _deliveredOrders = [];
  int _avgServiceSeconds = 300; // default 5 min
  
  bool _isLoading = false;
  bool _isLoadingDelivered = false;
  String? _error;
  String? _subscribedBusinessId;

  final SocketService _socketService = SocketService();

  List<QueueEntryModel> get businessQueue => _businessQueue;
  QueueModel? get currentQueue => _currentQueueState;
  List<QueueEntryModel> get userActiveQueues => _userActiveQueues;
  List<QueueEntryModel> get deliveredOrders => _deliveredOrders;
  int get avgServiceSeconds => _avgServiceSeconds;
  
  bool get isLoading => _isLoading;
  bool get isLoadingDelivered => _isLoadingDelivered;
  String? get error => _error;

  void connectSocket() {
    _socketService.connect();
  }

  void subscribeToQueue(String businessId) {
    connectSocket();
    if (_subscribedBusinessId == businessId) return;
    if (_subscribedBusinessId != null) {
      _socketService.leaveBusiness(_subscribedBusinessId!);
      _socketService.offQueueUpdate();
    }
    _subscribedBusinessId = businessId;
    _socketService.joinBusiness(businessId);
    _socketService.onQueueUpdate((data) {
      _handleQueueUpdate(data);
      if (_subscribedBusinessId != null) {
        loadDeliveredOrders(_subscribedBusinessId!, silent: true);
      }
    });
    _socketService.onQueuePaused((_) {
      if (_currentQueueState != null) {
        _currentQueueState = _currentQueueState!.copyWith(isPaused: true);
        notifyListeners();
      }
    });
    _socketService.onQueueResumed((_) {
      if (_currentQueueState != null) {
        _currentQueueState = _currentQueueState!.copyWith(isPaused: false);
        notifyListeners();
      }
    });
  }

  void unsubscribeFromQueue() {
    if (_subscribedBusinessId != null) {
      _socketService.leaveBusiness(_subscribedBusinessId!);
      _socketService.offQueueUpdate();
      _socketService.offQueuePaused();
      _socketService.offQueueResumed();
      _subscribedBusinessId = null;
    }
  }

  void _handleQueueUpdate(Map<String, dynamic> data) {
    try {
      if (data['queue'] != null) {
        _currentQueueState = QueueModel.fromJson(Map<String, dynamic>.from(data['queue']));
      }
      if (data['entries'] != null) {
        _businessQueue = (data['entries'] as List)
            .map((j) => QueueEntryModel.fromJson(Map<String, dynamic>.from(j)))
            .toList();
      }
      if (data['avgServiceSeconds'] != null) {
        _avgServiceSeconds = (data['avgServiceSeconds'] as num).toInt();
      }
      notifyListeners();
    } catch (e) {
      // ignore parse errors
    }
  }

  Future<void> loadQueue(String businessId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final queueRes = await ApiService.get('/queues/$businessId');
      if (queueRes != null) {
        _currentQueueState = QueueModel.fromJson(queueRes);
        _avgServiceSeconds = (queueRes['avg_service_seconds'] as num?)?.toInt() ?? 300;
      } else {
        _currentQueueState = null;
      }
      
      final entriesRes = await ApiService.get('/queues/$businessId/entries');
      _businessQueue = (entriesRes as List).map((j) => QueueEntryModel.fromJson(j)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDeliveredOrders(String businessId, {bool silent = false}) async {
    if (!silent) {
      _isLoadingDelivered = true;
      notifyListeners();
    }
    try {
      final res = await ApiService.get('/queues/$businessId/completed');
      _deliveredOrders = (res as List).map((j) => QueueEntryModel.fromJson(j)).toList();
    } catch (e) {
      _deliveredOrders = [];
    } finally {
      if (!silent) {
        _isLoadingDelivered = false;
      }
      notifyListeners();
    }
  }

  Future<void> loadUserQueues() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService.get('/queues/user/me');
      _userActiveQueues = (res as List).map((j) => QueueEntryModel.fromJson(j)).toList();
      HomeWidgetService.updateWidget(_userActiveQueues);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> joinQueue(String businessId, {String? notes, List<Map<String, dynamic>>? items, double totalPrice = 0, String? discountCode, double discountAmount = 0, String paymentMethod = 'later'}) async {
    try {
      final res = await ApiService.post('/queues/$businessId/join', {
        'productName': notes,
        if (items != null && items.isNotEmpty) 'items': items,
        'totalPrice': totalPrice,
        'paymentMethod': paymentMethod,
        if (discountCode != null) 'discountCode': discountCode,
        'discountAmount': discountAmount,
      });
      final newEntry = QueueEntryModel.fromJson(res);
      _userActiveQueues.insert(0, newEntry);
      notifyListeners();
    } catch (e) {
      final msg = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '').replaceAll(RegExp(r'^Error:\s*'), '');
      throw Exception(msg);
    }
  }

  Future<void> cancelSpecificQueue(String entryId) async {
    try {
      await ApiService.delete('/queues/entries/$entryId');
      _userActiveQueues.removeWhere((q) => q.id == entryId);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to cancel queue entry: $e');
    }
  }

  Future<void> leaveQueue(String entryId) async {
    await cancelSpecificQueue(entryId);
  }

  Future<void> updateEntryStatus(String entryId, QueueEntryStatus newStatus) async {
    try {
      // DB ENUM uses 'done' for completed
      final statusStr = newStatus == QueueEntryStatus.completed
          ? 'done'
          : newStatus.toString().split('.').last;
      await ApiService.put('/queues/entries/$entryId/status', {
        'status': statusStr,
      });
      final idx = _businessQueue.indexWhere((e) => e.id == entryId);
      if (idx != -1) {
        _businessQueue[idx] = _businessQueue[idx].copyWith(status: newStatus);
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to update status: $e');
    }
  }

  Future<void> callNext(String businessId) async {
    final current = _businessQueue.where((e) => e.status == QueueEntryStatus.serving).toList();
    for (var entry in current) {
      await updateEntryStatus(entry.id, QueueEntryStatus.completed);
    }
    final next = _businessQueue.where((e) => e.status == QueueEntryStatus.waiting).toList();
    if (next.isNotEmpty) {
      next.sort((a, b) => a.position.compareTo(b.position));
      await updateEntryStatus(next.first.id, QueueEntryStatus.serving);
    }
    // Remove completed entries from active list and refresh delivered
    _businessQueue.removeWhere((e) => e.status == QueueEntryStatus.completed);
    notifyListeners();
    loadDeliveredOrders(businessId);
  }

  Future<void> prioritizeVIP(String businessId, String entryId) async {
    try {
      await ApiService.put('/queues/entries/$entryId/prioritize', {});
      await loadQueue(businessId);
    } catch (e) {
      throw Exception('Failed to prioritize: $e');
    }
  }

  Future<void> reorderWaitingEntries(String businessId, List<String> orderedEntryIds) async {
    try {
      await ApiService.post('/queues/$businessId/reorder', {
        'orderedEntryIds': orderedEntryIds,
      });
      await loadQueue(businessId);
    } catch (e) {
      throw Exception('Failed to reorder queue: $e');
    }
  }

  Future<void> pauseQueue(String businessId) async {
    try {
      await ApiService.post('/queues/$businessId/pause', {});
      if (_currentQueueState != null) {
        _currentQueueState = _currentQueueState!.copyWith(isPaused: true);
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to pause queue: $e');
    }
  }

  Future<void> resumeQueue(String businessId) async {
    try {
      await ApiService.post('/queues/$businessId/resume', {});
      if (_currentQueueState != null) {
        _currentQueueState = _currentQueueState!.copyWith(isPaused: false);
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to resume queue: $e');
    }
  }
}
