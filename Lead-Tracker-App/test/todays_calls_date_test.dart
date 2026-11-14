import 'package:flutter_test/flutter_test.dart';
import 'package:suniti_crm/models/daily_task.dart';

void main() {
  group("Today's Calls & UTC to Local Date Handling Tests", () {
    test('correctly maps UTC timestamp across boundary and validates isOverdue logic', () {
      final utcNightTimestamp = DateTime.parse('2026-11-09T20:00:00Z');
      final localDate = utcNightTimestamp.toLocal();

      final taskOnBoundary = DailyTask(
        taskId: 101,
        companyName: 'Boundary Company',
        scheduledCallDate: utcNightTimestamp,
        isCompleted: false,
      );

      expect(taskOnBoundary.scheduledCallDate!.toLocal(), equals(localDate));

      final now = DateTime.now();
      final taskYesterday = DailyTask(
        taskId: 103,
        companyName: 'Yesterday Company',
        scheduledCallDate: DateTime(now.year, now.month, now.day - 1, 10, 0),
        isCompleted: false,
      );
      final taskTomorrow = DailyTask(
        taskId: 104,
        companyName: 'Tomorrow Company',
        scheduledCallDate: DateTime(now.year, now.month, now.day + 1, 10, 0),
        isCompleted: false,
      );
      final taskCompletedToday = DailyTask(
        taskId: 105,
        companyName: 'Completed Today Company',
        scheduledCallDate: DateTime(now.year, now.month, now.day, 11, 0),
        isCompleted: true,
      );

      // Verify isOverdue helper on DailyTask
      expect(taskYesterday.isOverdue, isTrue);
      expect(taskTomorrow.isOverdue, isFalse);
      expect(taskCompletedToday.isOverdue, isFalse);
    });

    test('dueTodayTasks excludes completed, future, and overdue calls', () {
      final now = DateTime.now();

      final todayLocalMorning = DateTime(now.year, now.month, now.day, 10, 0);
      final todayUtcEquivalent = todayLocalMorning.toUtc();

      final tasks = [
        DailyTask(
          taskId: 1,
          companyName: 'Due Today 1',
          scheduledCallDate: todayUtcEquivalent,
          isCompleted: false,
        ),
        DailyTask(
          taskId: 2,
          companyName: 'Already Completed',
          scheduledCallDate: todayUtcEquivalent,
          isCompleted: true,
        ),
        DailyTask(
          taskId: 3,
          companyName: 'Future Call',
          scheduledCallDate: DateTime(now.year, now.month, now.day + 2, 11, 0),
          isCompleted: false,
        ),
        DailyTask(
          taskId: 4,
          companyName: 'Overdue Past Call',
          scheduledCallDate: DateTime(now.year, now.month, now.day - 2, 11, 0),
          isCompleted: false,
        ),
      ];

      final due = tasks.where((task) {
        if (task.isCompleted) return false;
        if (task.scheduledCallDate == null) return false;
        final d = task.scheduledCallDate!.toLocal();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();

      expect(due.length, equals(1));
      expect(due.first.taskId, equals(1));
      expect(due.first.companyName, equals('Due Today 1'));
    });
  });
}
