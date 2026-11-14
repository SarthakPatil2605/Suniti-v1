// Customer List Screen
// Matches ui-screen/491acbcb26-718a48a6d30c15ab4a22.png
// Four category tiles: Premium, Loyal, Interior Designers, New Customers
// Global statistics bar at bottom.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import 'customer_category_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load data on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CustomerProvider>();
      provider.loadExistingCustomers();
      provider.loadNewCustomers();
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // Do NOT show a back button when inside the bottom nav shell
        automaticallyImplyLeading: false,
        title: const Text(
          'Customers',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceElevated,
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await provider.loadExistingCustomers();
          await provider.loadNewCustomers();
        },
        child: provider.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : provider.errorMessage != null
            ? _buildErrorState(provider)
            : _buildContent(provider),
      ),
    );
  }

  Widget _buildContent(CustomerProvider provider) {
    final premiumCount = provider.countForTier(CustomerTier.PREMIUM);
    final loyalCount = provider.countForTier(CustomerTier.LOYAL);
    final interiorCount = provider.countForTier(CustomerTier.INTERIOR_DESIGNER);
    final newCount = provider.newCustomersCount;
    final totalExisting = provider.totalExistingCustomers;

    // Filter categories by search query (category name match)
    final categories = _buildCategories(
      premiumCount: premiumCount,
      loyalCount: loyalCount,
      interiorCount: interiorCount,
      newCount: newCount,
    );

    final filtered = _searchQuery.isEmpty
        ? categories
        : categories
              .where((c) => c.label.toLowerCase().contains(_searchQuery))
              .toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverToBoxAdapter(child: _buildSearchBar()),
        ),
        const SliverPadding(padding: EdgeInsets.only(top: 16)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final cat = filtered[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CategoryTile(
                  icon: cat.icon,
                  iconColor: cat.color,
                  label: cat.label,
                  count: cat.count,
                  onTap: () => _openCategory(context, cat),
                ),
              );
            }, childCount: filtered.length),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverToBoxAdapter(
            child: _buildGlobalStats(totalExisting + newCount),
          ),
        ),
      ],
    );
  }

  List<_CategoryData> _buildCategories({
    required int premiumCount,
    required int loyalCount,
    required int interiorCount,
    required int newCount,
  }) {
    return [
      _CategoryData(
        tier: CustomerTier.PREMIUM,
        isNewCategory: false,
        label: 'Premium',
        icon: Icons.workspace_premium_rounded,
        color: AppColors.tierPremium,
        count: premiumCount,
      ),
      _CategoryData(
        tier: CustomerTier.LOYAL,
        isNewCategory: false,
        label: 'Loyal',
        icon: Icons.favorite_rounded,
        color: AppColors.tierLoyal,
        count: loyalCount,
      ),
      _CategoryData(
        tier: CustomerTier.INTERIOR_DESIGNER,
        isNewCategory: false,
        label: 'Interior Designers',
        icon: Icons.design_services_rounded,
        color: AppColors.tierInterior,
        count: interiorCount,
      ),
      _CategoryData(
        tier: null,
        isNewCategory: true,
        label: 'New Customers',
        icon: Icons.person_add_rounded,
        color: AppColors.typeNew,
        count: newCount,
      ),
    ];
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
          hintText: 'Search customers...',
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

  Widget _buildGlobalStats(int totalCustomers) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GLOBAL STATISTICS',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      totalCustomers.toString(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Total Customers',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 48, color: AppColors.border),
              const SizedBox(width: 24),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '—',
                      style: TextStyle(
                        color: AppColors.callGreen,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Active Pipeline',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(CustomerProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage ?? 'Failed to load customers.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                provider.loadExistingCustomers();
                provider.loadNewCustomers();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _openCategory(BuildContext context, _CategoryData cat) {
    if (cat.isNewCategory) {
      // Navigate to New Customers screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerCategoryScreen(
            tier: null,
            isNewCategory: true,
            label: cat.label,
            color: cat.color,
            icon: cat.icon,
          ),
        ),
      );
    } else if (cat.tier != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerCategoryScreen(
            tier: cat.tier!,
            isNewCategory: false,
            label: cat.label,
            color: cat.color,
            icon: cat.icon,
          ),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _CategoryData {
  final CustomerTier? tier;
  final bool isNewCategory;
  final String label;
  final IconData icon;
  final Color color;
  final int count;

  const _CategoryData({
    required this.tier,
    required this.isNewCategory,
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
  });
}

class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int count;
  final VoidCallback? onTap;

  const _CategoryTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final countLabel = '$count Active Leads';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusXl,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: AppRadius.radiusLg,
              ),
              child: Center(child: Icon(icon, color: iconColor, size: 26)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    countLabel,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
