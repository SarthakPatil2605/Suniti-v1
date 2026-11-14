// Today's Calls / Notifications Screen
// Displays only customers with scheduled follow-ups due today according to backend.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_theme.dart';
import '../../models/daily_task.dart';
import '../../providers/task_provider.dart';

class TodaysCallsScreen extends StatefulWidget {
  const TodaysCallsScreen({super.key});

  @override
  State<TodaysCallsScreen> createState() => _TodaysCallsScreenState();
}

class _TodaysCallsScreenState extends State<TodaysCallsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTodayTasks();
    });
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number provided for this customer.'),
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
            content: Text('Cannot launch phone dialer for $phone.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showCompleteDialog(DailyTask task) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _CompleteCallDialog(
        task: task,
        notesController: notesController,
        onComplete: (conclusionNotes) async {
          final taskProvider = context.read<TaskProvider>();
          await taskProvider.completeTask(
            task.taskId,
            conclusionNotes: conclusionNotes,
          );
          // Check if there was an error
          if (taskProvider.errorMessage != null) {
            throw Exception(taskProvider.errorMessage);
          }
        },
        onSuccess: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Call marked as completed.'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.callGreen,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final dueTasks = taskProvider.dueTodayTasks;

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
            const Text(
              "Today's Calls",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${dueTasks.length} PENDING CALLS FOR TODAY',
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
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: () => taskProvider.loadTodayTasks(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => taskProvider.loadTodayTasks(),
        child: taskProvider.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : taskProvider.errorMessage != null
            ? _buildErrorView(taskProvider)
            : dueTasks.isEmpty
            ? _buildEmptyView()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: dueTasks.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final task = dueTasks[index];
                  return _buildTaskCard(task);
                },
              ),
      ),
    );
  }

  Widget _buildTaskCard(DailyTask task) {
    final phone = task.contactDetails?.phone;
    final projectTitle = task.opportunity?.projectTitle ?? 'General Inquiry';
    final location = task.location ?? task.contactDetails?.billingAddress ?? '';
    final timeStr = task.scheduledCallDate != null
        ? DateFormat('hh:mm a').format(task.scheduledCallDate!.toLocal())
        : 'Today';

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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.phone_in_talk_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.companyName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      projectTitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.radiusSm,
                ),
                child: Text(
                  timeStr,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (task.taskInstruction != null &&
              task.taskInstruction!.isNotEmpty) ...[
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
                      task.taskInstruction!,
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.callGreen,
                    side: const BorderSide(color: AppColors.callGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusMd,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Mark Done',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _showCompleteDialog(task),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.callGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusMd,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text(
                    'Call Now',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => _makeCall(phone),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.radiusXl,
              ),
              child: const Center(
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.callGreen,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'All calls done for today!',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No pending follow-up calls scheduled for today.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(TaskProvider provider) {
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
              provider.errorMessage ?? 'Failed to load tasks.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                provider.clearError();
                provider.loadTodayTasks();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stateful dialog widget that manages its own loading/error state
// ---------------------------------------------------------------------------
class _CompleteCallDialog extends StatefulWidget {
  final DailyTask task;
  final TextEditingController notesController;
  final Future<void> Function(String?) onComplete;
  final VoidCallback onSuccess;

  const _CompleteCallDialog({
    required this.task,
    required this.notesController,
    required this.onComplete,
    required this.onSuccess,
  });

  @override
  State<_CompleteCallDialog> createState() => _CompleteCallDialogState();
}

class _CompleteCallDialogState extends State<_CompleteCallDialog> {
  bool _isSubmitting = false;
  String? _error;

  Future<void> _handleComplete() async {
    if (_isSubmitting) return; // Prevent duplicate submissions

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final notes = widget.notesController.text.trim();
      await widget.onComplete(notes.isNotEmpty ? notes : null);

      if (!mounted) return;
      // Success — close dialog and notify parent
      Navigator.of(context).pop();
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.radiusLg,
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text(
        'Mark Call as Done',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer: ${widget.task.companyName}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.notesController,
            maxLines: 3,
            enabled: !_isSubmitting,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Add conversation conclusion notes...',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: _isSubmitting
                  ? AppColors.textMuted
                  : AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.callGreen,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: _isSubmitting ? null : _handleComplete,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Complete Call'),
        ),
      ],
    );
  }
}
