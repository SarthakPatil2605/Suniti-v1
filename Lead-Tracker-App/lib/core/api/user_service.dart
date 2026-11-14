// User Management service interacting with /api/users endpoints
import '../../models/employee.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';

class UserService {
  final ApiClient _apiClient;

  UserService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Retrieves list of all CRM users/employees (Admin only) via GET /api/users
  Future<List<Employee>> getUsers() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.users);
      final data = response.data;

      if (data is Map<String, dynamic>) {
        final list = data['users'] ?? data['employees'] ?? data['data'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map(Employee.fromJson)
              .toList();
        }
      } else if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(Employee.fromJson)
            .toList();
      }

      return [];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(message: 'Failed to retrieve users: $e');
    }
  }

  /// Creates a new CRM user (Admin only) via POST /api/users
  Future<Employee> createUser({
    required String email,
    required String password,
    required String role,
    String? name,
  }) async {
    try {
      final payload = <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'role': role.trim(),
      };

      if (name != null && name.trim().isNotEmpty) {
        payload['name'] = name.trim();
      }

      final response = await _apiClient.post(ApiEndpoints.users, data: payload);

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const UnexpectedApiException(
          message: 'Malformed response received from user creation endpoint.',
        );
      }

      final userMap =
          (data['user'] ?? data['employee'] ?? data['data'])
              as Map<String, dynamic>?;

      if (userMap == null) {
        throw const UnexpectedApiException(
          message: 'User profile was missing from user creation response.',
        );
      }

      return Employee.fromJson(userMap);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(message: 'Failed to create user: $e');
    }
  }
}
