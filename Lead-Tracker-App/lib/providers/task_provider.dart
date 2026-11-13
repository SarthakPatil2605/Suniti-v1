// Task and Follow-up state provider — wired to TaskService
import 'package:flutter/foundation.dart';

import '../core/api/task_service.dart';
import '../core/api/api_exceptions.dart';
import '../models/daily_task.dart';

class TaskProvider extends ChangeNotifier {
  final TaskService _service;

  TaskProvider({TaskService? service}) : _service = service ?? TaskService();

  // --- State ---
  List<DailyTask> _todayTasks = [];
  int _pendingCount = 0;
  int _completedCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // --- Getters ---
  List<DailyTask> get todayTasks => _todayTasks;

  /// Returns only tasks that are scheduled specifically for today (in user's local timezone)
  /// and NOT completed. Future and overdue calls are excluded.
  List<DailyTask> get dueTodayTasks {
    final now = DateTime.now();
    return _todayTasks.where((task) {
      if (task.isCompleted) return false;
      if (task.scheduledCallDate == null) return false;
      // Convert to local time before comparing year, month, and day
      final localDate = task.scheduledCallDate!.toLocal();
      return localDate.year == now.year &&
          localDate.month == now.month &&
          localDate.day == now.day;
    }).toList();
  }

  /// Accurate badge notification count for Home bell
  int get todayDueNotificationCount => dueTodayTasks.length;

  int get pendingTasksCount => _pendingCount;
  int get completedTasksCount => _completedCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // --- Actions ---

  /// Loads scheduled tasks for today from GET /api/tasks/today.
  /// Pass [includeOverdue] = true to also fetch overdue pending tasks.
  Future<void> loadTodayTasks({bool includeOverdue = false}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final result = await _service.getTodayTasks(
        includeOverdue: includeOverdue,
      );
      _todayTasks = result.tasks;
      _pendingCount = result.pendingTasks;
      _completedCount = result.completedTasks;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage =
          'An unexpected error occurred while loading today\'s tasks.';
    } finally {
      _setLoading(false);
    }
  }

  /// Mark a task complete via PATCH /api/tasks/:id/complete.
  Future<void> completeTask(
    int taskId, {
    String? conclusionNotes,
    String? leadTemperature,
    String? dealStatus,
    DateTime? nextCallDate,
  }) async {
    try {
      await _service.completeTask(
        taskId,
        conclusionNotes: conclusionNotes,
        leadTemperature: leadTemperature,
        dealStatus: dealStatus,
        nextCallDate: nextCallDate,
      );
      // Refresh today's tasks after completion
      await loadTodayTasks();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to complete task.';
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
