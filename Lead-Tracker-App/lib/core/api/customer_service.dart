// Customer Service — wraps all /api/customers/* endpoints
// Response shapes verified against customer.controller.js (Suniti V-2 branch)
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../../models/customer.dart';
import '../../models/opportunity.dart';
import '../../models/lead_note.dart';

/// Lightweight data class for the grouped response from GET /api/customers/existing.
/// Includes per-tier counts returned directly by the backend.
class ExistingCustomersResult {
  final Map<CustomerTier, List<Customer>> grouped;
  final Map<CustomerTier, int> counts;
  final int total;

  const ExistingCustomersResult({
    required this.grouped,
    required this.counts,
    required this.total,
  });
}

/// Lightweight response for GET /api/customers/:id/opportunities
class CustomerOpportunitiesResult {
  final int companyId;
  final String companyName;
  final List<Opportunity> opportunities;

  const CustomerOpportunitiesResult({
    required this.companyId,
    required this.companyName,
    required this.opportunities,
  });
}

/// Response returned by POST /api/customers/new
class CreateCustomerWithOpportunityResult {
  final Customer customer;
  final Opportunity opportunity;
  final LeadNote leadNote;

  const CreateCustomerWithOpportunityResult({
    required this.customer,
    required this.opportunity,
    required this.leadNote,
  });
}

/// Response from GET /api/customers (general search with filters)
class AllCustomersResult {
  final int count;
  final List<Customer> customers;

  const AllCustomersResult({required this.count, required this.customers});
}

class CustomerService {
  final ApiClient _apiClient;

  CustomerService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// GET /api/customers/existing
  /// Returns customers grouped by tier (PREMIUM, LOYAL, INTERIOR_DESIGNER).
  /// Each customer row also includes `total_opportunities` from the backend JOIN.
  /// Only authenticated employees may call this endpoint.
  Future<ExistingCustomersResult> getExistingCustomers() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.customersExisting);
      final data = response.data;

      if (data is! Map<String, dynamic>) {
        throw const UnexpectedApiException(
          message: 'Unexpected response format from /api/customers/existing.',
        );
      }

      final total = data['total'] as int? ?? 0;

      // Parse per-tier counts sent by backend
      final rawCounts = data['counts'] as Map<String, dynamic>? ?? {};
      final counts = <CustomerTier, int>{
        CustomerTier.PREMIUM: (rawCounts['PREMIUM'] as int?) ?? 0,
        CustomerTier.LOYAL: (rawCounts['LOYAL'] as int?) ?? 0,
        CustomerTier.INTERIOR_DESIGNER:
            (rawCounts['INTERIOR_DESIGNER'] as int?) ?? 0,
      };

      // Parse grouped customer lists
      final rawData = data['data'] as Map<String, dynamic>? ?? {};
      final grouped = <CustomerTier, List<Customer>>{
        CustomerTier.PREMIUM: [],
        CustomerTier.LOYAL: [],
        CustomerTier.INTERIOR_DESIGNER: [],
      };

      for (final tierKey in ['PREMIUM', 'LOYAL', 'INTERIOR_DESIGNER']) {
        final tier = CustomerTier.fromString(tierKey);
        if (tier == null) continue;
        final rawList = rawData[tierKey];
        if (rawList is List) {
          grouped[tier] = rawList
              .whereType<Map<String, dynamic>>()
              .map(Customer.fromJson)
              .toList();
        }
      }

      return ExistingCustomersResult(
        grouped: grouped,
        counts: counts,
        total: total,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(
        message: 'Failed to load existing customers: $e',
      );
    }
  }

  /// GET /api/customers/:id/opportunities
  /// Returns the customer's company name and their list of opportunities/plant locations.
  Future<CustomerOpportunitiesResult> getCustomerOpportunities(
    int customerId,
  ) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.customerOpportunities(customerId),
      );
      final data = response.data;

      if (data is! Map<String, dynamic>) {
        throw const UnexpectedApiException(
          message: 'Unexpected response format from customer opportunities endpoint.',
        );
      }

      final companyId = data['company_id'] as int? ?? customerId;
      final companyName = data['company_name'] as String? ?? '';

      final rawOpps = data['opportunities'];
      final opportunities = <Opportunity>[];
      if (rawOpps is List) {
        for (final item in rawOpps) {
          if (item is Map<String, dynamic>) {
            opportunities.add(Opportunity.fromJson(item));
          }
        }
      }

      return CustomerOpportunitiesResult(
        companyId: companyId,
        companyName: companyName,
        opportunities: opportunities,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(
        message: 'Failed to load opportunities for customer $customerId: $e',
      );
    }
  }

  /// POST /api/customers/new
  /// Creates a new customer, initial opportunity (PIPELINE), and scheduled lead note.
  Future<CreateCustomerWithOpportunityResult> createCustomerWithOpportunity({
    required String name,
    required String projectTitle,
    required String locationName,
    String? phone,
    String? billingAddress,
    String? tier,
    String leadTemperature = 'WARM',
    String? conclusionNotes,
    DateTime? nextCallDate,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name.trim(),
        'project_title': projectTitle.trim(),
        'location_name': locationName.trim(),
        'lead_temperature': leadTemperature,
      };

      if (tier != null && tier.trim().isNotEmpty) {
        body['tier'] = tier.trim();
      }
      if (phone != null && phone.trim().isNotEmpty) {
        body['phone'] = phone.trim();
      }
      if (billingAddress != null && billingAddress.trim().isNotEmpty) {
        body['billing_address'] = billingAddress.trim();
      }
      if (conclusionNotes != null && conclusionNotes.trim().isNotEmpty) {
        body['conclusion_notes'] = conclusionNotes.trim();
      }
      if (nextCallDate != null) {
        body['next_call_date'] = nextCallDate.toIso8601String();
      }

      final response = await _apiClient.post(
        ApiEndpoints.customersNew,
        data: body,
      );
      final data = response.data;

      if (data is! Map<String, dynamic>) {
        throw const UnexpectedApiException(
          message: 'Unexpected response from create new customer endpoint.',
        );
      }

      final customerMap = data['customer'] as Map<String, dynamic>?;
      final oppMap = data['opportunity'] as Map<String, dynamic>?;
      final noteMap = data['lead_note'] as Map<String, dynamic>?;

      if (customerMap == null || oppMap == null || noteMap == null) {
        throw const UnexpectedApiException(
          message: 'Incomplete response received from customer creation.',
        );
      }

      return CreateCustomerWithOpportunityResult(
        customer: Customer.fromJson(customerMap),
        opportunity: Opportunity.fromJson(oppMap),
        leadNote: LeadNote.fromJson(noteMap),
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(message: 'Failed to create customer: $e');
    }
  }

  /// GET /api/customers?customer_type=NEW
  /// Returns customers created with customer_type = 'NEW'.
  Future<List<Customer>> getNewCustomers() async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.customers,
        queryParameters: {'customer_type': 'NEW'},
      );
      final data = response.data;

      if (data is Map<String, dynamic>) {
        final rawList = data['customers'] ?? data['data'];
        if (rawList is List) {
          return rawList
              .whereType<Map<String, dynamic>>()
              .map(Customer.fromJson)
              .toList();
        }
      }
      return [];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(message: 'Failed to load new customers: $e');
    }
  }

  /// GET /api/customers with optional query params for search/filter.
  /// Supports: search, location, customer_type, tier, is_blocklisted.
  Future<AllCustomersResult> getAllCustomers({
    String? search,
    String? location,
    String? customerType,
    String? tier,
    bool? isBlocklisted,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (location != null && location.trim().isNotEmpty) {
        queryParams['location'] = location.trim();
      }
      if (customerType != null && customerType.trim().isNotEmpty) {
        queryParams['customer_type'] = customerType.trim();
      }
      if (tier != null && tier.trim().isNotEmpty) {
        queryParams['tier'] = tier.trim();
      }
      if (isBlocklisted != null) {
        queryParams['is_blocklisted'] = isBlocklisted.toString();
      }

      final response = await _apiClient.get(
        ApiEndpoints.customers,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final data = response.data;

      if (data is Map<String, dynamic>) {
        final count = data['count'] as int? ?? 0;
        final rawList = data['customers'] ?? data['data'];
        final customers = <Customer>[];
        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map<String, dynamic>) {
              customers.add(Customer.fromJson(item));
            }
          }
        }
        return AllCustomersResult(count: count, customers: customers);
      }
      return const AllCustomersResult(count: 0, customers: []);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(message: 'Failed to load customers: $e');
    }
  }

  /// GET /api/customers/blocklisted
  /// (or filtered check for blocklisted accounts).
  /// Note: Handled gracefully if 403 or 404 is returned by backend.
  Future<List<Customer>> getBlocklistedCustomers() async {
    try {
      // First attempt documented /api/customers/blocklisted
      final response = await _apiClient.get(ApiEndpoints.customersBlocklisted);
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map(Customer.fromJson)
            .toList();
      } else if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(Customer.fromJson)
            .toList();
      }
      return [];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(
        message: 'Failed to load blocklisted customers: $e',
      );
    }
  }

  /// PATCH /api/admin/customers/:id/blocklist
  /// or PATCH /api/customers/:id/blocklist
  /// Toggles or sets is_blocklisted for a customer.
  Future<Customer> toggleBlocklist(
    int customerId, {
    bool? isBlocklisted,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (isBlocklisted != null) {
        body['is_blocklisted'] = isBlocklisted;
      }

      // Try /api/admin/customers/:id/blocklist
      final response = await _apiClient.patch(
        ApiEndpoints.adminCustomerBlocklist(customerId),
        data: body.isNotEmpty ? body : null,
      );

      final data = response.data;
      if (data is Map<String, dynamic> &&
          data['customer'] is Map<String, dynamic>) {
        return Customer.fromJson(data['customer'] as Map<String, dynamic>);
      }
      throw const UnexpectedApiException(
        message: 'Invalid response from blocklist endpoint.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(
        message:
            'Failed to update blocklist status for customer $customerId: $e',
      );
    }
  }
}
