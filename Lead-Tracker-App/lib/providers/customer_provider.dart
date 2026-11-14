// Customer state provider — wired to CustomerService
import 'package:flutter/foundation.dart';

import '../core/api/customer_service.dart';
import '../core/api/api_exceptions.dart';
import '../models/customer.dart';

class CustomerProvider extends ChangeNotifier {
  final CustomerService _service;

  CustomerProvider({CustomerService? service})
    : _service = service ?? CustomerService();

  // --- State ---
  Map<CustomerTier, List<Customer>> _groupedExistingCustomers = {
    CustomerTier.PREMIUM: [],
    CustomerTier.LOYAL: [],
    CustomerTier.INTERIOR_DESIGNER: [],
  };

  Map<CustomerTier, int> _tierCounts = {
    CustomerTier.PREMIUM: 0,
    CustomerTier.LOYAL: 0,
    CustomerTier.INTERIOR_DESIGNER: 0,
  };

  List<Customer> _newCustomers = [];
  int _newCustomersCount = 0;

  List<Customer> _blocklistedCustomers = [];
  List<Customer> _filteredCustomers = [];

  int _existingTotal = 0;
  bool _isLoading = false;
  bool _isFilterLoading = false;
  String? _errorMessage;

  // --- Getters ---
  Map<CustomerTier, List<Customer>> get groupedExistingCustomers =>
      _groupedExistingCustomers;
  Map<CustomerTier, int> get tierCounts => _tierCounts;
  List<Customer> get newCustomers => _newCustomers;
  int get newCustomersCount => _newCustomersCount;
  List<Customer> get blocklistedCustomers => _blocklistedCustomers;
  List<Customer> get filteredCustomers => _filteredCustomers;
  int get existingTotal => _existingTotal;
  bool get isLoading => _isLoading;
  bool get isFilterLoading => _isFilterLoading;
  String? get errorMessage => _errorMessage;

  List<Customer> customersForTier(CustomerTier tier) =>
      _groupedExistingCustomers[tier] ?? [];

  List<Customer> get allExistingCustomers {
    final list = <Customer>[];
    for (final tierList in _groupedExistingCustomers.values) {
      list.addAll(tierList);
    }
    return list;
  }

  int countForTier(CustomerTier tier) => _tierCounts[tier] ?? 0;

  int get totalExistingCustomers =>
      _tierCounts.values.fold(0, (sum, c) => sum + c);

  // --- Actions ---

  /// Loads existing customers grouped by tier from GET /api/customers/existing.
  /// Also extracts new_customers_count from the same response.
  Future<void> loadExistingCustomers() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final result = await _service.getExistingCustomers();
      _groupedExistingCustomers = result.grouped;
      _tierCounts = result.counts;
      _existingTotal = result.total;
      _errorMessage = null;
    } on ForbiddenException {
      _errorMessage =
          'Access restricted: you do not have permission to view customers.';
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred while loading customers.';
    } finally {
      _setLoading(false);
    }
  }

  /// Loads new customers from GET /api/customers?customer_type=NEW.
  Future<void> loadNewCustomers() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _newCustomers = await _service.getNewCustomers();
      _newCustomersCount = _newCustomers.length;
      _errorMessage = null;
    } on ForbiddenException {
      _errorMessage =
          'Access restricted: you do not have permission to view customers.';
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage =
          'An unexpected error occurred while loading new customers.';
    } finally {
      _setLoading(false);
    }
  }

  /// Loads all customers with optional filters using GET /api/customers.
  Future<void> loadFilteredCustomers({
    String? search,
    String? location,
    String? customerType,
    String? tier,
  }) async {
    _isFilterLoading = true;
    notifyListeners();
    _errorMessage = null;
    try {
      final result = await _service.getAllCustomers(
        search: search,
        location: location,
        customerType: customerType,
        tier: tier,
      );
      _filteredCustomers = result.customers;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred while searching customers.';
    } finally {
      _isFilterLoading = false;
      notifyListeners();
    }
  }

  /// Loads blocklisted customers from API or falls back to existing blocklisted records.
  Future<void> loadBlocklistedCustomers() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      try {
        final list = await _service.getBlocklistedCustomers();
        if (list.isNotEmpty) {
          _blocklistedCustomers = list;
        }
      } catch (_) {
        // If dedicated blocklisted endpoint returns 404 or 403, we rely on existing customers query
        await loadExistingCustomers();
      }
    } on ForbiddenException {
      _errorMessage = 'Access restricted: only Admin and Manager roles can access blacklisted records.';
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to load blacklisted customers.';
    } finally {
      _setLoading(false);
    }
  }

  /// Toggle or unblocklist customer.
  Future<void> unblockCustomer(int customerId) async {
    try {
      await _service.toggleBlocklist(customerId, isBlocklisted: false);
      _blocklistedCustomers.removeWhere((c) => c.customerId == customerId);
      // Refresh customer lists so customer reappears in categories
      await loadExistingCustomers();
      await loadNewCustomers();
      await loadBlocklistedCustomers();
      notifyListeners();
    } on ForbiddenException {
      _errorMessage = 'Permission denied: Admin or Manager authorization required to unblock.';
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to unblock customer.';
      notifyListeners();
    }
  }

  /// Blacklist a customer with an optional reason.
  Future<bool> blockCustomer(int customerId, {String? reason}) async {
    try {
      final updated = await _service.toggleBlocklist(
        customerId,
        isBlocklisted: true,
        blocklistReason: reason,
      );
      // Remove from existing/new lists
      for (final tier in _groupedExistingCustomers.keys) {
        _groupedExistingCustomers[tier]?.removeWhere(
          (c) => c.customerId == customerId,
        );
      }
      _newCustomers.removeWhere((c) => c.customerId == customerId);
      _blocklistedCustomers.removeWhere((c) => c.customerId == customerId);
      _blocklistedCustomers.insert(0, updated);

      await loadExistingCustomers();
      await loadNewCustomers();
      await loadBlocklistedCustomers();
      notifyListeners();
      return true;
    } on ForbiddenException {
      _errorMessage = 'Permission denied: Admin or Manager authorization required to blacklist.';
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to blacklist customer.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearFilteredCustomers() {
    _filteredCustomers = [];
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
