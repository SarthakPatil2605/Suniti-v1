// Authentication service interacting with Suniti backend auth endpoints
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../../models/employee.dart';

class AuthService {
  final ApiClient _apiClient;

  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Authenticates employee with email and password via POST /api/auth/login
  Future<Employee> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.login,
        data: {'email': email.trim(), 'password': password},
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnexpectedApiException(
          message: 'Malformed response received from login endpoint.',
        );
      }

      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const UnexpectedApiException(
          message: 'Authentication token was missing from login response.',
        );
      }

      // Persist the JWT token
      await _apiClient.saveAuthToken(token);

      // Extract employee object (backend uses 'user' key)
      final userMap =
          (data['user'] ?? data['employee']) as Map<String, dynamic>?;
      if (userMap == null) {
        throw const UnexpectedApiException(
          message: 'User profile was missing from login response.',
        );
      }

      return Employee.fromJson(userMap);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(
        message: 'An error occurred during authentication: $e',
      );
    }
  }

  /// Retrieves current authenticated employee profile via GET /api/auth/me
  Future<Employee> getMe() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.me);
      final data = response.data;

      if (data is! Map<String, dynamic>) {
        throw const UnexpectedApiException(
          message: 'Malformed response received from profile endpoint.',
        );
      }

      final userMap =
          (data['user'] ?? data['employee']) as Map<String, dynamic>?;
      if (userMap == null) {
        throw const UnexpectedApiException(
          message: 'User profile was missing from response.',
        );
      }

      return Employee.fromJson(userMap);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(
        message: 'Failed to retrieve user profile: $e',
      );
    }
  }

  /// Clears stored JWT token and user session
  Future<void> logout() async {
    await _apiClient.clearAuthToken();
  }
}
