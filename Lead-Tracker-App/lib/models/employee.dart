// ignore_for_file: constant_identifier_names

// Employee model reflecting the Prisma Employee schema

enum EmployeeRole {
  ADMIN,
  MANAGER,
  SALES_REP;

  static EmployeeRole fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'ADMIN':
        return EmployeeRole.ADMIN;
      case 'MANAGER':
        return EmployeeRole.MANAGER;
      case 'SALES_REP':
      default:
        return EmployeeRole.SALES_REP;
    }
  }

  String toJson() => name;
}

class Employee {
  final int employeeId;
  final String name;
  final String email;
  final EmployeeRole role;
  final DateTime? createdAt;

  const Employee({
    required this.employeeId,
    required this.name,
    required this.email,
    this.role = EmployeeRole.SALES_REP,
    this.createdAt,
  });

  bool get isAdmin => role == EmployeeRole.ADMIN;
  bool get isManager => role == EmployeeRole.MANAGER;
  bool get isSalesRep => role == EmployeeRole.SALES_REP;

  /// Only ADMIN has administrative/management privileges according to the backend schema and verifyAdmin middleware.
  bool get canManage => isAdmin;

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      employeeId: json['employee_id'] as int? ?? json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: EmployeeRole.fromString(json['role'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'name': name,
      'email': email,
      'role': role.toJson(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Employee copyWith({
    int? employeeId,
    String? name,
    String? email,
    EmployeeRole? role,
    DateTime? createdAt,
  }) {
    return Employee(
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Employee(id: $employeeId, name: $name, role: ${role.name})';
}
