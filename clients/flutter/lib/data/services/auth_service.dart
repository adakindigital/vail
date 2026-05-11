import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vail_app/data/models/api/auth/auth_response.dart';

class AuthService {
  final String endpoint;

  AuthService({required this.endpoint});

  Future<AuthResponse> register(String email, String password) async {
    return _post('/auth/register', {'email': email, 'password': password});
  }

  Future<AuthResponse> login(String email, String password) async {
    return _post('/auth/login', {'email': email, 'password': password});
  }

  Future<AuthResponse> _post(String path, Map<String, String> body) async {
    final uri = Uri.parse('$endpoint$path');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return AuthResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    String message = 'Something went wrong.';
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['detail'] is String) {
        message = json['detail'] as String;
      }
    } catch (_) {}
    throw AuthException(message);
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}
