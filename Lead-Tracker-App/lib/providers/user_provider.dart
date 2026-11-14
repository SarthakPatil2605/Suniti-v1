import 'package:flutter/foundation.dart';

import '../core/api/api_exceptions.dart';
import '../core/api/user_service.dart';
import '../models/employee.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService;

  List<Employee> _users = [];
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;
  String? _successMessage;

  UserProvider({UserService? userService})
    : _userService = userService ?? UserService();

  List<Employee> get users => _users;
  int get userCount => _users.length;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  /// Loads all CRM users via GET /api/users (Admin only)
  Future<void> loadUsers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _users = await _userService.getUsers();
      _errorMessage = null;
    } on ForbiddenException {
      _errorMessage =
          'Access restricted: only Administrators can view CRM users.';
    } on UnauthorizedException {
      _errorMessage = 'Session expired. Please sign in again.';
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to load CRM users.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new CRM user via POST /api/users (Admin only)
  Future<bool> createUser({
    required String email,
    required String password,
    required String role,
    String? name,
  }) async {
    _isCreating = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final newUser = await _userService.createUser(
        email: email,
        password: password,
        role: role,
        name: name,
      );

      // Add to local list and sort newest first
      _users.removeWhere((u) => u.employeeId == newUser.employeeId);
      _users.insert(0, newUser);

      _successMessage =
          'User "${newUser.email}" (${newUser.role.displayName}) created successfully!';
      _errorMessage = null;
      notifyListeners();
      return true;
    } on ConflictException catch (e) {
      _errorMessage = e.message;
      return false;
    } on ForbiddenException {
      _errorMessage = 'Permission denied: only Administrators are authorized to provision CRM accounts.';
      return false;
    } on BadRequestException catch (e) {
      _errorMessage = e.message;
      return false;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Failed to create user. Please try again.';
      return false;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
