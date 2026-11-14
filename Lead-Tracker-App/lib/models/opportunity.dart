// ignore_for_file: constant_identifier_names

// Opportunity model reflecting the Prisma Opportunity schema
import 'customer.dart';
import 'employee.dart';
import 'lead_note.dart';

enum LeadTemperature {
  HOT,
  WARM,
  COLD;

  static LeadTemperature fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'HOT':
        return LeadTemperature.HOT;
      case 'COLD':
        return LeadTemperature.COLD;
      case 'WARM':
      default:
        return LeadTemperature.WARM;
    }
  }

  String toJson() => name;
}

enum DealStatus {
  PIPELINE,
  CLOSED_WON,
  CLOSED_LOST,
  OTHER;

  static DealStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'CLOSED_WON':
        return DealStatus.CLOSED_WON;
      case 'CLOSED_LOST':
        return DealStatus.CLOSED_LOST;
      case 'OTHER':
        return DealStatus.OTHER;
      case 'PIPELINE':
      default:
        return DealStatus.PIPELINE;
    }
  }

  String toJson() => name;
}

enum ProjectPhase {
  TALKING,
  PROCESSING,
  DEAL_CLOSED;

  static ProjectPhase fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'PROCESSING':
        return ProjectPhase.PROCESSING;
      case 'DEAL_CLOSED':
        return ProjectPhase.DEAL_CLOSED;
      case 'TALKING':
      default:
        return ProjectPhase.TALKING;
    }
  }

  String toJson() => name;

  String get displayName {
    switch (this) {
      case ProjectPhase.TALKING:
        return 'Talking';
      case ProjectPhase.PROCESSING:
        return 'Processing';
      case ProjectPhase.DEAL_CLOSED:
        return 'Deal Closed';
    }
  }
}

class Opportunity {
  final int opportunityId;
  final int customerId;
  final int employeeId;
  final String projectTitle;
  final String? locationName;
  final LeadTemperature leadTemperature;
  final DealStatus dealStatus;
  final ProjectPhase projectPhase;
  final String? closureReason;
  final bool isCompleted;
  final DateTime? completedAt;
  final int? completedBy;
  final DateTime? createdAt;

  // Optional relations populated by backend joins
  final Customer? customer;
  final Employee? assignedEmployee;
  final List<LeadNote>? leadNotes;

  const Opportunity({
    required this.opportunityId,
    required this.customerId,
    required this.employeeId,
    required this.projectTitle,
    this.locationName,
    this.leadTemperature = LeadTemperature.WARM,
    this.dealStatus = DealStatus.PIPELINE,
    this.projectPhase = ProjectPhase.TALKING,
    this.closureReason,
    this.isCompleted = false,
    this.completedAt,
    this.completedBy,
    this.createdAt,
    this.customer,
    this.assignedEmployee,
    this.leadNotes,
  });

  bool get isHot => leadTemperature == LeadTemperature.HOT;
  bool get isWarm => leadTemperature == LeadTemperature.WARM;
  bool get isCold => leadTemperature == LeadTemperature.COLD;

  bool get isClosedWon => dealStatus == DealStatus.CLOSED_WON;
  bool get isClosedLost => dealStatus == DealStatus.CLOSED_LOST;
  bool get isOther => dealStatus == DealStatus.OTHER;
  bool get isClosed => isClosedWon || isClosedLost || isOther;
  bool get isPipeline => dealStatus == DealStatus.PIPELINE;

  factory Opportunity.fromJson(Map<String, dynamic> json) {
    return Opportunity(
      opportunityId: json['opportunity_id'] as int? ?? json['id'] as int? ?? 0,
      customerId: json['customer_id'] as int? ?? 0,
      employeeId: json['employee_id'] as int? ?? 0,
      projectTitle: json['project_title'] as String? ?? '',
      locationName: json['location_name'] as String?,
      leadTemperature: LeadTemperature.fromString(
        json['lead_temperature'] as String?,
      ),
      dealStatus: DealStatus.fromString(json['deal_status'] as String?),
      projectPhase: ProjectPhase.fromString(json['project_phase'] as String?),
      closureReason: json['closure_reason'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      completedBy: json['completed_by'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      customer:
          json['customer'] != null && json['customer'] is Map<String, dynamic>
          ? Customer.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      assignedEmployee:
          json['assigned_employee'] != null &&
              json['assigned_employee'] is Map<String, dynamic>
          ? Employee.fromJson(json['assigned_employee'] as Map<String, dynamic>)
          : null,
      leadNotes: json['lead_notes'] != null && json['lead_notes'] is List
          ? (json['lead_notes'] as List)
                .map((note) => LeadNote.fromJson(note as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'opportunity_id': opportunityId,
      'customer_id': customerId,
      'employee_id': employeeId,
      'project_title': projectTitle,
      if (locationName != null) 'location_name': locationName,
      'lead_temperature': leadTemperature.toJson(),
      'deal_status': dealStatus.toJson(),
      'project_phase': projectPhase.toJson(),
      if (closureReason != null) 'closure_reason': closureReason,
      'is_completed': isCompleted,
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (completedBy != null) 'completed_by': completedBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (customer != null) 'customer': customer!.toJson(),
    };
  }

  Opportunity copyWith({
    int? opportunityId,
    int? customerId,
    int? employeeId,
    String? projectTitle,
    String? locationName,
    LeadTemperature? leadTemperature,
    DealStatus? dealStatus,
    ProjectPhase? projectPhase,
    String? closureReason,
    bool? isCompleted,
    DateTime? completedAt,
    int? completedBy,
    DateTime? createdAt,
    Customer? customer,
    Employee? assignedEmployee,
    List<LeadNote>? leadNotes,
  }) {
    return Opportunity(
      opportunityId: opportunityId ?? this.opportunityId,
      customerId: customerId ?? this.customerId,
      employeeId: employeeId ?? this.employeeId,
      projectTitle: projectTitle ?? this.projectTitle,
      locationName: locationName ?? this.locationName,
      leadTemperature: leadTemperature ?? this.leadTemperature,
      dealStatus: dealStatus ?? this.dealStatus,
      projectPhase: projectPhase ?? this.projectPhase,
      closureReason: closureReason ?? this.closureReason,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      createdAt: createdAt ?? this.createdAt,
      customer: customer ?? this.customer,
      assignedEmployee: assignedEmployee ?? this.assignedEmployee,
      leadNotes: leadNotes ?? this.leadNotes,
    );
  }

  @override
  String toString() =>
      'Opportunity(id: $opportunityId, title: $projectTitle, temp: ${leadTemperature.name}, status: ${dealStatus.name})';
}
