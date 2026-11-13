// Suniti Construction CRM - Home Dashboard Screen
// Faithfully matches ui-screen/aea4dabffa-a5604329ed7ba9a47293.png
// Added Notification Bell in Top App Bar linking to TodaysCallsScreen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../models/daily_task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/task_provider.dart';
import '../blocklist/blacklisted_customers_screen.dart';
import '../customers/customer_list_screen.dart';
import '../leads/create_lead_screen.dart';
import '../leads/ongoing_leads_screen.dart';
import '../tasks/todays_calls_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onTabChange;

  const HomeScreen({super.key, this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTodayTasks();
      context.read<LeadProvider>().loadOngoingLeads();
    });
  }

  void _openTodaysCalls() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const TodaysCallsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final leadProvider = context.watch<LeadProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final employee = authProvider.currentEmployee;

    final activeLeadsCount = leadProvider.activePipelineLeads.length;
    final todayFollowUpsCount = taskProvider.pendingTasksCount;
    final todayDueCallsCount = taskProvider.todayDueNotificationCount;

    final DailyTask? nextTask = taskProvider.todayTasks.isNotEmpty
        ? taskProvider.todayTasks.firstWhere(
            (t) => !t.isCompleted,
            orElse: () => taskProvider.todayTasks.first,
          )
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top App Bar & Profile Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadius.radiusMd,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.apartment_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Suniti',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Notification Bell with badge for Today's Calls
                      Stack(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.notifications_outlined,
                                size: 22,
                              ),
                              color: AppColors.textPrimary,
                              onPressed: _openTodaysCalls,
                            ),
                          ),
                          if (todayDueCallsCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$todayDueCallsCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),

                      // Search Icon
                      Container(
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.search_rounded, size: 20),
                          color: AppColors.textPrimary,
                          onPressed: () {
                            if (widget.onTabChange != null) {
                              widget.onTabChange!(1); // Go to Ongoing Leads
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Employee Profile Avatar & Menu
                      PopupMenuButton<String>(
                        color: AppColors.surfaceElevated,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusMd,
                          side: const BorderSide(color: AppColors.border),
                        ),
                        onSelected: (value) {
                          if (value == 'logout') {
                            authProvider.logout();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            enabled: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  employee?.name ?? 'Employee',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  employee?.role.name ?? 'SALES_REP',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  color: AppColors.danger,
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Sign Out',
                                  style: TextStyle(color: AppColors.danger),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: CircleAvatar(
                          radius: 19,
                          backgroundColor: AppColors.surfaceElevated,
                          child: Text(
                            employee?.name.isNotEmpty == true
                                ? employee!.name.substring(0, 1).toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. Greeting
              Text(
                _greeting,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                employee?.name ?? 'Sales Representative',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              // 3. Summary Card (Active Leads & Follow-ups)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.radiusXl,
                  border: Border.all(color: AppColors.border, width: 1.2),
                ),
                child: Row(
                  children: [
                    // Active Leads
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Leads',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                activeLeadsCount > 0
                                    ? activeLeadsCount.toString().padLeft(
                                        2,
                                        '0',
                                      )
                                    : '00',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Pipeline',
                                style: TextStyle(
                                  color: AppColors.callGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    Container(width: 1, height: 48, color: AppColors.border),
                    const SizedBox(width: 20),

                    // Follow-ups
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Follow-ups',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                todayFollowUpsCount > 0
                                    ? todayFollowUpsCount.toString().padLeft(
                                        2,
                                        '0',
                                      )
                                    : '00',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Today',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Grid Navigation Cards (2x2 Grid)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
                children: [
                  _buildNavCard(
                    context: context,
                    icon: Icons.people_alt_rounded,
                    iconColor: AppColors.typeNew,
                    iconBgColor: AppColors.typeNew.withValues(alpha: 0.15),
                    title: 'Customer\nList',
                    onTap: () {
                      if (widget.onTabChange != null) {
                        widget.onTabChange!(2); // Navigate to Customers Tab
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CustomerListScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildNavCard(
                    context: context,
                    icon: Icons.add_rounded,
                    iconColor: AppColors.primary,
                    iconBgColor: AppColors.primary.withValues(alpha: 0.15),
                    title: 'Create\nLead Track',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateLeadScreen(),
                        ),
                      );
                    },
                  ),
                  _buildNavCard(
                    context: context,
                    icon: Icons.trending_up_rounded,
                    iconColor: AppColors.callGreen,
                    iconBgColor: AppColors.callGreen.withValues(alpha: 0.15),
                    title: 'Ongoing\nLeads',
                    onTap: () {
                      if (widget.onTabChange != null) {
                        widget.onTabChange!(1); // Navigate to Ongoing Leads Tab
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OngoingLeadsScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildNavCard(
                    context: context,
                    icon: Icons.person_off_rounded,
                    iconColor: AppColors.tierInterior,
                    iconBgColor: AppColors.tierInterior.withValues(alpha: 0.15),
                    title: 'Blacklisted\nCustomers',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BlacklistedCustomersScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 5. Next Follow-up Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Next Follow-up',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: _openTodaysCalls,
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Follow-up card or clean empty state
              if (nextTask != null)
                _buildFollowUpCard(context, nextTask)
              else
                _buildEmptyFollowUpCard(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusXl,
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: AppRadius.radiusLg,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpCard(BuildContext context, DailyTask task) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.radiusLg,
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              color: AppColors.callGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.scheduledBy?.name ?? task.companyName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.taskInstruction ??
                      task.opportunity?.projectTitle ??
                      'Scheduled Call Today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.tierInterior.withValues(alpha: 0.15),
              borderRadius: AppRadius.radiusSm,
            ),
            child: const Text(
              'TODAY',
              style: TextStyle(
                color: AppColors.tierInterior,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFollowUpCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 32,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 10),
            Text(
              'No pending follow-ups scheduled for today',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
