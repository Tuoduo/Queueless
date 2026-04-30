import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';
import 'auth_provider.dart';

class NotificationProvider with ChangeNotifier {
  final SocketService _socketService = SocketService();
  final List<NotificationModel> _notifications = <NotificationModel>[];

  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;
  String? _activeUserId;
  String? _activeConversationId;
  bool _notificationsEnabled = true;
  String? _permissionsRequestedForUserId;

  List<NotificationModel> get notifications => List<NotificationModel>.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  void syncAuth(AuthProvider authProvider) {
    final userId = authProvider.currentUser?.id;
    if (!authProvider.isAuthenticated || userId == null || userId.isEmpty) {
      _socketService.offNotification(_handleIncomingNotification);
      _activeUserId = null;
      _activeConversationId = null;
      _notificationsEnabled = true;
      _notifications.clear();
      _unreadCount = 0;
      _error = null;
      notifyListeners();
      return;
    }

    _notificationsEnabled = authProvider.currentUser?.notificationsEnabled ?? true;
    _socketService.connect();
    _socketService.offNotification(_handleIncomingNotification);
    _socketService.onNotification(_handleIncomingNotification);

    if (_notificationsEnabled && _permissionsRequestedForUserId != userId) {
      _permissionsRequestedForUserId = userId;
      Future<void>.microtask(NotificationService.requestPermissions);
    }

    if (_activeUserId != userId) {
      _activeUserId = userId;
      Future<void>.microtask(loadNotifications);
    } else {
      notifyListeners();
    }
  }

  Future<void> loadNotifications({bool silent = false}) async {
    if (_activeUserId == null) return;
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final result = await ApiService.get('/notifications');
      final items = List<Map<String, dynamic>>.from(result['notifications'] ?? const <Map<String, dynamic>>[])
          .map(NotificationModel.fromJson)
          .toList();
      _notifications
        ..clear()
        ..addAll(items);
      _unreadCount = (result['unreadCount'] as num?)?.toInt() ?? items.where((item) => !item.isRead).length;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((item) => item.id == notificationId);
    if (index == -1 || _notifications[index].isRead) return;

    _notifications[index] = _notifications[index].copyWith(isRead: true);
    _unreadCount = (_unreadCount - 1).clamp(0, _notifications.length);
    notifyListeners();

    try {
      await ApiService.put('/notifications/$notificationId/read', {});
    } catch (_) {
      // Leave optimistic state in place; next refresh will correct it if needed.
    }
  }

  Future<void> markAllAsRead() async {
    if (_notifications.every((item) => item.isRead)) return;

    for (var index = 0; index < _notifications.length; index++) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
    }
    _unreadCount = 0;
    notifyListeners();

    try {
      await ApiService.post('/notifications/read-all', {});
    } catch (_) {
      // Ignore and let manual refresh reconcile state.
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final originalItems = List<NotificationModel>.from(_notifications);
    _notifications.removeWhere((item) => item.id == notificationId);
    _unreadCount = _notifications.where((item) => !item.isRead).length;
    notifyListeners();

    try {
      await ApiService.delete('/notifications/$notificationId');
    } catch (_) {
      _notifications
        ..clear()
        ..addAll(originalItems);
      _unreadCount = _notifications.where((item) => !item.isRead).length;
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    if (_notifications.isEmpty) return;

    final originalItems = List<NotificationModel>.from(_notifications);
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();

    try {
      await ApiService.delete('/notifications/clear-all');
    } catch (_) {
      _notifications
        ..clear()
        ..addAll(originalItems);
      _unreadCount = _notifications.where((item) => !item.isRead).length;
      notifyListeners();
    }
  }

  Future<bool> enableDeviceAlerts() {
    return NotificationService.requestPermissions();
  }

  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId == null || conversationId.isEmpty ? null : conversationId;
  }

  bool _shouldSuppress(NotificationModel notification) {
    if (notification.type != 'chat_message') return false;
    final conversationId = notification.metadata?['conversationId']?.toString() ?? notification.entityId ?? '';
    return conversationId.isNotEmpty && conversationId == _activeConversationId;
  }

  void _handleIncomingNotification(Map<String, dynamic> payload) {
    if (!_notificationsEnabled) return;
    final notification = NotificationModel.fromJson(payload);
    if (_shouldSuppress(notification)) return;

    final existingIndex = _notifications.indexWhere((item) => item.id == notification.id);
    if (existingIndex == -1) {
      _notifications.insert(0, notification);
    } else {
      _notifications[existingIndex] = notification;
    }

    _unreadCount = _notifications.where((item) => !item.isRead).length;
    notifyListeners();
    NotificationService.showNotification(notification);
  }
}