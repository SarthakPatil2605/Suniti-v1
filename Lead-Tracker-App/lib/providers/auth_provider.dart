// Authentication state provider managing session lifecycle and user state
import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../core/api/api_constants.dart';
import '../core/api/api_exceptions.dart';
import '../core/api/auth_service.dart';
import '../models/employee.dart';

enum AuthStatus { initial, authenticating, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final ApiClient _apiClient;

  AuthStatus _status = AuthStatus.initial;
  Employee? _currentEmployee;
  String? _errorMessage;

  AuthProvider({AuthService? authService, ApiClient? apiClient})
    : _authService = authService ?? AuthService(),
      _apiClient = apiClient ?? ApiClient();

  AuthStatus get status => _status;
  bool get isInitial => _status == AuthStatus.initial;
  bool get isAuthenticating => _status == AuthStatus.authenticating;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isUnauthenticated => _status == AuthStatus.unauthenticated;

  Employee? get currentEmployee => _currentEmployee;
  String? get errorMessage => _errorMessage;

  /// Checks for an existing persisted session on app launch
  Future<void> checkAuthStatus() async {
    _status = AuthStatus.initial;
    _errorMessage = null;

    try {
      final token = await _apiClient.secureStorage.read(
        key: ApiConstants.tokenStorageKey,
      );

      if (token == null || token.isEmpty) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      // Validate token with GET /api/auth/me
      final employee = await _authService.getMe();
      _currentEmployee = employee;
      _status = AuthStatus.authenticated;
    } catch (e) {
      // If token is expired, invalid, or server returns 401, clear storage
      await _authService.logout();
      _currentEmployee = null;
      _status = AuthStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  /// Logs in employee via email and password
  Future<bool> login({required String email, required String password}) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final employee = await _authService.login(
        email: email,
        password: password,
      );
      _currentEmployee = employee;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during login.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Clears user session and JWT token
  Future<void> logout() async {
    await _authService.logout();
    _currentEmployee = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Clears any transient error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Sets current employee and updates auth state (for tests and session sync)
  void setCurrentEmployee(Employee? employee) {
    _currentEmployee = employee;
    _status = employee != null
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }
}
