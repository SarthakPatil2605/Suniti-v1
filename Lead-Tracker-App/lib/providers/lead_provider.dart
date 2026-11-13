// Lead and Opportunity state provider — wired to OpportunityService & TaskService
import 'package:flutter/foundation.dart';

import '../core/api/opportunity_service.dart';
import '../core/api/task_service.dart';
import '../core/api/api_exceptions.dart';
import '../models/opportunity.dart';
import '../models/daily_task.dart';

enum OngoingLeadTab { all, highPriority, scheduledToday }

class LeadProvider extends ChangeNotifier {
  final OpportunityService _opportunityService;
  final TaskService _taskService;

  LeadProvider({
    OpportunityService? opportunityService,
    TaskService? taskService,
  }) : _opportunityService = opportunityService ?? OpportunityService(),
       _taskService = taskService ?? TaskService();

  List<Opportunity> _opportunities = [];
  List<DailyTask> _scheduledTodayTasks = [];
  Opportunity? _selectedOpportunity;
  OngoingLeadTab _selectedTab = OngoingLeadTab.all;
  String _searchQuery = '';

  bool _isLoading = false;
  String? _errorMessage;

  List<Opportunity> get opportunities => _opportunities;
  List<DailyTask> get scheduledTodayTasks => _scheduledTodayTasks;
  Opportunity? get selectedOpportunity => _selectedOpportunity;
  OngoingLeadTab get selectedTab => _selectedTab;
  String get searchQuery => _searchQuery;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Opportunity> get activePipelineLeads => _opportunities
      .where((opp) => opp.dealStatus == DealStatus.PIPELINE)
      .toList();

  List<Opportunity> get highPriorityLeads => _opportunities
      .where((opp) => opp.leadTemperature == LeadTemperature.HOT)
      .toList();

  /// Filtered list according to current tab and search query
  List<Opportunity> get filteredOpportunities {
    List<Opportunity> list;
    switch (_selectedTab) {
      case OngoingLeadTab.all:
        list = _opportunities;
        break;
      case OngoingLeadTab.highPriority:
        list = highPriorityLeads;
        break;
      case OngoingLeadTab.scheduledToday:
        // Match opportunities that have an incomplete task scheduled specifically for today (local time)
        final now = DateTime.now();
        final todayOppIds = _scheduledTodayTasks
            .where((t) {
              if (t.isCompleted || t.scheduledCallDate == null) return false;
              final d = t.scheduledCallDate!.toLocal();
              return d.year == now.year &&
                  d.month == now.month &&
                  d.day == now.day;
            })
            .map((t) => t.opportunity?.opportunityId)
            .whereType<int>()
            .toSet();
        list = _opportunities
            .where((opp) => todayOppIds.contains(opp.opportunityId))
            .toList();
        break;
    }

    if (_searchQuery.trim().isEmpty) {
      return list;
    }

    final query = _searchQuery.trim().toLowerCase();
    return list.where((opp) {
      final titleMatch = opp.projectTitle.toLowerCase().contains(query);
      final customerMatch =
          opp.customer?.name.toLowerCase().contains(query) ?? false;
      final locationMatch =
          opp.locationName?.toLowerCase().contains(query) ?? false;
      return titleMatch || customerMatch || locationMatch;
    }).toList();
  }

  void setSelectedTab(OngoingLeadTab tab) {
    _selectedTab = tab;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void setOpportunities(List<Opportunity> opportunities) {
    _opportunities = opportunities;
    _errorMessage = null;
    notifyListeners();
  }

  void setSelectedOpportunity(Opportunity? opportunity) {
    _selectedOpportunity = opportunity;
    notifyListeners();
  }

  /// Load ongoing leads from API (combines opportunities endpoint and today's tasks)
  Future<void> loadOngoingLeads() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Fetch opportunities
      final opps = await _opportunityService.getOpportunities(
        dealStatus: 'PIPELINE',
      );
      _opportunities = opps;

      // 2. Fetch today's tasks to identify scheduled today opportunities
      try {
        final tasksRes = await _taskService.getTodayTasks();
        _scheduledTodayTasks = tasksRes.tasks;
      } catch (_) {
        // Soft-fail for tasks
      }

      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to load ongoing leads: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update lead status (e.g. CLOSED_WON or CLOSED_LOST)
  Future<Opportunity?> updateStatus(
    int opportunityId, {
    required String dealStatus,
    String? tier,
    String? conclusionNotes,
  }) async {
    try {
      final updated = await _opportunityService.updateOpportunityStatus(
        opportunityId,
        dealStatus: dealStatus,
        tier: tier,
        conclusionNotes: conclusionNotes,
      );

      // Refresh local list
      final idx = _opportunities.indexWhere(
        (o) => o.opportunityId == opportunityId,
      );
      if (idx != -1) {
        _opportunities[idx] = updated;
      }
      notifyListeners();
      return updated;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Failed to update opportunity status.';
      notifyListeners();
      rethrow;
    }
  }

  /// Add a note to an opportunity
  Future<void> addNote(
    int opportunityId, {
    required String notes,
    DateTime? nextCallDate,
    String? leadTemperature,
  }) async {
    try {
      await _opportunityService.addOpportunityNote(
        opportunityId,
        conclusionNotes: notes,
        nextCallDate: nextCallDate,
        leadTemperature: leadTemperature,
      );
      await loadOngoingLeads();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Failed to add follow-up note.';
      notifyListeners();
      rethrow;
    }
  }
}
