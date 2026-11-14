// ignore_for_file: constant_identifier_names

// Customer model reflecting the Prisma Customer schema
// Keeps CustomerType (NEW / EXISTING) and CustomerTier (PREMIUM / LOYAL / INTERIOR_DESIGNER) separate.

enum CustomerType {
  NEW,
  EXISTING;

  static CustomerType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'EXISTING':
        return CustomerType.EXISTING;
      case 'NEW':
      default:
        return CustomerType.NEW;
    }
  }

  String toJson() => name;
}

enum CustomerTier {
  PREMIUM,
  LOYAL,
  INTERIOR_DESIGNER;

  static CustomerTier? fromString(String? value) {
    if (value == null) return null;
    switch (value.toUpperCase()) {
      case 'PREMIUM':
        return CustomerTier.PREMIUM;
      case 'LOYAL':
        return CustomerTier.LOYAL;
      case 'INTERIOR_DESIGNER':
        return CustomerTier.INTERIOR_DESIGNER;
      default:
        return null;
    }
  }

  String toJson() => name;

  String get displayName {
    switch (this) {
      case CustomerTier.PREMIUM:
        return 'Premium Customer';
      case CustomerTier.LOYAL:
        return 'Loyal Customer';
      case CustomerTier.INTERIOR_DESIGNER:
        return 'Interior Designer';
    }
  }
}

class Customer {
  final int customerId;
  final String name;
  final CustomerType customerType;
  final CustomerTier? tier;
  final String? phone;
  final String? billingAddress;
  final bool isBlocklisted;
  final String? blocklistReason;
  final DateTime? createdAt;

  const Customer({
    required this.customerId,
    required this.name,
    this.customerType = CustomerType.NEW,
    this.tier,
    this.phone,
    this.billingAddress,
    this.isBlocklisted = false,
    this.blocklistReason,
    this.createdAt,
  });

  bool get isNew => customerType == CustomerType.NEW;
  bool get isExisting => customerType == CustomerType.EXISTING;

  /// Returns the UI category badge title:
  /// For NEW customers, displays "New Customer".
  /// For EXISTING customers, displays their specific tier name or "Existing Customer".
  String get categoryDisplayTitle {
    if (isNew) return 'New Customer';
    return tier?.displayName ?? 'Existing Customer';
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      customerId: json['customer_id'] as int? ?? json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      customerType: CustomerType.fromString(json['customer_type'] as String?),
      tier: CustomerTier.fromString(json['tier'] as String?),
      phone: json['phone'] as String?,
      billingAddress: json['billing_address'] as String?,
      isBlocklisted: json['is_blocklisted'] as bool? ?? false,
      blocklistReason: json['blocklist_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'name': name,
      'customer_type': customerType.toJson(),
      'tier': tier?.toJson(),
      if (phone != null) 'phone': phone,
      if (billingAddress != null) 'billing_address': billingAddress,
      'is_blocklisted': isBlocklisted,
      if (blocklistReason != null) 'blocklist_reason': blocklistReason,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Customer copyWith({
    int? customerId,
    String? name,
    CustomerType? customerType,
    CustomerTier? tier,
    String? phone,
    String? billingAddress,
    bool? isBlocklisted,
    String? blocklistReason,
    bool clearBlocklistReason = false,
    DateTime? createdAt,
  }) {
    return Customer(
      customerId: customerId ?? this.customerId,
      name: name ?? this.name,
      customerType: customerType ?? this.customerType,
      tier: tier ?? this.tier,
      phone: phone ?? this.phone,
      billingAddress: billingAddress ?? this.billingAddress,
      isBlocklisted: isBlocklisted ?? this.isBlocklisted,
      blocklistReason: clearBlocklistReason
          ? null
          : (blocklistReason ?? this.blocklistReason),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Customer(id: $customerId, name: $name, type: ${customerType.name}, tier: ${tier?.name})';
}
