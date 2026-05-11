import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:vail_app/core/config/app_config.dart';
import 'package:vail_app/data/services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AppConfig _config = GetIt.I<AppConfig>();

  bool _isLoading = false;
  String _error = '';

  bool get isLoading => _isLoading;
  String get error => _error;
  bool get isAuthenticated => _config.isAuthenticated;
  String get userId => _config.userId;

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final service = AuthService(endpoint: _config.endpoint);
      final response = await service.login(email, password);
      await _config.setToken(response.token);
      await _config.setUserId(response.userId);
    } on AuthException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Something went wrong.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> register(String email, String password) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final service = AuthService(endpoint: _config.endpoint);
      final response = await service.register(email, password);
      await _config.setToken(response.token);
      await _config.setUserId(response.userId);
    } on AuthException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Something went wrong.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _config.clearAuth();
    notifyListeners();
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}
