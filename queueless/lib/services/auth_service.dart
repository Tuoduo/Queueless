import '../models/user_model.dart';
import '../models/business_model.dart';
import 'api_service.dart';

class AuthService {
  UserModel? _currentUser;
  
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  static UserRole _parseRole(String? role) {
    switch (role) {
      case 'businessOwner':
        return UserRole.businessOwner;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.customer;
    }
  }

  static UserModel _mapUser(Map<String, dynamic> json, {UserRole? fallbackRole}) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: fallbackRole ?? _parseRole(json['role']?.toString()),
      notificationsEnabled: json['notifications_enabled'] != false && json['notifications_enabled'] != 0,
    );
  }

  Future<UserModel> login(String email, String password) async {
    final response = await ApiService.post('/auth/login', {
      'email': email,
      'password': password,
    });
    
    final token = response['token'];
    ApiService.setToken(token);
    
    _currentUser = _mapUser(Map<String, dynamic>.from(response['user'] as Map));
    return _currentUser!;
  }

  Future<UserModel> register({
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
    final businessCategoryName = businessCategory?.toString().split('.').last;
    final serviceTypeName = serviceType?.toString().split('.').last;
    Map<String, dynamic> optionalEntry(String key, Object? value) {
      return value == null ? const <String, dynamic>{} : <String, dynamic>{key: value};
    }

    final payload = {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'role': role == UserRole.businessOwner ? 'businessOwner' : 'customer',
      ...optionalEntry('businessName', businessName),
      ...optionalEntry('businessCategory', businessCategoryName),
      ...optionalEntry('serviceType', serviceTypeName),
      ...optionalEntry('businessAddress', businessAddress),
    };
    
    final response = await ApiService.post('/auth/register', payload);
    
    final token = response['token'];
    ApiService.setToken(token);
    
    _currentUser = _mapUser(Map<String, dynamic>.from(response['user'] as Map), fallbackRole: role);
    
    return _currentUser!;
  }

  Future<void> logout() async {
    ApiService.clearToken();
    _currentUser = null;
  }

  Future<UserModel> updateProfile({
    required String name,
    required String email,
    required String phone,
    String? password,
    String? currentPassword,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
      if (password != null && password.isNotEmpty) 'password': password,
      if (currentPassword != null && currentPassword.isNotEmpty) 'currentPassword': currentPassword,
    };
    final response = await ApiService.put('/auth/profile', payload);
    _currentUser = _mapUser(Map<String, dynamic>.from(response['user'] as Map), fallbackRole: _currentUser!.role);
    return _currentUser!;
  }

  Future<UserModel> updateNotificationPreference(bool enabled) async {
    final response = await ApiService.put('/auth/preferences/notifications', {'enabled': enabled});
    _currentUser = _mapUser(Map<String, dynamic>.from(response['user'] as Map), fallbackRole: _currentUser?.role);
    return _currentUser!;
  }

  Future<void> deleteAccount() async {
    await ApiService.delete('/auth/account');
    ApiService.clearToken();
    _currentUser = null;
  }
}
