import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _connected = false;
  bool _joinedAdminPanel = false;
  final Set<String> _joinedBusinessIds = <String>{};
  final Set<String> _joinedChatIds = <String>{};
  String? _joinedUserId;
  final List<void Function(Map<String, dynamic>)> _ticketUpdateListeners = <void Function(Map<String, dynamic>)>[];
  final List<void Function(Map<String, dynamic>)> _chatUpdateListeners = <void Function(Map<String, dynamic>)>[];
  final List<void Function(Map<String, dynamic>)> _productUpdateListeners = <void Function(Map<String, dynamic>)>[];
  final List<void Function(Map<String, dynamic>)> _businessUpdateListeners = <void Function(Map<String, dynamic>)>[];
  final List<void Function(Map<String, dynamic>)> _notificationListeners = <void Function(Map<String, dynamic>)>[];

  bool get isConnected => _connected;

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  void _notifyListeners(List<void Function(Map<String, dynamic>)> listeners, dynamic data) {
    final payload = _asMap(data);
    for (final listener in List<void Function(Map<String, dynamic>)>.from(listeners)) {
      listener(payload);
    }
  }

  void _registerManagedListeners() {
    _socket?.off('ticket:update');
    _socket?.off('chat:update');
    _socket?.off('product:update');
    _socket?.off('business:update');
    _socket?.off('notification:new');

    _socket?.on('ticket:update', (data) {
      _notifyListeners(_ticketUpdateListeners, data);
    });

    _socket?.on('chat:update', (data) {
      _notifyListeners(_chatUpdateListeners, data);
    });

    _socket?.on('product:update', (data) {
      _notifyListeners(_productUpdateListeners, data);
    });

    _socket?.on('business:update', (data) {
      _notifyListeners(_businessUpdateListeners, data);
    });

    _socket?.on('notification:new', (data) {
      _notifyListeners(_notificationListeners, data);
    });
  }

  void connect() {
    if (_socket != null) {
      if (!_connected) {
        _socket!.connect();
      }
      return;
    }

    _socket = io.io(
      ApiService.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );

    _registerManagedListeners();

    _socket!.onConnect((_) {
      _connected = true;
      if (_joinedUserId != null && _joinedUserId!.isNotEmpty) {
        _socket?.emit('join:user', _joinedUserId);
      }
      if (_joinedAdminPanel) {
        _socket?.emit('join:admin');
      }
      for (final businessId in _joinedBusinessIds) {
        _socket?.emit('join:business', businessId);
      }
      for (final conversationId in _joinedChatIds) {
        _socket?.emit('join:chat', conversationId);
      }
    });

    _socket!.onDisconnect((_) {
      _connected = false;
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
    _joinedAdminPanel = false;
    _joinedBusinessIds.clear();
    _joinedChatIds.clear();
    _joinedUserId = null;
    _ticketUpdateListeners.clear();
    _chatUpdateListeners.clear();
    _productUpdateListeners.clear();
    _businessUpdateListeners.clear();
    _notificationListeners.clear();
  }

  void joinBusiness(String businessId) {
    if (businessId.isEmpty) return;
    _joinedBusinessIds.add(businessId);
    _socket?.emit('join:business', businessId);
  }

  void leaveBusiness(String businessId) {
    _joinedBusinessIds.remove(businessId);
    _socket?.emit('leave:business', businessId);
  }

  void joinAdminPanel() {
    _joinedAdminPanel = true;
    _socket?.emit('join:admin');
  }

  void leaveAdminPanel() {
    _joinedAdminPanel = false;
    _socket?.emit('leave:admin');
  }

  void joinUser(String userId) {
    if (userId.isEmpty) return;
    _joinedUserId = userId;
    _socket?.emit('join:user', userId);
  }

  void leaveUser(String userId) {
    if (_joinedUserId == userId) {
      _joinedUserId = null;
    }
    _socket?.emit('leave:user', userId);
  }

  void joinChat(String conversationId) {
    if (conversationId.isEmpty) return;
    _joinedChatIds.add(conversationId);
    _socket?.emit('join:chat', conversationId);
  }

  void leaveChat(String conversationId) {
    _joinedChatIds.remove(conversationId);
    _socket?.emit('leave:chat', conversationId);
  }

  void onQueueUpdate(void Function(Map<String, dynamic> data) callback) {
    _socket?.on('queue:update', (data) {
      if (data is Map<String, dynamic>) {
        callback(data);
      } else if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  void offQueueUpdate() {
    _socket?.off('queue:update');
  }

  void onQueuePaused(void Function(Map<String, dynamic> data) callback) {
    _socket?.on('queue:paused', (data) {
      if (data is Map) callback(Map<String, dynamic>.from(data));
    });
  }

  void offQueuePaused() {
    _socket?.off('queue:paused');
  }

  void onQueueResumed(void Function(Map<String, dynamic> data) callback) {
    _socket?.on('queue:resumed', (data) {
      if (data is Map) callback(Map<String, dynamic>.from(data));
    });
  }

  void offQueueResumed() {
    _socket?.off('queue:resumed');
  }

  void onAppointmentUpdate(void Function(Map<String, dynamic> data) callback) {
    _socket?.on('appointment:update', (data) {
      if (data is Map<String, dynamic>) {
        callback(data);
      } else if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  void offAppointmentUpdate() {
    _socket?.off('appointment:update');
  }

  void onHistoryUpdate(void Function(Map<String, dynamic> data) callback) {
    _socket?.on('history:update', (data) {
      // Always fire regardless of payload shape; the listener only needs the signal.
      if (data is Map<String, dynamic>) {
        callback(data);
      } else if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      } else {
        callback({});
      }
    });
  }

  void offHistoryUpdate() {
    _socket?.off('history:update');
  }

  void onTicketUpdate(void Function(Map<String, dynamic>) callback) {
    _ticketUpdateListeners.add(callback);
  }

  void offTicketUpdate([void Function(Map<String, dynamic>)? callback]) {
    if (callback == null) {
      _ticketUpdateListeners.clear();
      return;
    }
    _ticketUpdateListeners.remove(callback);
  }

  void onChatUpdate(void Function(Map<String, dynamic>) callback) {
    _chatUpdateListeners.add(callback);
  }

  void offChatUpdate([void Function(Map<String, dynamic>)? callback]) {
    if (callback == null) {
      _chatUpdateListeners.clear();
      return;
    }
    _chatUpdateListeners.remove(callback);
  }

  void onProductUpdate(void Function(Map<String, dynamic>) callback) {
    _productUpdateListeners.add(callback);
  }

  void offProductUpdate([void Function(Map<String, dynamic>)? callback]) {
    if (callback == null) {
      _productUpdateListeners.clear();
      return;
    }
    _productUpdateListeners.remove(callback);
  }

  void onBusinessUpdate(void Function(Map<String, dynamic>) callback) {
    _businessUpdateListeners.add(callback);
  }

  void offBusinessUpdate([void Function(Map<String, dynamic>)? callback]) {
    if (callback == null) {
      _businessUpdateListeners.clear();
      return;
    }
    _businessUpdateListeners.remove(callback);
  }

  void onNotification(void Function(Map<String, dynamic>) callback) {
    _notificationListeners.add(callback);
  }

  void offNotification([void Function(Map<String, dynamic>)? callback]) {
    if (callback == null) {
      _notificationListeners.clear();
      return;
    }
    _notificationListeners.remove(callback);
  }
}
