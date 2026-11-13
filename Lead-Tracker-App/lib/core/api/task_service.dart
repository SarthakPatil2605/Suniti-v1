// Task Service — wraps /api/tasks/* endpoints
// Response shapes verified against task.controller.js (Suniti V-2 branch)
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../../models/daily_task.dart';

class TaskService {
  final ApiClient _apiClient;

  TaskService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /api/tasks/today
  /// Query params:
  ///   date: YYYY-MM-DD (defaults to server date)
  ///   include_overdue: 'true' | 'false' (defaults to 'false')
  ///
  /// Returns a custom flat record per task joining lead_notes + opportunities
  /// + customers + employees. Use [DailyTask] — not LeadNote.
  Future<TodayTasksResult> getTodayTasks({
    DateTime? date,
    bool includeOverdue = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null) {
        // Backend accepts YYYY-MM-DD
        queryParams['date'] =
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
      }
      if (includeOverdue) {
        queryParams['include_overdue'] = 'true';
      }

      final response = await _apiClient.get(
        ApiEndpoints.tasksToday,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final data = response.data;

      if (data is! Map<String, dynamic>) {
        throw const UnexpectedApiException(
          message: 'Unexpected response format from /api/tasks/today.',
        );
      }

      final rawTasks = data['tasks'];
      final tasks = <DailyTask>[];
      if (rawTasks is List) {
        for (final item in rawTasks) {
          if (item is Map<String, dynamic>) {
            tasks.add(DailyTask.fromJson(item));
          }
        }
      }

      return TodayTasksResult(
        queryDate: data['query_date'] as String? ?? '',
        totalTasks: data['total_tasks'] as int? ?? 0,
        pendingTasks: data['pending_tasks'] as int? ?? 0,
        completedTasks: data['completed_tasks'] as int? ?? 0,
        tasks: tasks,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(
        message: 'Failed to load today\'s tasks: $e',
      );
    }
  }

  /// PATCH /api/tasks/:id/complete
  /// Marks a task (lead note) as done. Optionally updates the opportunity's
  /// tracking fields and schedules a subsequent follow-up note.
  /// Body (all optional):
  ///   conclusion_notes: String
  ///   lead_temperature: 'HOT' | 'WARM' | 'COLD'
  ///   deal_status: 'PIPELINE' | 'CLOSED_WON' | 'CLOSED_LOST'
  ///   next_call_date: ISO timestamp
  Future<void> completeTask(
    int taskId, {
    String? conclusionNotes,
    String? leadTemperature,
    String? dealStatus,
    DateTime? nextCallDate,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (conclusionNotes != null) body['conclusion_notes'] = conclusionNotes;
      if (leadTemperature != null) body['lead_temperature'] = leadTemperature;
      if (dealStatus != null) body['deal_status'] = dealStatus;
      if (nextCallDate != null) {
        body['next_call_date'] = nextCallDate.toIso8601String();
      }

      await _apiClient.patch(
        ApiEndpoints.taskComplete(taskId),
        data: body.isNotEmpty ? body : null,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(
        message: 'Failed to complete task $taskId: $e',
      );
    }
  }
}
