// Customer Detail and Complete Lead History Screen
// Displays:
//   - Full customer information (Name, phone, billing address, type, tier, blacklist status, created date)
//   - Blacklist / Unblacklist actions with confirmation dialog and mandatory reason for Admin/Manager
//   - Complete Lead/Opportunity history (sorted newest first, status tags, temperatures, notes, next call dates)
//   - Clean empty state if customer has no leads
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_theme.dart';
import '../../core/api/customer_service.dart';
import '../../models/customer.dart';
import '../../models/opportunity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';

class CustomerDetailScreen extends StatefulWidget {
  final int customerId;
  final Customer? initialCustomer;
  final CustomerService? customerService;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    this.initialCustomer,
    this.customerService,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late final CustomerService _customerService =
      widget.customerService ?? CustomerService();

  bool _isLoading = true;
  String? _errorMessage;
  Customer? _customer;
  List<Opportunity> _opportunities = [];

  @override
  void initState() {
    super.initState();
    _customer = widget.initialCustomer;
    _fetchCustomerDetails();
  }

  Future<void> _fetchCustomerDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _customerService.getCustomerOpportunities(
        widget.customerId,
      );

      if (mounted) {
        setState(() {
          _customer = result.customer ?? _customer;
          _opportunities = result.opportunities;
          // Sort newest first
          _opportunities.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number on record for this customer.'),
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
            content: Text('Cannot launch dialer for $phone.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showBlacklistDialog() {
    final reasonController = TextEditingController();
    String? localError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusLg,
            side: const BorderSide(color: AppColors.border),
          ),
          title: Row(
            children: const [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.danger,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Blacklist Customer',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to blacklist "${_customer?.name ?? 'this customer'}"? '
                'They will be restricted from future lead generation and flagged team-wide.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Blacklist Reason *',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 2,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  hintText:
                      'Enter reason (e.g. Non-payment, dispute, fake lead)...',
                ),
              ),
              if (localError != null) ...[
                const SizedBox(height: 8),
                Text(
                  localError!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  setDialogState(() {
                    localError =
                        'A reason is required to blacklist a customer.';
                  });
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(dialogCtx).pop();
                final provider = context.read<CustomerProvider>();
                final success = await provider.blockCustomer(
                  widget.customerId,
                  reason: reason,
                );

                if (mounted) {
                  if (success) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Customer "${_customer?.name}" blacklisted.',
                        ),
                        backgroundColor: AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    _fetchCustomerDetails();
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.errorMessage ??
                              'Failed to blacklist customer.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Blacklist'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnblacklistDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusLg,
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Restore from Blacklist',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to unblacklist "${_customer?.name ?? 'this customer'}" and allow new leads to be created?',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.callGreen,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(dialogCtx).pop();
              final provider = context.read<CustomerProvider>();
              await provider.unblockCustomer(widget.customerId);

              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Customer "${_customer?.name}" restored successfully.',
                    ),
                    backgroundColor: AppColors.callGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _fetchCustomerDetails();
              }
            },
            child: const Text('Unblacklist'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final canManage = authProvider.currentEmployee?.canManage ?? false;
    final isBlocklisted = _customer?.isBlocklisted ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _customer?.name ?? 'Customer Profile',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (canManage && !isBlocklisted)
            IconButton(
              icon: const Icon(
                Icons.person_off_rounded,
                color: AppColors.danger,
              ),
              tooltip: 'Blacklist Customer',
              onPressed: _showBlacklistDialog,
            )
          else if (canManage && isBlocklisted)
            IconButton(
              icon: const Icon(
                Icons.lock_open_rounded,
                color: AppColors.callGreen,
              ),
              tooltip: 'Unblacklist Customer',
              onPressed: _showUnblacklistDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
          ? _buildErrorView()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Summary Card
                  _buildCustomerHeaderCard(canManage, isBlocklisted),
                  const SizedBox(height: 24),

                  // Section Header: Complete Lead History
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'LEAD HISTORY',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.radiusPill,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${_opportunities.length} TOTAL LEADS',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Lead List or Empty State
                  if (_opportunities.isEmpty)
                    _buildEmptyHistory()
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _opportunities.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildOpportunityHistoryCard(
                          _opportunities[index],
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildCustomerHeaderCard(bool canManage, bool isBlocklisted) {
    final customer = _customer;
    if (customer == null) return const SizedBox.shrink();

    final initials = customer.name.isNotEmpty
        ? (customer.name.trim().split(' ').length > 1
              ? '${customer.name.trim().split(' ')[0][0]}${customer.name.trim().split(' ')[1][0]}'
              : customer.name[0])
        : '?';

    final badgeColor = isBlocklisted
        ? AppColors.danger
        : customer.isNew
        ? AppColors.typeNew
        : customer.tier == CustomerTier.PREMIUM
        ? AppColors.tierPremium
        : customer.tier == CustomerTier.LOYAL
        ? AppColors.tierLoyal
        : AppColors.tierInterior;

    final joinedDate = customer.createdAt != null
        ? DateFormat('dd MMM yyyy').format(customer.createdAt!)
        : 'Unknown';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(
          color: isBlocklisted
              ? AppColors.danger.withValues(alpha: 0.6)
              : AppColors.border,
          width: isBlocklisted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    initials.toUpperCase(),
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
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
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: AppRadius.radiusSm,
                          ),
                          child: Text(
                            isBlocklisted
                                ? 'RESTRICTED / BLACKLISTED'
                                : customer.categoryDisplayTitle.toUpperCase(),
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (customer.phone != null && customer.phone!.isNotEmpty)
                GestureDetector(
                  onTap: () => _makeCall(customer.phone),
                  child: Container(
                    width: 42,
                    height: 42,
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

          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),

          // Detail rows
          if (customer.phone != null && customer.phone!.isNotEmpty) ...[
            _buildInfoRow(Icons.phone_rounded, 'Phone', customer.phone!),
            const SizedBox(height: 10),
          ],
          if (customer.billingAddress != null &&
              customer.billingAddress!.isNotEmpty) ...[
            _buildInfoRow(
              Icons.location_on_rounded,
              'Address',
              customer.billingAddress!,
            ),
            const SizedBox(height: 10),
          ],
          _buildInfoRow(
            Icons.calendar_today_rounded,
            'Customer Since',
            joinedDate,
          ),

          if (isBlocklisted) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerSurface,
                borderRadius: AppRadius.radiusMd,
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.report_problem_rounded,
                        color: AppColors.danger,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'BLACKLIST REASON',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    customer.blocklistReason ??
                        'Flagged as restricted account by manager/admin.',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (canManage) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isBlocklisted
                      ? AppColors.callGreen
                      : AppColors.danger,
                  side: BorderSide(
                    color: isBlocklisted
                        ? AppColors.callGreen
                        : AppColors.danger,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusMd,
                  ),
                ),
                icon: Icon(
                  isBlocklisted
                      ? Icons.lock_open_rounded
                      : Icons.person_off_rounded,
                  size: 18,
                ),
                label: Text(
                  isBlocklisted ? 'Unblacklist Customer' : 'Blacklist Customer',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: isBlocklisted
                    ? _showUnblacklistDialog
                    : _showBlacklistDialog,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOpportunityHistoryCard(Opportunity opp) {
    final dateStr = opp.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(opp.createdAt!.toLocal())
        : 'Unknown Date';

    // Status badge style
    Color statusColor;
    String statusText;
    switch (opp.dealStatus) {
      case DealStatus.CLOSED_WON:
        statusColor = AppColors.callGreen;
        statusText = 'WON';
        break;
      case DealStatus.CLOSED_LOST:
        statusColor = AppColors.danger;
        statusText = 'LOST';
        break;
      case DealStatus.OTHER:
        statusColor = AppColors.tierInterior;
        statusText = 'OTHER';
        break;
      case DealStatus.PIPELINE:
        statusColor = AppColors.tempWarm;
        statusText = 'PIPELINE';
        break;
    }

    // Lead temperature badge
    Color tempColor;
    switch (opp.leadTemperature) {
      case LeadTemperature.HOT:
        tempColor = AppColors.tempHot;
        break;
      case LeadTemperature.WARM:
        tempColor = AppColors.tempWarm;
        break;
      case LeadTemperature.COLD:
        tempColor = AppColors.tempCold;
        break;
    }

    // Lead notes / conclusion notes
    final notes = opp.leadNotes;
    final latestNote = (notes != null && notes.isNotEmpty) ? notes.first : null;
    final noteText = latestNote?.conclusionNotes;

    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opportunity #${opp.opportunityId}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      opp.projectTitle,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tempColor.withValues(alpha: 0.15),
                      borderRadius: AppRadius.radiusSm,
                    ),
                    child: Text(
                      opp.leadTemperature.name,
                      style: TextStyle(
                        color: tempColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: AppRadius.radiusSm,
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),

          if (opp.locationName != null && opp.locationName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    opp.locationName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (opp.closureReason != null && opp.closureReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: AppRadius.radiusSm,
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Closure Reason: ${opp.closureReason}',
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (noteText != null && noteText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: AppRadius.radiusMd,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notes_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      noteText,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (latestNote?.nextCallDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.event_rounded,
                  size: 13,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Next Follow-up: ${DateFormat('dd MMM yyyy').format(latestNote!.nextCallDate!.toLocal())}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: const [
            Icon(Icons.history_rounded, size: 36, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No Lead History Found',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'No past opportunities have been recorded for this customer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
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
              _errorMessage ?? 'Failed to load customer profile.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchCustomerDetails,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
