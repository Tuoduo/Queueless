import 'package:uuid/uuid.dart';
import '../models/queue_model.dart';
import '../core/events/event_bus.dart';

/// Mock Queue Service handling real-time updates via EventBus
class QueueService {
  static final QueueService _instance = QueueService._internal();
  factory QueueService() => _instance;
  QueueService._internal();

  final _uuid = const Uuid();
  final EventBus _eventBus = EventBus();
  
  // Mock database
  final Map<String, QueueModel> _queues = {};

  Future<QueueModel> getQueue(String businessId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!_queues.containsKey(businessId)) {
      _queues[businessId] = QueueModel(
        id: _uuid.v4(),
        businessId: businessId,
      );
    }
    
    return _queues[businessId]!;
  }

  Future<QueueEntryModel> joinQueue({
    required String businessId,
    required String customerId,
    required String customerName,
    String? notes,
  }) async {
    final queue = await getQueue(businessId);
    
    // Check if already in queue
    final existingEntry = queue.entries.where(
      (e) => e.customerId == customerId && 
             (e.status == QueueEntryStatus.waiting || e.status == QueueEntryStatus.serving)
    ).firstOrNull;

    if (existingEntry != null) {
      throw Exception('Already in queue');
    }

    final newEntry = QueueEntryModel(
      id: _uuid.v4(),
      customerId: customerId,
      customerName: customerName,
      businessId: businessId,
      position: queue.waitingCount + 1,
      notes: notes,
    );

    queue.entries.add(newEntry);
    
    _eventBus.fire(QueueUpdatedEvent(
      businessId: businessId,
      message: '$customerName joined the queue.',
    ));

    return newEntry;
  }

  Future<void> leaveQueue(String businessId, String entryId) async {
    final queue = await getQueue(businessId);
    final entryIndex = queue.entries.indexWhere((e) => e.id == entryId);
    
    if (entryIndex != -1) {
      queue.entries[entryIndex].status = QueueEntryStatus.cancelled;
      _updatePositions(queue);
      _eventBus.fire(QueueUpdatedEvent(businessId: businessId));
    }
  }

  Future<void> callNextCustomer(String businessId) async {
    final queue = await getQueue(businessId);
    
    // Complete current serving if any
    final currentList = queue.entries.where((e) => e.status == QueueEntryStatus.serving).toList();
    if (currentList.isNotEmpty) {
      currentList.first.status = QueueEntryStatus.completed;
      queue.currentServing++;
    }

    // Call next waiting
    final waitingList = queue.waitingEntries;
    if (waitingList.isNotEmpty) {
      final next = waitingList.first;
      next.status = QueueEntryStatus.serving;
      _updatePositions(queue);
      
      _eventBus.fire(QueueUpdatedEvent(businessId: businessId));
      _eventBus.fire(CustomerCalledEvent(
        businessId: businessId, 
        customerName: next.customerName
      ));
    }
  }

  Future<void> prioritizeVIP(String businessId, String entryId) async {
    final queue = await getQueue(businessId);
    final entryIndex = queue.entries.indexWhere((e) => e.id == entryId);
    
    if (entryIndex != -1 && queue.entries[entryIndex].status == QueueEntryStatus.waiting) {
      final entry = queue.entries.removeAt(entryIndex);
      
      // Inherits the position 1 (right after the serving one if any)
      // Find the first index of a waiting customer
      final firstWaitingIndex = queue.entries.indexWhere((e) => e.status == QueueEntryStatus.waiting);
      
      if (firstWaitingIndex != -1) {
        queue.entries.insert(firstWaitingIndex, entry);
      } else {
        queue.entries.add(entry);
      }
      
      _updatePositions(queue);
      
      _eventBus.fire(QueueUpdatedEvent(businessId: businessId));
      _eventBus.fire(VIPPrioritizedEvent(
        businessId: businessId, 
        customerName: entry.customerName
      ));
    }
  }

  void _updatePositions(QueueModel queue) {
    int pos = 1;
    for (var entry in queue.entries) {
      if (entry.status == QueueEntryStatus.waiting) {
        entry.position = pos++;
      }
    }
  }

  Future<List<QueueEntryModel>> getUserActiveQueues(String customerId) async {
    final List<QueueEntryModel> activeEntries = [];
    
    _queues.forEach((businessId, queue) {
      final userEntry = queue.entries.where(
        (e) => e.customerId == customerId && 
               (e.status == QueueEntryStatus.waiting || e.status == QueueEntryStatus.serving)
      ).firstOrNull;
      
      if (userEntry != null) {
        activeEntries.add(userEntry);
      }
    });

    return activeEntries;
  }
}
