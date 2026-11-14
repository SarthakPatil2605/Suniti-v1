// Create Lead Track Screen
// Supports:
//   A. Existing Customer Selection via debounced search autocomplete
//      -> POST /api/opportunities (links to existing customer_id, no customer duplicate)
//   B. Add New Customer (when no match or chosen)
//      -> POST /api/customers/new (creates new customer + opportunity + task atomically)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_theme.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../providers/lead_provider.dart';
import '../../core/api/customer_service.dart';
import '../../core/api/opportunity_service.dart';

class CreateLeadScreen extends StatefulWidget {
  const CreateLeadScreen({super.key});

  @override
  State<CreateLeadScreen> createState() => _CreateLeadScreenState();
}

class _CreateLeadScreenState extends State<CreateLeadScreen> {
  // Mode: true = Add New Customer, false = Select Existing Customer
  bool _isNewCustomerMode = false;

  // Search autocomplete state for existing customers
  final TextEditingController _customerSearchController =
      TextEditingController();
  Timer? _searchDebounce;
  bool _isSearchingCustomers = false;
  List<Customer> _customerSearchResults = [];
  bool _hasSearched = false;
  Customer? _selectedCustomer;

  // New Customer form controllers
  final _newCustomerNameController = TextEditingController();
  final _newCustomerPhoneController = TextEditingController();
  final _newCustomerAddressController = TextEditingController();
  CustomerTier? _newCustomerTier;

  // Common Opportunity fields
  final _projectTitleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedTemperature = 'WARM';
  DateTime? _scheduledCallDate;

  bool _isSubmitting = false;
  String? _errorMessage;

  final CustomerService _customerService = CustomerService();
  final OpportunityService _opportunityService = OpportunityService();

  @override
  void initState() {
    super.initState();
    _customerSearchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _customerSearchController.dispose();
    _newCustomerNameController.dispose();
    _newCustomerPhoneController.dispose();
    _newCustomerAddressController.dispose();
    _projectTitleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _customerSearchController.text.trim();
    if (_selectedCustomer != null && _selectedCustomer!.name != query) {
      // User typed after selection -> clear selected customer
      setState(() {
        _selectedCustomer = null;
      });
    }

    _searchDebounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _customerSearchResults = [];
        _isSearchingCustomers = false;
        _hasSearched = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performCustomerSearch(query);
    });
  }

  Future<void> _performCustomerSearch(String query) async {
    setState(() {
      _isSearchingCustomers = true;
      _hasSearched = true;
    });

    try {
      final result = await _customerService.getAllCustomers(search: query);
      if (mounted) {
        setState(() {
          _customerSearchResults = result.customers;
          _isSearchingCustomers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearchingCustomers = false;
        });
      }
    }
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _customerSearchController.text = customer.name;
      _customerSearchResults = [];
      _isNewCustomerMode = false;
      _errorMessage = null;

      // Autofill location from customer if location field is currently empty
      if (_locationController.text.trim().isEmpty &&
          customer.billingAddress != null &&
          customer.billingAddress!.isNotEmpty) {
        _locationController.text = customer.billingAddress!;
      }
    });
    FocusScope.of(context).unfocus();
  }

  void _clearSelectedCustomer() {
    setState(() {
      _selectedCustomer = null;
      _customerSearchController.clear();
      _customerSearchResults = [];
      _hasSearched = false;
    });
  }

  void _switchToNewCustomerMode([String? initialName]) {
    setState(() {
      _isNewCustomerMode = true;
      _selectedCustomer = null;
      _customerSearchResults = [];
      _hasSearched = false;
      if (initialName != null && initialName.trim().isNotEmpty) {
        _newCustomerNameController.text = initialName.trim();
      }
      _errorMessage = null;
    });
  }

  void _switchToExistingCustomerMode() {
    setState(() {
      _isNewCustomerMode = false;
      _errorMessage = null;
    });
  }

  Future<void> _submitLead() async {
    if (_isSubmitting) return;

    final projectTitle = _projectTitleController.text.trim();
    final location = _locationController.text.trim();
    final notes = _notesController.text.trim();

    if (projectTitle.isEmpty) {
      setState(() => _errorMessage = 'Project title is required.');
      return;
    }

    if (location.isEmpty) {
      setState(
        () => _errorMessage = 'Project location / site address is required.',
      );
      return;
    }

    if (_isNewCustomerMode) {
      // Path A: Genuinely New Customer
      final name = _newCustomerNameController.text.trim();
      final phone = _newCustomerPhoneController.text.trim();
      final address = _newCustomerAddressController.text.trim();

      if (name.isEmpty) {
        setState(() => _errorMessage = 'Customer company name is required.');
        return;
      }

      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });

      try {
        final custProvider = context.read<CustomerProvider>();
        final ldProvider = context.read<LeadProvider>();
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);

        await _customerService.createCustomerWithOpportunity(
          name: name,
          projectTitle: projectTitle,
          locationName: location,
          phone: phone.isNotEmpty ? phone : null,
          billingAddress: address.isNotEmpty ? address : location,
          tier: _newCustomerTier?.name,
          leadTemperature: _selectedTemperature,
          conclusionNotes: notes.isNotEmpty ? notes : null,
          nextCallDate: _scheduledCallDate,
        );

        if (!mounted) return;
        await custProvider.loadExistingCustomers();
        await custProvider.loadNewCustomers();
        await ldProvider.loadOngoingLeads();

        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'New customer and lead opportunity created successfully!',
            ),
            backgroundColor: AppColors.callGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        navigator.pop();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } else {
      // Path B: Existing Customer Selected
      if (_selectedCustomer == null) {
        setState(
          () => _errorMessage = 'Please search and select an existing customer, or click "+ Add New Customer".',
        );
        return;
      }

      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });

      try {
        final ldProvider = context.read<LeadProvider>();
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);

        await _opportunityService.createOpportunity(
          customerId: _selectedCustomer!.customerId,
          projectTitle: projectTitle,
          locationName: location,
          leadTemperature: _selectedTemperature,
          dealStatus: 'PIPELINE',
          conclusionNotes: notes.isNotEmpty ? notes : null,
          nextCallDate: _scheduledCallDate,
        );

        if (!mounted) return;
        await ldProvider.loadOngoingLeads();

        messenger.showSnackBar(
          SnackBar(
            content: Text('New lead created for "${_selectedCustomer!.name}"!'),
            backgroundColor: AppColors.callGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        navigator.pop();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Create Lead Track',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Selector Tabs (Existing vs New Customer)
            _buildModeToggle(),
            const SizedBox(height: 20),

            // 1. CUSTOMER SELECTION OR NEW CUSTOMER INPUT
            if (!_isNewCustomerMode) ...[
              _buildSectionLabel('1. SELECT EXISTING CUSTOMER'),
              const SizedBox(height: 8),
              if (_selectedCustomer != null)
                _buildSelectedCustomerCard()
              else
                _buildCustomerSearchField(),
              if (_selectedCustomer == null &&
                  (_isSearchingCustomers ||
                      _customerSearchResults.isNotEmpty ||
                      _hasSearched))
                _buildCustomerSearchResultsList(),
            ] else ...[
              _buildSectionLabel('1. NEW CUSTOMER DETAILS'),
              const SizedBox(height: 10),
              _buildNewCustomerForm(),
            ],

            const SizedBox(height: 24),

            // 2. PROJECT TITLE & LOCATION (Common)
            _buildSectionLabel('2. PROJECT TITLE & SITE LOCATION'),
            const SizedBox(height: 10),
            TextField(
              controller: _projectTitleController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Project title (e.g. Pune Plant Expansion Phase 2)',
                prefixIcon: Icon(
                  Icons.apartment_rounded,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Site Location / Work Address',
                prefixIcon: Icon(
                  Icons.location_on_rounded,
                  color: AppColors.textMuted,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 3. CALL NOTES FOR NEXT TEAMMATE
            _buildSectionLabel('3. INITIAL CALL NOTES / INSTRUCTIONS'),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Describe client requirements, materials needed, budget, or architectural details...',
              ),
            ),

            const SizedBox(height: 24),

            // 4. SCHEDULE NEXT CALL & PRIORITY
            _buildSectionLabel('4. SCHEDULE NEXT FOLLOW-UP & PRIORITY'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusMd,
                      ),
                    ),
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(
                      _scheduledCallDate == null
                          ? 'Follow-up Date'
                          : DateFormat('dd MMM yyyy')
                                .format(_scheduledCallDate!),
                      style: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 3),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _scheduledCallDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedTemperature,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'HOT',
                        child: Text('🔥 Hot Priority'),
                      ),
                      DropdownMenuItem(
                        value: 'WARM',
                        child: Text('⚡ Warm Lead'),
                      ),
                      DropdownMenuItem(
                        value: 'COLD',
                        child: Text('❄ Cold Lead'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedTemperature = val);
                      }
                    },
                  ),
                ),
              ],
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusLg,
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitLead,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isNewCustomerMode
                                ? 'Create Customer & Lead'
                                : 'Save & Link Opportunity',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.radiusPill,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _switchToExistingCustomerMode,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isNewCustomerMode
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: AppRadius.radiusPill,
                ),
                child: Center(
                  child: Text(
                    'Select Existing Customer',
                    style: TextStyle(
                      color: !_isNewCustomerMode
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: !_isNewCustomerMode
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _switchToNewCustomerMode(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isNewCustomerMode
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: AppRadius.radiusPill,
                ),
                child: Center(
                  child: Text(
                    '+ Add New Customer',
                    style: TextStyle(
                      color: _isNewCustomerMode
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: _isNewCustomerMode
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSearchField() {
    return TextField(
      controller: _customerSearchController,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Type customer name or phone to search...',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textMuted,
        ),
        suffixIcon: _customerSearchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _customerSearchController.clear();
                },
              )
            : null,
      ),
    );
  }

  Widget _buildCustomerSearchResultsList() {
    if (_isSearchingCustomers) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (_customerSearchResults.isEmpty && _hasSearched) {
      final currentQuery = _customerSearchController.text.trim();
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.person_search_rounded,
              color: AppColors.textMuted,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No customer found matching "$currentQuery"',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.callGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: Text('Create "$currentQuery" as New Customer'),
              onPressed: () => _switchToNewCustomerMode(currentQuery),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _customerSearchResults.length + 1, // +1 for "Add New" option
        separatorBuilder: (_, _) =>
            const Divider(color: AppColors.border, height: 1),
        itemBuilder: (context, index) {
          if (index == _customerSearchResults.length) {
            return ListTile(
              dense: true,
              leading: const CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.callGreen,
                child: Icon(Icons.add, size: 16, color: Colors.white),
              ),
              title: const Text(
                '+ Add as New Customer',
                style: TextStyle(
                  color: AppColors.callGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              onTap: () => _switchToNewCustomerMode(
                _customerSearchController.text.trim(),
              ),
            );
          }

          final customer = _customerSearchResults[index];
          final badgeColor = customer.isNew
              ? AppColors.typeNew
              : customer.tier == CustomerTier.PREMIUM
              ? AppColors.tierPremium
              : customer.tier == CustomerTier.LOYAL
              ? AppColors.tierLoyal
              : AppColors.tierInterior;

          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: badgeColor.withValues(alpha: 0.18),
              child: Text(
                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    customer.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: AppRadius.radiusSm,
                  ),
                  child: Text(
                    customer.categoryDisplayTitle.toUpperCase(),
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_rounded,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        customer.phone!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                if (customer.billingAddress != null &&
                    customer.billingAddress!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          customer.billingAddress!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            onTap: () => _selectCustomer(customer),
          );
        },
      ),
    );
  }

  Widget _buildSelectedCustomerCard() {
    final customer = _selectedCustomer!;
    final badgeColor = customer.isNew
        ? AppColors.typeNew
        : customer.tier == CustomerTier.PREMIUM
        ? AppColors.tierPremium
        : customer.tier == CustomerTier.LOYAL
        ? AppColors.tierLoyal
        : AppColors.tierInterior;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.callGreen, width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: badgeColor.withValues(alpha: 0.18),
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customer.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: AppRadius.radiusSm,
                      ),
                      child: Text(
                        customer.categoryDisplayTitle.toUpperCase(),
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Phone: ${customer.phone}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (customer.billingAddress != null &&
                    customer.billingAddress!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Address: ${customer.billingAddress}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.change_circle_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            tooltip: 'Change Selected Customer',
            onPressed: _clearSelectedCustomer,
          ),
        ],
      ),
    );
  }

  Widget _buildNewCustomerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _newCustomerNameController,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Customer / Company Name *',
            prefixIcon: Icon(
              Icons.business_rounded,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newCustomerPhoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: const InputDecoration(
            hintText: '+91 Phone Number',
            prefixIcon: Icon(Icons.phone_rounded, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newCustomerAddressController,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Customer Billing / Registered Address',
            prefixIcon: Icon(
              Icons.location_city_rounded,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CustomerTier>(
          initialValue: _newCustomerTier,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Customer Tier (Optional, default NEW)',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          items: const [
            DropdownMenuItem(
              value: null,
              child: Text('New Customer (Standard)'),
            ),
            DropdownMenuItem(
              value: CustomerTier.PREMIUM,
              child: Text('Premium Customer'),
            ),
            DropdownMenuItem(
              value: CustomerTier.LOYAL,
              child: Text('Loyal Customer'),
            ),
            DropdownMenuItem(
              value: CustomerTier.INTERIOR_DESIGNER,
              child: Text('Interior Designer'),
            ),
          ],
          onChanged: (tier) {
            setState(() => _newCustomerTier = tier);
          },
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}
