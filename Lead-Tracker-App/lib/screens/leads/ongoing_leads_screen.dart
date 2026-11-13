// Ongoing Leads Pipeline Screen
// Faithfully matching ui-screen/531f99621d-5df2d09f260649eae1b3.png
// Tabs: All, High Priority, Scheduled Today
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_theme.dart';
import '../../models/opportunity.dart';
import '../../models/customer.dart';
import '../../providers/lead_provider.dart';

class OngoingLeadsScreen extends StatefulWidget {
  const OngoingLeadsScreen({super.key});

  @override
  State<OngoingLeadsScreen> createState() => _OngoingLeadsScreenState();
}

class _OngoingLeadsScreenState extends State<OngoingLeadsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeadProvider>().loadOngoingLeads();
    });
    _searchController.addListener(() {
      context.read<LeadProvider>().setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No contact number available for this lead.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot dial $phone.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showLeadDetail(Opportunity opp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => _LeadDetailSheet(opportunity: opp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadProvider = context.watch<LeadProvider>();
    final leads = leadProvider.filteredOpportunities;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Ongoing Leads',
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
              icon: const Icon(Icons.history_rounded, size: 20),
              color: AppColors.textSecondary,
              onPressed: () => leadProvider.loadOngoingLeads(),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => leadProvider.loadOngoingLeads(),
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
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
                    hintText: 'Filter by customer name...',
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
            ),

            // Tab bar (All, High Priority, Scheduled Today)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildTab(
                    label: 'All',
                    tab: OngoingLeadTab.all,
                    currentTab: leadProvider.selectedTab,
                    onTap: () =>
                        leadProvider.setSelectedTab(OngoingLeadTab.all),
                  ),
                  const SizedBox(width: 18),
                  _buildTab(
                    label: 'High Priority',
                    tab: OngoingLeadTab.highPriority,
                    currentTab: leadProvider.selectedTab,
                    onTap: () => leadProvider.setSelectedTab(
                      OngoingLeadTab.highPriority,
                    ),
                  ),
                  const SizedBox(width: 18),
                  _buildTab(
                    label: 'Scheduled Today',
                    tab: OngoingLeadTab.scheduledToday,
                    currentTab: leadProvider.selectedTab,
                    onTap: () => leadProvider.setSelectedTab(
                      OngoingLeadTab.scheduledToday,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 16, thickness: 1),

            // Lead Cards List
            Expanded(
              child: leadProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : leadProvider.errorMessage != null
                  ? _buildErrorView(leadProvider)
                  : leads.isEmpty
                  ? _buildEmptyView()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: leads.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final opp = leads[index];
                        return _buildLeadCard(opp);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required OngoingLeadTab tab,
    required OngoingLeadTab currentTab,
    required VoidCallback onTap,
  }) {
    final isSelected = tab == currentTab;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: 24,
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildLeadCard(Opportunity opp) {
    final customerName = opp.customer?.name ?? 'Customer #${opp.customerId}';
    final tier = opp.customer?.tier;
    final initials = customerName.isNotEmpty
        ? customerName
              .trim()
              .split(' ')
              .take(2)
              .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
              .join()
        : 'LD';

    Color tierColor = AppColors.tierPremium;
    String tierText = 'NEW PROSPECT';
    if (tier == CustomerTier.PREMIUM) {
      tierColor = AppColors.tierPremium;
      tierText = 'PREMIUM CUSTOMER';
    } else if (tier == CustomerTier.LOYAL) {
      tierColor = AppColors.tierLoyal;
      tierText = 'LOYAL CUSTOMER';
    } else if (tier == CustomerTier.INTERIOR_DESIGNER) {
      tierColor = AppColors.tierInterior;
      tierText = 'INTERIOR DESIGNER';
    }

    return GestureDetector(
      onTap: () => _showLeadDetail(opp),
      child: Container(
        padding: const EdgeInsets.all(16),
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
                // Avatar initials circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: tierColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tierText,
                        style: TextStyle(
                          color: tierColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Call icon action
                GestureDetector(
                  onTap: () => _makeCall(opp.customer?.phone),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.callGreen.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_rounded,
                      color: AppColors.callGreen,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT STAGE',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      opp.projectTitle,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: opp.isHot
                        ? AppColors.tempHot.withValues(alpha: 0.15)
                        : AppColors.surfaceElevated,
                    borderRadius: AppRadius.radiusSm,
                    border: Border.all(
                      color: opp.isHot
                          ? AppColors.tempHot.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    opp.isHot ? 'HIGH PRIORITY' : 'FOLLOW-UP: ACTIVE',
                    style: TextStyle(
                      color: opp.isHot
                          ? AppColors.tempHot
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.inbox_rounded, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No leads found matching your criteria.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(LeadProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage ??
                  'An error occurred loading ongoing leads.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.loadOngoingLeads(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadDetailSheet extends StatelessWidget {
  final Opportunity opportunity;

  const _LeadDetailSheet({required this.opportunity});

  void _showCloseDealDialog(BuildContext context) {
    final notesController = TextEditingController();
    String selectedStatus = 'CLOSED_WON';
    String selectedTier = 'LOYAL';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusLg,
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text(
            'Close Deal / Update Status',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Status Option (Backend Supported):',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary),
                items: const [
                  DropdownMenuItem(
                    value: 'CLOSED_WON',
                    child: Text('Closed Won (Lead Completed)'),
                  ),
                  DropdownMenuItem(
                    value: 'CLOSED_LOST',
                    child: Text('Closed Lost'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedStatus = val);
                  }
                },
              ),
              if (selectedStatus == 'CLOSED_WON') ...[
                const SizedBox(height: 12),
                const Text(
                  'Assigned Customer Tier:',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedTier,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.textPrimary),
                  items: const [
                    DropdownMenuItem(
                      value: 'PREMIUM',
                      child: Text('Premium Customer'),
                    ),
                    DropdownMenuItem(
                      value: 'LOYAL',
                      child: Text('Loyal Customer'),
                    ),
                    DropdownMenuItem(
                      value: 'INTERIOR_DESIGNER',
                      child: Text('Interior Designer'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedTier = val);
                    }
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Conclusion notes...',
                ),
              ),
            ],
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
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                try {
                  await context.read<LeadProvider>().updateStatus(
                    opportunity.opportunityId,
                    dealStatus: selectedStatus,
                    tier: selectedStatus == 'CLOSED_WON' ? selectedTier : null,
                    conclusionNotes: notesController.text.trim().isNotEmpty
                        ? notesController.text.trim()
                        : null,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close sheet
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Lead status updated to $selectedStatus.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update status: $e'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context) {
    final noteController = TextEditingController();
    DateTime? nextDate;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusLg,
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text(
            'Log Conversation Note',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: noteController,
                maxLines: 3,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Enter conclusion notes...',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(
                  nextDate == null
                      ? 'Schedule Follow-up Call'
                      : DateFormat('dd MMM yyyy').format(nextDate!),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => nextDate = picked);
                  }
                },
              ),
            ],
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
              onPressed: () async {
                if (noteController.text.trim().isEmpty) return;
                Navigator.of(dialogCtx).pop();
                try {
                  await context.read<LeadProvider>().addNote(
                    opportunity.opportunityId,
                    notes: noteController.text.trim(),
                    nextCallDate: nextDate,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Follow-up note logged successfully.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to add note: $e'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Note'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                opportunity.projectTitle,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Customer: ${opportunity.customer?.name ?? 'ID: ${opportunity.customerId}'}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          if (opportunity.locationName != null &&
              opportunity.locationName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Location: ${opportunity.locationName}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _buildBadge(
                'Status: ${opportunity.dealStatus.name}',
                opportunity.dealStatus == DealStatus.PIPELINE
                    ? AppColors.callGreen
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              _buildBadge(
                'Temp: ${opportunity.leadTemperature.name}',
                opportunity.isHot ? AppColors.tempHot : AppColors.tempWarm,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.note_add_rounded, size: 18),
                  label: const Text('Add Note'),
                  onPressed: () => _showAddNoteDialog(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Close Deal'),
                  onPressed: () => _showCloseDealDialog(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
