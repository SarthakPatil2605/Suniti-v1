// Blacklisted Customers Screen
// Faithfully matches ui-screen/de502b6714-3f7530a494d9d314bdde.png
// Restricted Access banner, Search, Customer cards with initials & unblock options
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../models/customer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../customers/customer_detail_screen.dart';

class BlacklistedCustomersScreen extends StatefulWidget {
  const BlacklistedCustomersScreen({super.key});

  @override
  State<BlacklistedCustomersScreen> createState() =>
      _BlacklistedCustomersScreenState();
}

class _BlacklistedCustomersScreenState
    extends State<BlacklistedCustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadBlocklistedCustomers();
    });
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmUnblock(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusLg,
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Remove from Blocklist',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to restore "${customer.name}" and allow new leads to be created?',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await context.read<CustomerProvider>().unblockCustomer(
                customer.customerId,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Customer "${customer.name}" unblocked successfully.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final customerProvider = context.watch<CustomerProvider>();
    final isAdmin = authProvider.currentEmployee?.isAdmin ?? false;

    final allBlocklisted = customerProvider.blocklistedCustomers;
    final filtered = _searchQuery.isEmpty
        ? allBlocklisted
        : allBlocklisted
              .where((c) => c.name.toLowerCase().contains(_searchQuery))
              .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Blacklisted',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.person_off_rounded, size: 20),
              color: AppColors.danger,
              onPressed: () => customerProvider.loadBlocklistedCustomers(),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => customerProvider.loadBlocklistedCustomers(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Restricted Access Warning Banner (Matching de502b6714)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius: AppRadius.radiusLg,
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.2),
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.danger,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Restricted Access',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Blacklisted customers will not appear in the lead generation flow and are flagged across all team accounts.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search Input
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: AppRadius.radiusPill,
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search blacklisted...',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
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
              ),
              const SizedBox(height: 16),

              // Content / List
              if (customerProvider.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (customerProvider.errorMessage != null)
                _buildErrorView(customerProvider)
              else if (filtered.isEmpty)
                _buildEmptyView()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final customer = filtered[index];
                    return _buildCustomerItem(customer, isAdmin);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerItem(Customer customer, bool isAdmin) {
    final initials = customer.name.isNotEmpty
        ? customer.name
              .trim()
              .split(' ')
              .take(2)
              .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
              .join()
        : 'BL';

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
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
                      const SizedBox(height: 3),
                      const Text(
                        'RESTRICTED ACCOUNT',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    color: AppColors.surfaceElevated,
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusMd,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    onSelected: (val) {
                      if (val == 'unblock') {
                        _confirmUnblock(context, customer);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'unblock',
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_open_rounded,
                              color: AppColors.callGreen,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Unblock Customer',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
            if (customer.blocklistReason != null &&
                customer.blocklistReason!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.danger,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reason: ${customer.blocklistReason!}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (customer.phone != null && customer.phone!.isNotEmpty) ...[
              const SizedBox(height: 8),
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: const [
            Icon(Icons.shield_rounded, size: 48, color: AppColors.callGreen),
            SizedBox(height: 12),
            Text(
              'No Blacklisted Customers',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'All customer records are currently active and in good standing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(CustomerProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.lock_person_rounded,
              size: 48,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage ?? 'Access restriction encountered.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.loadBlocklistedCustomers(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
