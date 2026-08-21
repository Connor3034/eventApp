import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
  });

  final int id;
  final String username;
  final String email;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['user_id'] as int,
      username: json['user_name'] as String,
      email: json['email'] as String,
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

class AuthService extends ChangeNotifier {
  AuthService({
    http.Client? client,
    FlutterSecureStorage? storage,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  static const _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );
  static const _tokenKey = 'event_app_access_token';

  final http.Client _client;
  final FlutterSecureStorage _storage;
  AuthUser? user;
  String? token;
  bool isInitializing = true;

  bool get isAuthenticated => user != null && token != null;

  Future<void> initialize() async {
    try {
      final savedToken = await _storage.read(key: _tokenKey);
      if (savedToken == null || savedToken.isEmpty) {
        return;
      }

      final response = await _client.get(
        Uri.parse('$_apiBaseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $savedToken'},
      );
      if (response.statusCode == 200) {
        token = savedToken;
        user = AuthUser.fromJson(_decode(response)['user'] as Map<String, dynamic>);
      } else {
        await _storage.delete(key: _tokenKey);
      }
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    final response = await _client.post(
      Uri.parse('$_apiBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    await _acceptAuthResponse(response);
  }

  Future<void> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_apiBaseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_name': username.trim(),
        'email': email.trim(),
        'password': password,
      }),
    );
    await _acceptAuthResponse(response);
  }

  Future<void> signOut() async {
    token = null;
    user = null;
    await _storage.delete(key: _tokenKey);
    notifyListeners();
  }

  Future<void> _acceptAuthResponse(http.Response response) async {
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(body['error'] as String? ?? 'Authentication failed');
    }

    final receivedToken = body['token'] as String?;
    final receivedUser = body['user'] as Map<String, dynamic>?;
    if (receivedToken == null || receivedUser == null) {
      throw const AuthException('The server returned an invalid authentication response');
    }

    token = receivedToken;
    user = AuthUser.fromJson(receivedUser);
    await _storage.write(key: _tokenKey, value: receivedToken);
    notifyListeners();
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AuthException('The server returned an invalid response');
    }
  }
}