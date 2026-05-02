import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_config.dart';

class ApiService {
  static const String _networkErrorMessage = 'Could not connect to the server. Please check the backend connection and try again.';

  /// The base URL used for all REST API calls.
  /// - Web (same machine): localhost keeps working in browser dev
  /// - Physical devices on LAN: uses kBackendHost from app_config.dart
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:$kBackendPort/api';
    return 'http://$kBackendHost:$kBackendPort/api';
  }

  /// The base URL used for Socket.IO connections.
  static String get socketUrl {
    if (kIsWeb) return 'http://localhost:$kBackendPort';
    return 'http://$kBackendHost:$kBackendPort';
  }

  /// Returns the base URL used for QR code guest page links.
  /// Honours the PUBLIC_BASE_URL build-time variable when set.
  static String get configuredGuestBaseUrl {
    const envBaseUrl = String.fromEnvironment('PUBLIC_BASE_URL', defaultValue: '');
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl.replaceFirst(RegExp(r'/$'), '');
    }
    return socketUrl;
  }

  /// Resolves the best reachable base URL for guest QR links.
  /// Falls back to [configuredGuestBaseUrl] when PUBLIC_BASE_URL is set.
  static Future<String> resolveGuestBaseUrl() async {
    const envBaseUrl = String.fromEnvironment('PUBLIC_BASE_URL', defaultValue: '');
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl.replaceFirst(RegExp(r'/$'), '');
    }
    return socketUrl;
  }

  static String? _token;
  static void setToken(String token) => _token = token;
  static void clearToken() => _token = null;

  static Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  static Future<dynamic> get(String endpoint) async {
    return _sendRequest(() => http.get(Uri.parse('$baseUrl$endpoint'), headers: _headers));
  }

  static Future<dynamic> post(String endpoint, dynamic data) async {
    return _sendRequest(
      () => http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(data),
      ),
    );
  }

  static Future<dynamic> put(String endpoint, dynamic data) async {
    return _sendRequest(
      () => http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(data),
      ),
    );
  }

  static Future<dynamic> delete(String endpoint) async {
    return _sendRequest(() => http.delete(Uri.parse('$baseUrl$endpoint'), headers: _headers));
  }

  static Future<dynamic> _sendRequest(Future<http.Response> Function() request) async {
    try {
      final response = await request();
      return _processResponse(response);
    } on http.ClientException {
      throw Exception(_networkErrorMessage);
    } catch (error) {
      final raw = error.toString().toLowerCase();
      if (raw.contains('socketexception') ||
          raw.contains('failed host lookup') ||
          raw.contains('xmlhttprequest error') ||
          raw.contains('connection refused') ||
          raw.contains('network is unreachable')) {
        throw Exception(_networkErrorMessage);
      }
      rethrow;
    }
  }

  static dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      dynamic errorBody;
      try {
        errorBody = jsonDecode(response.body);
      } catch (e) {
        errorBody = {'error': 'Unknown error occurred (${response.statusCode})'};
      }
      throw Exception(errorBody['error'] ?? 'API Error');
    }
  }
}
