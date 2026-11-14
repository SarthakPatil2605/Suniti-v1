// Customer Category Screen
// Shows customers for a selected CustomerTier OR New Customers with:
//   - Avatar initials (gold circle matching tier color)
//   - Customer name
//   - Joined date (created_at) in "DD MMM YYYY" format
//   - Tier/type badge
//   - Call button (green phone icon)
//   - Search + text filter
//   - Advanced filter bottom sheet with name, location, and category filters
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_theme.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import 'customer_detail_screen.dart';

class CustomerCategoryScreen extends StatefulWidget {
  final CustomerTier? tier;
  final bool isNewCategory;
  final String label;
  final Color color;
  final IconData icon;

  const CustomerCategoryScreen({
    super.key,
    required this.tier,
    required this.isNewCategory,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  State<CustomerCategoryScreen> createState() => _CustomerCategoryScreenState();
}

class _CustomerCategoryScreenState extends State<CustomerCategoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Active filter state
  String _filterName = '';
  String _filterLocation = '';
  String? _filterCustomerType;
  String? _filterTier;
  int _activeFilterCount = 0;
  bool _isServerFiltering = false;
  List<Customer>? _serverFilteredResults;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Load new customers if this is the New category
    if (widget.isNewCategory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CustomerProvider>().loadNewCustomers();
      });
    }
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  List<Customer> _getSourceCustomers(CustomerProvider provider) {
    if (_serverFilteredResults != null) {
      return _serverFilteredResults!;
    }
    if (widget.isNewCategory) {
      return provider.newCustomers;
    }
    if (widget.tier != null) {
      return provider.customersForTier(widget.tier!);
    }
    return [];
  }

  List<Customer> _filtered(List<Customer> all) {
    if (_searchQuery.isEmpty) return all;
    return all
        .where((c) => c.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  void _updateActiveFilterCount() {
    int count = 0;
    if (_filterName.isNotEmpty) count++;
    if (_filterLocation.isNotEmpty) count++;
    if (_filterCustomerType != null) count++;
    if (_filterTier != null) count++;
    _activeFilterCount = count;
  }

  Future<void> _applyServerFilters() async {
    _updateActiveFilterCount();

    if (_activeFilterCount == 0) {
      setState(() {
        _serverFilteredResults = null;
        _isServerFiltering = false;
      });
      return;
    }

    setState(() => _isServerFiltering = true);

    final provider = context.read<CustomerProvider>();
    await provider.loadFilteredCustomers(
      search: _filterName.isNotEmpty ? _filterName : null,
      location: _filterLocation.isNotEmpty ? _filterLocation : null,
      customerType:
          _filterCustomerType ?? (widget.isNewCategory ? 'NEW' : null),
      tier: _filterTier ?? widget.tier?.name,
    );

    if (mounted) {
      setState(() {
        _serverFilteredResults = provider.filteredCustomers;
        _isServerFiltering = false;
      });
    }
  }

  void _clearAllFilters() {
    setState(() {
      _filterName = '';
      _filterLocation = '';
      _filterCustomerType = null;
      _filterTier = null;
      _activeFilterCount = 0;
      _serverFilteredResults = null;
      _isServerFiltering = false;
    });
  }

  void _showFilterSheet() {
    final nameController = TextEditingController(text: _filterName);
    final locationController = TextEditingController(text: _filterLocation);
    String? tempCustomerType = _filterCustomerType;
    String? tempTier = _filterTier;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Customers',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Name filter
                  const Text(
                    'Customer Name',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FilterTextField(
                    controller: nameController,
                    hint: 'Search by name...',
                    icon: Icons.person_search_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Location filter
                  const Text(
                    'Location',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FilterTextField(
                    controller: locationController,
                    hint: 'Search by location...',
                    icon: Icons.location_on_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Category / Type filter
                  const Text(
                    'Customer Category',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: 'New',
                        isSelected: tempCustomerType == 'NEW',
                        color: AppColors.typeNew,
                        onTap: () {
                          setSheetState(() {
                            tempCustomerType = tempCustomerType == 'NEW'
                                ? null
                                : 'NEW';
                            if (tempCustomerType == 'NEW') tempTier = null;
                          });
                        },
                      ),
                      _FilterChip(
                        label: 'Premium',
                        isSelected: tempTier == 'PREMIUM',
                        color: AppColors.tierPremium,
                        onTap: () {
                          setSheetState(() {
                            tempTier = tempTier == 'PREMIUM' ? null : 'PREMIUM';
                            if (tempTier != null) tempCustomerType = null;
                          });
                        },
                      ),
                      _FilterChip(
                        label: 'Loyal',
                        isSelected: tempTier == 'LOYAL',
                        color: AppColors.tierLoyal,
                        onTap: () {
                          setSheetState(() {
                            tempTier = tempTier == 'LOYAL' ? null : 'LOYAL';
                            if (tempTier != null) tempCustomerType = null;
                          });
                        },
                      ),
                      _FilterChip(
                        label: 'Interior Designer',
                        isSelected: tempTier == 'INTERIOR_DESIGNER',
                        color: AppColors.tierInterior,
                        onTap: () {
                          setSheetState(() {
                            tempTier = tempTier == 'INTERIOR_DESIGNER'
                                ? null
                                : 'INTERIOR_DESIGNER';
                            if (tempTier != null) tempCustomerType = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.radiusMd,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _clearAllFilters();
                          },
                          child: const Text('Clear All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.radiusMd,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _filterName = nameController.text.trim();
                              _filterLocation = locationController.text.trim();
                              _filterCustomerType = tempCustomerType;
                              _filterTier = tempTier;
                            });
                            _applyServerFilters();
                          },
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final sourceCustomers = _getSourceCustomers(provider);
    final displayed = _filtered(sourceCustomers);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _activeFilterCount > 0
                  ? '$_activeFilterCount FILTER${_activeFilterCount > 1 ? 'S' : ''} ACTIVE'
                  : 'CATEGORY FILTER ACTIVE',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.radiusMd,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: _showFilterSheet,
                  ),
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$_activeFilterCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: provider.isLoading || _isServerFiltering
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: _buildSearchBar(),
                ),
                // Active filter chips
                if (_activeFilterCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _buildActiveFilterChips(),
                  ),
                // Customer list
                Expanded(
                  child: displayed.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: displayed.length,
                          separatorBuilder: (context, i) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _CustomerCard(
                            customer: displayed[index],
                            tier: widget.tier,
                            isNewCategory: widget.isNewCategory,
                            tierColor: widget.color,
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildActiveFilterChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (_filterName.isNotEmpty)
          _ActiveFilterTag(
            label: 'Name: $_filterName',
            onRemove: () {
              setState(() => _filterName = '');
              _applyServerFilters();
            },
          ),
        if (_filterLocation.isNotEmpty)
          _ActiveFilterTag(
            label: 'Location: $_filterLocation',
            onRemove: () {
              setState(() => _filterLocation = '');
              _applyServerFilters();
            },
          ),
        if (_filterCustomerType != null)
          _ActiveFilterTag(
            label: 'Type: $_filterCustomerType',
            onRemove: () {
              setState(() => _filterCustomerType = null);
              _applyServerFilters();
            },
          ),
        if (_filterTier != null)
          _ActiveFilterTag(
            label: 'Tier: $_filterTier',
            onRemove: () {
              setState(() => _filterTier = null);
              _applyServerFilters();
            },
          ),
        GestureDetector(
          onTap: _clearAllFilters,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Clear all',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.radiusPill,
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Search in category...',
          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No customers match "$_searchQuery".'
                : _activeFilterCount > 0
                ? 'No customers match the active filters.'
                : 'No ${widget.label} customers found.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          if (_activeFilterCount > 0) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Clear Filters'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Customer card
// ---------------------------------------------------------------------------

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final CustomerTier? tier;
  final bool isNewCategory;
  final Color tierColor;

  const _CustomerCard({
    required this.customer,
    required this.tier,
    required this.isNewCategory,
    required this.tierColor,
  });

  /// Extracts initials from the customer's name (up to 2 chars).
  String get _initials {
    final parts = customer.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String get _badgeLabel {
    if (isNewCategory || customer.isNew) return 'New Customer';
    final t = customer.tier ?? tier;
    if (t == null) return 'Existing';
    return t.name
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) => w.isNotEmpty ? '${w[0]}${w.substring(1).toLowerCase()}' : '',
        )
        .join(' ');
  }

  String get _joinedDate {
    if (customer.createdAt == null) return '';
    return DateFormat('dd MMM yyyy').format(customer.createdAt!);
  }

  Future<void> _callCustomer(BuildContext context) async {
    final phone = customer.phone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number on record for this customer.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot dial $phone on this device.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomerDetailScreen(
              customerId: customer.customerId,
              initialCustomer: customer,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar initials circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: tierColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: TextStyle(
                    color: tierColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Name + date + tier badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (_joinedDate.isNotEmpty) ...[
                        Text(
                          _joinedDate,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _TierBadge(label: _badgeLabel, color: tierColor),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Call button
            GestureDetector(
              onTap: () => _callCustomer(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.callGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TierBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.radiusSm,
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ActiveFilterTag extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterTag({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;

  const _FilterTextField({
    required this.controller,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : AppColors.surfaceSubtle,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
