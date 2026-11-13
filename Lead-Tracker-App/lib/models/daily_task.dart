// ignore_for_file: constant_identifier_names

// DailyTask — matches the custom flat response shape from GET /api/tasks/today
// (task.controller.js: getTodayTasks). This is NOT the same as LeadNote.
// The backend joins lead_notes + opportunities + customers + employees into
// one flat record. We model that shape here.

import 'opportunity.dart';

class DailyTaskContactDetails {
  final int customerId;
  final String? phone;
  final String? billingAddress;
  final String? customerType;
  final String? customerTier;

  const DailyTaskContactDetails({
    required this.customerId,
    this.phone,
    this.billingAddress,
    this.customerType,
    this.customerTier,
  });

  factory DailyTaskContactDetails.fromJson(Map<String, dynamic> json) {
    return DailyTaskContactDetails(
      customerId: json['customer_id'] as int? ?? 0,
      phone: json['phone'] as String?,
      billingAddress: json['billing_address'] as String?,
      customerType: json['customer_type'] as String?,
      customerTier: json['customer_tier'] as String?,
    );
  }
}

class DailyTaskOpportunity {
  final int opportunityId;
  final String? projectTitle;
  final String? locationName;
  final LeadTemperature leadTemperature;
  final DealStatus dealStatus;

  const DailyTaskOpportunity({
    required this.opportunityId,
    this.projectTitle,
    this.locationName,
    this.leadTemperature = LeadTemperature.WARM,
    this.dealStatus = DealStatus.PIPELINE,
  });

  factory DailyTaskOpportunity.fromJson(Map<String, dynamic> json) {
    return DailyTaskOpportunity(
      opportunityId: json['opportunity_id'] as int? ?? 0,
      projectTitle: json['project_title'] as String?,
      locationName: json['location_name'] as String?,
      leadTemperature: LeadTemperature.fromString(
        json['lead_temperature'] as String?,
      ),
      dealStatus: DealStatus.fromString(json['deal_status'] as String?),
    );
  }
}

class DailyTaskEmployee {
  final int employeeId;
  final String name;
  final String? email;

  const DailyTaskEmployee({
    required this.employeeId,
    required this.name,
    this.email,
  });

  factory DailyTaskEmployee.fromJson(Map<String, dynamic> json) {
    return DailyTaskEmployee(
      employeeId: json['employee_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}

class DailyTask {
  final int taskId;
  final String companyName;
  final String? location;
  final DailyTaskContactDetails? contactDetails;
  final DailyTaskOpportunity? opportunity;
  final DateTime? scheduledCallDate;
  final String? taskInstruction;
  final bool isCompleted;
  final DateTime? completedAt;
  final DailyTaskEmployee? scheduledBy;
  final DailyTaskEmployee? completedBy;

  const DailyTask({
    required this.taskId,
    required this.companyName,
    this.location,
    this.contactDetails,
    this.opportunity,
    this.scheduledCallDate,
    this.taskInstruction,
    this.isCompleted = false,
    this.completedAt,
    this.scheduledBy,
    this.completedBy,
  });

  bool get isPending => !isCompleted;

  /// Returns true if scheduled_call_date in local time is prior to current local time and task is not completed
  bool get isOverdue {
    if (isCompleted || scheduledCallDate == null) return false;
    return scheduledCallDate!.toLocal().isBefore(DateTime.now());
  }

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    final contactMap = json['contact_details'];
    final oppMap = json['opportunity'];
    final scheduledByMap = json['scheduled_by'];
    final completedByMap = json['completed_by'];

    return DailyTask(
      taskId: json['task_id'] as int? ?? 0,
      companyName: json['company_name'] as String? ?? '',
      location: json['location'] as String?,
      contactDetails: contactMap is Map<String, dynamic>
          ? DailyTaskContactDetails.fromJson(contactMap)
          : null,
      opportunity: oppMap is Map<String, dynamic>
          ? DailyTaskOpportunity.fromJson(oppMap)
          : null,
      scheduledCallDate: json['scheduled_call_date'] != null
          ? DateTime.tryParse(json['scheduled_call_date'].toString())
          : null,
      taskInstruction: json['task_instruction'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      scheduledBy: scheduledByMap is Map<String, dynamic>
          ? DailyTaskEmployee.fromJson(scheduledByMap)
          : null,
      completedBy: completedByMap is Map<String, dynamic>
          ? DailyTaskEmployee.fromJson(completedByMap)
          : null,
    );
  }

  @override
  String toString() =>
      'DailyTask(id: $taskId, company: $companyName, completed: $isCompleted, call: $scheduledCallDate)';
}

/// Top-level response from GET /api/tasks/today
class TodayTasksResult {
  final String queryDate;
  final int totalTasks;
  final int pendingTasks;
  final int completedTasks;
  final List<DailyTask> tasks;

  const TodayTasksResult({
    required this.queryDate,
    required this.totalTasks,
    required this.pendingTasks,
    required this.completedTasks,
    required this.tasks,
  });
}
