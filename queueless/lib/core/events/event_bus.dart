import 'dart:async';

/// Event Bus implementation for Event-Driven Architecture.
/// Handles real-time communication between components using streams.
class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final _controller = StreamController<AppEvent>.broadcast();

  Stream<AppEvent> get stream => _controller.stream;

  void fire(AppEvent event) {
    _controller.add(event);
  }

  Stream<T> on<T extends AppEvent>() {
    return _controller.stream.where((event) => event is T).cast<T>();
  }

  void dispose() {
    _controller.close();
  }
}

/// Base class for all events
abstract class AppEvent {
  final DateTime timestamp;
  AppEvent() : timestamp = DateTime.now();
}

/// Fired when queue is updated (customer joins, leaves, or is prioritized)
class QueueUpdatedEvent extends AppEvent {
  final String businessId;
  final String? message;
  QueueUpdatedEvent({required this.businessId, this.message});
}

/// Fired when stock changes
class StockChangedEvent extends AppEvent {
  final String productId;
  final int newStock;
  StockChangedEvent({required this.productId, required this.newStock});
}

/// Fired when appointment is created or modified
class AppointmentEvent extends AppEvent {
  final String appointmentId;
  final String action; // 'created', 'confirmed', 'cancelled'
  AppointmentEvent({required this.appointmentId, required this.action});
}

/// Fired when a VIP customer is prioritized
class VIPPrioritizedEvent extends AppEvent {
  final String businessId;
  final String customerName;
  VIPPrioritizedEvent({required this.businessId, required this.customerName});
}

/// Fired when next customer is called
class CustomerCalledEvent extends AppEvent {
  final String businessId;
  final String customerName;
  CustomerCalledEvent({required this.businessId, required this.customerName});
}
