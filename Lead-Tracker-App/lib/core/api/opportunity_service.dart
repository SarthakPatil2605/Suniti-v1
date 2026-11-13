// Opportunity Service — wraps /api/opportunities/* endpoints
// Response shapes verified against opportunity.controller.js (Suniti V-2 branch)
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../../models/opportunity.dart';
import '../../models/lead_note.dart';

/// Result returned after adding a note to an opportunity.
class AddNoteResult {
  final LeadNote note;
  final Opportunity opportunity;

  const AddNoteResult({required this.note, required this.opportunity});
}

class OpportunityService {
  final ApiClient _apiClient;

  OpportunityService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// GET /api/opportunities
  /// Fetches opportunities (if endpoint available or query params provided).
  Future<List<Opportunity>> getOpportunities({
    String? dealStatus,
    String? leadTemperature,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (dealStatus != null) queryParams['deal_status'] = dealStatus;
      if (leadTemperature != null) {
        queryParams['lead_temperature'] = leadTemperature;
      }

      final response = await _apiClient.get(
        ApiEndpoints.opportunities,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final data = response.data;

      if (data is Map<String, dynamic>) {
        final list = data['opportunities'] ?? data['data'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map(Opportunity.fromJson)
              .toList();
        }
      } else if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(Opportunity.fromJson)
            .toList();
      }
      return [];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(
        message: 'Failed to fetch opportunities: $e',
      );
    }
  }

  /// GET /api/opportunities/:id
  Future<Opportunity> getOpportunityById(int id) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.opportunityById(id));
      final data = response.data;

      if (data is Map<String, dynamic>) {
        final oppMap =
            (data['opportunity'] ?? data['data'] ?? data)
                as Map<String, dynamic>;
        return Opportunity.fromJson(oppMap);
      }
      throw const UnexpectedApiException(
        message: 'Invalid response format for opportunity detail.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(
        message: 'Failed to fetch opportunity $id: $e',
      );
    }
  }

  /// POST /api/opportunities
  /// Creates a new opportunity for an existing customer.
  Future<Opportunity> createOpportunity({
    required int customerId,
    required String projectTitle,
    required String locationName,
    String leadTemperature = 'WARM',
    String dealStatus = 'PIPELINE',
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.opportunities,
        data: {
          'customer_id': customerId,
          'project_title': projectTitle.trim(),
          'location_name': locationName.trim(),
          'lead_temperature': leadTemperature,
          'deal_status': dealStatus,
        },
      );
      final data = response.data;

      if (data is Map<String, dynamic>) {
        final oppMap =
            (data['opportunity'] ?? data['data']) as Map<String, dynamic>?;
        if (oppMap != null) {
          return Opportunity.fromJson(oppMap);
        }
      }
      throw const UnexpectedApiException(
        message: 'Malformed response received while creating opportunity.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(message: 'Failed to create opportunity: $e');
    }
  }

  /// PATCH /api/opportunities/:id/status
  /// Updates deal_status. When closing as CLOSED_WON and customer_type == NEW,
  /// a [tier] must be provided — backend enforces this.
  /// Body: { deal_status: String, tier?: String, conclusion_notes?: String }
  Future<Opportunity> updateOpportunityStatus(
    int opportunityId, {
    required String dealStatus,
    String? tier,
    String? conclusionNotes,
  }) async {
    try {
      final body = <String, dynamic>{'deal_status': dealStatus};
      if (tier != null) body['tier'] = tier;
      if (conclusionNotes != null) body['conclusion_notes'] = conclusionNotes;

      final response = await _apiClient.patch(
        ApiEndpoints.opportunityStatus(opportunityId),
        data: body,
      );
      final data = response.data;

      if (data is! Map<String, dynamic>) {
        throw const UnexpectedApiException(
          message: 'Unexpected response format from opportunity status update.',
        );
      }

      final oppMap = data['opportunity'] as Map<String, dynamic>?;
      if (oppMap == null) {
        throw const UnexpectedApiException(
          message: 'Opportunity field missing in status update response.',
        );
      }
      return Opportunity.fromJson(oppMap);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(
        message: 'Failed to update opportunity status: $e',
      );
    }
  }

  /// POST /api/opportunities/:id/notes
  /// Logs a conversation conclusion note. Optionally updates lead_temperature
  /// and schedules a follow-up call (next_call_date).
  /// Body: { conclusion_notes: String, next_call_date?: ISO String, lead_temperature?: String }
  Future<AddNoteResult> addOpportunityNote(
    int opportunityId, {
    required String conclusionNotes,
    DateTime? nextCallDate,
    String? leadTemperature,
  }) async {
    try {
      final body = <String, dynamic>{'conclusion_notes': conclusionNotes};
      if (nextCallDate != null) {
        body['next_call_date'] = nextCallDate.toIso8601String();
      }
      if (leadTemperature != null) {
        body['lead_temperature'] = leadTemperature;
      }

      final response = await _apiClient.post(
        ApiEndpoints.opportunityNotes(opportunityId),
        data: body,
      );
      final data = response.data;

      if (data is! Map<String, dynamic>) {
        throw const UnexpectedApiException(
          message: 'Unexpected response format from add note endpoint.',
        );
      }

      final noteMap = data['note'] as Map<String, dynamic>?;
      final oppMap = data['opportunity'] as Map<String, dynamic>?;

      if (noteMap == null || oppMap == null) {
        throw const UnexpectedApiException(
          message: 'note or opportunity field missing in add note response.',
        );
      }

      return AddNoteResult(
        note: LeadNote.fromJson(noteMap),
        opportunity: Opportunity.fromJson(oppMap),
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException(
        message: 'Failed to add note to opportunity $opportunityId: $e',
      );
    }
  }
}
