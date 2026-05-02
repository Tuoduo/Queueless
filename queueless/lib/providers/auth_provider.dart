import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/business_model.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  UserModel? get currentUser => _authService.currentUser;
  bool get isAuthenticated => _authService.isAuthenticated;
  bool get isCustomer => currentUser?.role == UserRole.customer;
  bool get isBusinessOwner => currentUser?.role == UserRole.businessOwner;
  bool get isAdmin => currentUser?.role == UserRole.admin;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  String _normalizeError(Object error) {
    final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    if (raw.isEmpty) {
      return 'Sign-in failed. Please check your details and try again.';
    }
    if (raw.contains('Could not connect to the server') ||
        raw.contains('SocketException') ||
        raw.contains('XMLHttpRequest error') ||
        raw.contains('Connection refused')) {
      return 'Could not connect to the server. Please check the backend connection and try again.';
    }
    if (raw == 'Bu e-posta adresiyle kayıtlı hesap bulunamadı') {
      return 'No account found for this email address.';
    }
    if (raw == 'Şifre hatalı. Lütfen tekrar deneyin.') {
      return 'Incorrect password. Please try again.';
    }
    return raw;
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.login(email, password);
      SocketService().connect();
      final userId = _authService.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        SocketService().joinUser(userId);
      }
      if (_authService.currentUser?.role == UserRole.admin) {
        SocketService().joinAdminPanel();
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(_normalizeError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
    dynamic serviceType,
    String? businessName,
    BusinessCategory? businessCategory,
    String? businessAddress,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
        role: role,
        serviceType: serviceType,
        businessName: businessName,
        businessCategory: businessCategory,
        businessAddress: businessAddress,
      );
      SocketService().connect();
      final userId = _authService.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        SocketService().joinUser(userId);
      }
      if (_authService.currentUser?.role == UserRole.admin) {
        SocketService().joinAdminPanel();
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(_normalizeError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    final userId = currentUser?.id;
    if (userId != null && userId.isNotEmpty) {
      SocketService().leaveUser(userId);
    }
    if (currentUser?.role == UserRole.admin) {
      SocketService().leaveAdminPanel();
    }
    SocketService().disconnect();
    await _authService.logout();
    _setLoading(false);
  }

  Future<bool> deleteAccount() async {
    _setLoading(true);
    _setError(null);
    try {
      final userId = currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        SocketService().leaveUser(userId);
      }
      if (currentUser?.role == UserRole.admin) {
        SocketService().leaveAdminPanel();
      }
      await _authService.deleteAccount();
      SocketService().disconnect();
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_normalizeError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String email,
    required String phone,
    String? password,
    String? currentPassword,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.updateProfile(
        name: name,
        email: email,
        phone: phone,
        password: password,
        currentPassword: currentPassword,
      );
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_normalizeError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateNotificationPreference(bool enabled) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.updateNotificationPreference(enabled);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_normalizeError(e));
      _setLoading(false);
      return false;
    }
  }
}
