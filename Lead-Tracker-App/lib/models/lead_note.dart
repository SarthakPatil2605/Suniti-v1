// LeadNote model reflecting the Prisma LeadNote schema
import 'employee.dart';

class LeadNote {
  final int noteId;
  final int opportunityId;
  final int employeeId;
  final String? conclusionNotes;
  final DateTime? nextCallDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final int? completedBy;
  final DateTime? createdAt;

  // Optional relations populated by backend joins
  final Employee? author;
  final Employee? completedByEmployee;

  const LeadNote({
    required this.noteId,
    required this.opportunityId,
    required this.employeeId,
    this.conclusionNotes,
    this.nextCallDate,
    this.isCompleted = false,
    this.completedAt,
    this.completedBy,
    this.createdAt,
    this.author,
    this.completedByEmployee,
  });

  bool get isPending => !isCompleted;
  bool get hasScheduledCall => nextCallDate != null;

  /// Returns true if next_call_date is before current time and task is not completed
  bool get isOverdue {
    if (isCompleted || nextCallDate == null) return false;
    return nextCallDate!.isBefore(DateTime.now());
  }

  factory LeadNote.fromJson(Map<String, dynamic> json) {
    return LeadNote(
      noteId: json['note_id'] as int? ?? json['id'] as int? ?? 0,
      opportunityId: json['opportunity_id'] as int? ?? 0,
      employeeId: json['employee_id'] as int? ?? 0,
      conclusionNotes: json['conclusion_notes'] as String?,
      nextCallDate: json['next_call_date'] != null
          ? DateTime.tryParse(json['next_call_date'].toString())
          : null,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      completedBy: json['completed_by'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      author: json['author'] != null && json['author'] is Map<String, dynamic>
          ? Employee.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      completedByEmployee:
          json['completed_by_employee'] != null &&
              json['completed_by_employee'] is Map<String, dynamic>
          ? Employee.fromJson(
              json['completed_by_employee'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'note_id': noteId,
      'opportunity_id': opportunityId,
      'employee_id': employeeId,
      if (conclusionNotes != null) 'conclusion_notes': conclusionNotes,
      if (nextCallDate != null)
        'next_call_date': nextCallDate!.toIso8601String(),
      'is_completed': isCompleted,
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (completedBy != null) 'completed_by': completedBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  LeadNote copyWith({
    int? noteId,
    int? opportunityId,
    int? employeeId,
    String? conclusionNotes,
    DateTime? nextCallDate,
    bool? isCompleted,
    DateTime? completedAt,
    int? completedBy,
    DateTime? createdAt,
    Employee? author,
    Employee? completedByEmployee,
  }) {
    return LeadNote(
      noteId: noteId ?? this.noteId,
      opportunityId: opportunityId ?? this.opportunityId,
      employeeId: employeeId ?? this.employeeId,
      conclusionNotes: conclusionNotes ?? this.conclusionNotes,
      nextCallDate: nextCallDate ?? this.nextCallDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      createdAt: createdAt ?? this.createdAt,
      author: author ?? this.author,
      completedByEmployee: completedByEmployee ?? this.completedByEmployee,
    );
  }

  @override
  String toString() =>
      'LeadNote(id: $noteId, opp: $opportunityId, completed: $isCompleted, nextCall: $nextCallDate)';
}
