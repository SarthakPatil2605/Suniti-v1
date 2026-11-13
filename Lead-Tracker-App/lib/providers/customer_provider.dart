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

  List<Customer> _blocklistedCustomers = [];

  int _existingTotal = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // --- Getters ---
  Map<CustomerTier, List<Customer>> get groupedExistingCustomers =>
      _groupedExistingCustomers;
  Map<CustomerTier, int> get tierCounts => _tierCounts;
  List<Customer> get blocklistedCustomers => _blocklistedCustomers;
  int get existingTotal => _existingTotal;
  bool get isLoading => _isLoading;
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
  Future<void> loadExistingCustomers() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final result = await _service.getExistingCustomers();
      _groupedExistingCustomers = result.grouped;
      _tierCounts = result.counts;
      _existingTotal = result.total;

      // Also refresh blocklisted list if any existing customer is marked is_blocklisted
      final blocklistedFromExisting = <Customer>[];
      for (final list in _groupedExistingCustomers.values) {
        for (final c in list) {
          if (c.isBlocklisted) {
            blocklistedFromExisting.add(c);
          }
        }
      }
      _blocklistedCustomers = blocklistedFromExisting;
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
      notifyListeners();
    } on ForbiddenException {
      _errorMessage =
          'Permission denied: Admin authorization required to unblock.';
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to unblock customer.';
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
