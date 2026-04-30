import 'package:flutter/material.dart';
import '../models/business_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

enum _BusinessViewMode { none, publicList, owner }

class BusinessProvider with ChangeNotifier {
  final SocketService _socketService = SocketService();
  List<BusinessModel> _businesses = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  BusinessCategory? _selectedCategory;
  bool _listeningForUpdates = false;
  _BusinessViewMode _viewMode = _BusinessViewMode.none;
  String? _trackedOwnerId;

  List<BusinessModel> get businesses => _businesses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  BusinessCategory? get selectedCategory => _selectedCategory;

  void _ensureRealtimeUpdates() {
    if (_listeningForUpdates) return;
    _socketService.connect();
    _socketService.offBusinessUpdate(_handleBusinessUpdate);
    _socketService.onBusinessUpdate(_handleBusinessUpdate);
    _listeningForUpdates = true;
  }

  void _handleBusinessUpdate(Map<String, dynamic> payload) {
    if (_viewMode == _BusinessViewMode.owner && _trackedOwnerId != null && _trackedOwnerId!.isNotEmpty) {
      final ownerId = payload['ownerId']?.toString() ?? '';
      final businessId = payload['businessId']?.toString() ?? '';
      final currentBusinessId = _businesses.isNotEmpty ? _businesses.first.id : '';
      if (ownerId == _trackedOwnerId || businessId == currentBusinessId) {
        loadOwnerBusiness(_trackedOwnerId!, silent: true);
      }
      return;
    }

    if (_viewMode == _BusinessViewMode.publicList) {
      loadBusinesses(silent: true);
    }
  }

  Future<void> loadBusinesses({bool silent = false}) async {
    _viewMode = _BusinessViewMode.publicList;
    _trackedOwnerId = null;
    _ensureRealtimeUpdates();
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final queryParams = [];
      if (_selectedCategory != null) {
        queryParams.add('category=${_selectedCategory!.name}');
      }
      if (_searchQuery.isNotEmpty) {
        queryParams.add('search=${Uri.encodeQueryComponent(_searchQuery)}');
      }
      
      final q = queryParams.isEmpty ? '' : '?${queryParams.join('&')}';
      final response = await ApiService.get('/businesses$q');
      
      final List<dynamic> data = response;
      _businesses = data.map((json) => BusinessModel.fromJson(json)).toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading businesses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOwnerBusiness(String ownerId, {bool silent = false}) async {
    _viewMode = _BusinessViewMode.owner;
    _trackedOwnerId = ownerId;
    _ensureRealtimeUpdates();
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final response = await ApiService.get('/businesses/owner/$ownerId');
      if (response != null) {
        _businesses = [BusinessModel.fromJson(response)];
        debugPrint('Owner business loaded: ${response['name']}');
      } else {
        _businesses = [];
        _error = 'No business found for this owner';
        debugPrint('Owner business not found');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading owner business: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchBusinesses(String query) {
    _searchQuery = query;
    loadBusinesses();
  }

  void reset() {
    _businesses = [];
    _error = null;
    _searchQuery = '';
    _selectedCategory = null;
    _isLoading = false;
    _trackedOwnerId = null;
    _viewMode = _BusinessViewMode.none;
    notifyListeners();
  }

  void filterByCategory(BusinessCategory? category) {
    _selectedCategory = category;
    loadBusinesses();
  }

  BusinessModel? getBusinessById(String id) {
    try {
      return _businesses.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  BusinessModel? getBusinessByOwnerId(String ownerId) {
    try {
      return _businesses.firstWhere((b) => b.ownerId == ownerId);
    } catch (e) {
      return null;
    }
  }

  Future<void> addRating(String businessId, double rating, {String comment = '', String productsPurchased = ''}) async {
    final body = <String, dynamic>{'rating': rating};
    if (comment.isNotEmpty) body['comment'] = comment;
    if (productsPurchased.isNotEmpty) body['products_purchased'] = productsPurchased;
    // Let the caller handle errors — do NOT swallow them silently.
    final res = await ApiService.post('/businesses/$businessId/rating', body);
    final index = _businesses.indexWhere((b) => b.id == businessId);
    if (index != -1) {
      _businesses[index] = _businesses[index].copyWith(
        rating: double.tryParse(res['rating']?.toString() ?? '0') ?? _businesses[index].rating,
        ratingCount: int.tryParse(res['count']?.toString() ?? '0') ?? _businesses[index].ratingCount,
      );
      notifyListeners();
    }
  }

  void registerBusiness(BusinessModel business) {
    _businesses.removeWhere((item) => item.ownerId == business.ownerId);
    _businesses.add(business);
    notifyListeners();
  }

  Future<void> updateBusiness(String id, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.put('/businesses/$id', data);
      final index = _businesses.indexWhere((b) => b.id == id);
      if (index != -1) {
        _businesses[index] = BusinessModel.fromJson(res);
      } else {
        _businesses.add(BusinessModel.fromJson(res));
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _socketService.offBusinessUpdate(_handleBusinessUpdate);
    super.dispose();
  }
}
