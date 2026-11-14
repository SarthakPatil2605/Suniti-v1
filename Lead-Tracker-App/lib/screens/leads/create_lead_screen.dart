// Create Lead Track Screen
// Faithfully matches ui-screen/8a15acaae9-1e29dff06806f443b295.png
// Supports both:
//   A. New Customer -> POST /api/customers/new
//   B. Existing Customer (Premium, Loyal, Interior) -> POST /api/opportunities
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
  // 1. Customer Segment: 0: Premium, 1: Loyal, 2: Interior, 3: New
  int _selectedSegment = 3; // Defaults to 'New' as shown in common flows

  // Form Controllers
  final _customerNameController = TextEditingController();
  final _projectTitleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  // Existing customer selection
  Customer? _selectedExistingCustomer;
  final _searchExistingController = TextEditingController();

  // Lead Temperature & Next Call Date
  String _selectedTemperature = 'WARM';
  DateTime? _scheduledCallDate;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadExistingCustomers();
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _projectTitleController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _searchExistingController.dispose();
    super.dispose();
  }

  bool get _isNewCustomer => _selectedSegment == 3;

  CustomerTier? get _segmentTier {
    switch (_selectedSegment) {
      case 0:
        return CustomerTier.PREMIUM;
      case 1:
        return CustomerTier.LOYAL;
      case 2:
        return CustomerTier.INTERIOR_DESIGNER;
      default:
        return null;
    }
  }

  Future<void> _submitLead() async {
    if (_isSubmitting) return;

    final projectTitle = _projectTitleController.text.trim();
    final address = _addressController.text.trim();
    final notes = _notesController.text.trim();

    if (_isNewCustomer) {
      final name = _customerNameController.text.trim();
      final phone = _phoneController.text.trim();

      if (name.isEmpty) {
        setState(() => _errorMessage = 'Customer company name is required.');
        return;
      }
      if (projectTitle.isEmpty) {
        setState(() => _errorMessage = 'Project title is required.');
        return;
      }
      if (address.isEmpty) {
        setState(() => _errorMessage = 'Location / plant address is required.');
        return;
      }

      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });

      try {
        final custProvider = context.read<CustomerProvider>();
        final ldProvider = context.read<LeadProvider>();
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);

        final service = CustomerService();
        await service.createCustomerWithOpportunity(
          name: name,
          projectTitle: projectTitle,
          locationName: address,
          phone: phone.isNotEmpty ? phone : null,
          billingAddress: address,
          leadTemperature: _selectedTemperature,
          conclusionNotes: notes.isNotEmpty ? notes : null,
          nextCallDate: _scheduledCallDate,
        );

        if (!mounted) return;
        // Refresh providers (both existing and new customers)
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
          _errorMessage = e.toString();
        });
      }
    } else {
      // Existing customer flow
      if (_selectedExistingCustomer == null) {
        setState(() => _errorMessage = 'Please select an existing customer.');
        return;
      }
      if (projectTitle.isEmpty) {
        setState(() => _errorMessage = 'Project title is required.');
        return;
      }
      if (address.isEmpty) {
        setState(() => _errorMessage = 'Project location is required.');
        return;
      }

      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });

      try {
        final ldProvider = context.read<LeadProvider>();
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);

        final oppService = OpportunityService();
        final newOpp = await oppService.createOpportunity(
          customerId: _selectedExistingCustomer!.customerId,
          projectTitle: projectTitle,
          locationName: address,
          leadTemperature: _selectedTemperature,
          dealStatus: 'PIPELINE',
        );

        // Add follow-up note if provided
        if (notes.isNotEmpty || _scheduledCallDate != null) {
          await oppService.addOpportunityNote(
            newOpp.opportunityId,
            conclusionNotes: notes.isNotEmpty
                ? notes
                : 'Initial project intake.',
            nextCallDate: _scheduledCallDate,
            leadTemperature: _selectedTemperature,
          );
        }

        if (!mounted) return;
        await ldProvider.loadOngoingLeads();

        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Lead opportunity attached to customer successfully!',
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
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.watch<CustomerProvider>();
    final tier = _segmentTier;
    final availableCustomers = tier != null
        ? customerProvider.customersForTier(tier)
        : customerProvider.allExistingCustomers;

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
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Drafts',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. CUSTOMER SEGMENT
            _buildSectionLabel('1. CUSTOMER SEGMENT'),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildSegmentButton('Premium', 0),
                const SizedBox(width: 8),
                _buildSegmentButton('Loyal', 1),
                const SizedBox(width: 8),
                _buildSegmentButton('Interior', 2),
                const SizedBox(width: 8),
                _buildSegmentButton('New', 3),
              ],
            ),
            const SizedBox(height: 22),

            // 2. SELECT CUSTOMER (or Customer Name)
            _buildSectionLabel('2. SELECT CUSTOMER'),
            const SizedBox(height: 10),
            if (_isNewCustomer) ...[
              TextField(
                controller: _customerNameController,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Enter new customer company name...',
                  prefixIcon: Icon(
                    Icons.business_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ] else ...[
              DropdownButtonFormField<Customer>(
                initialValue: _selectedExistingCustomer,
                dropdownColor: AppColors.surface,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search or select existing customer...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
                items: availableCustomers.map((cust) {
                  return DropdownMenuItem<Customer>(
                    value: cust,
                    child: Text(
                      cust.name,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedExistingCustomer = val;
                    if (val != null) {
                      _phoneController.text = val.phone ?? '';
                      _addressController.text = val.billingAddress ?? '';
                    }
                  });
                },
              ),
            ],
            const SizedBox(height: 22),

            // 3. PROJECT TITLE & LOCATION
            _buildSectionLabel('3. PROJECT TITLE & LOCATION'),
            const SizedBox(height: 10),
            TextField(
              controller: _projectTitleController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Project title (e.g. Pune Plant Expansion)',
                prefixIcon: Icon(
                  Icons.apartment_rounded,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: '+91 Contact Number',
                prefixIcon: Icon(
                  Icons.phone_rounded,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              maxLines: 2,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Site / Billing Address (e.g. Pune, Pimpri)',
                prefixIcon: Icon(
                  Icons.location_on_rounded,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 22),

            // 4. CALL NOTES
            _buildSectionLabel('4. CALL NOTES FOR NEXT TEAMMATE'),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 4,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Describe the inquiry details, budget, and specific requirements...',
              ),
            ),
            const SizedBox(height: 22),

            // 5. SCHEDULE NEXT CALL & PRIORITY
            _buildSectionLabel('5. SCHEDULE NEXT CALL & PRIORITY'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(
                      _scheduledCallDate == null
                          ? 'Select Date'
                          : DateFormat('dd MMM yyyy')
                                .format(_scheduledCallDate!),
                      style: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 7),
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
              const SizedBox(height: 16),
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

            // Submit Button matching red CTA in 8a15acaae9
            SizedBox(
              width: double.infinity,
              height: 54,
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
                        children: const [
                          Text(
                            'Save & Assign Lead',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
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

  Widget _buildSegmentButton(String label, int index) {
    final isSelected = _selectedSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSegment = index;
            _selectedExistingCustomer = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceSubtle,
            borderRadius: AppRadius.radiusPill,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
