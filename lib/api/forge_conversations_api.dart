import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'forge_device_inventory_models.dart';
import 'forge_scheduler_selection_preview.dart';
import 'forge_scheduler_selection_lease.dart';
import 'forge_device_credential_candidate.dart';
import 'forge_conversations_models.dart';
import 'forge_client_instance_resource_view.dart';
import 'forge_client_instance_session_view.dart';
import 'forge_client_instance_session_resource_convergence.dart';
import 'forge_pending_run_intent.dart';
import 'forge_run_observed.dart';
import 'forge_run_attempt_lease_dispatch_preflight.dart';
import 'forge_preflight_fixture.dart';
import 'forge_local_runner_preview.dart';
import 'forge_runner_dispatch_plan_preview.dart';
import 'forge_runner_dispatch_admission.dart';
import 'forge_runner_transport_admission.dart';
import 'forge_runner_execution_boundary.dart';
import 'forge_runner_attempt_boundary.dart';
import 'forge_runner_execution_intent.dart';
import 'forge_prompt_append_receipt.dart';
import 'forge_session_device_observation_wire.dart';
import 'forge_session_placement.dart';
import 'forge_session_runner_receipt_observation.dart';
import 'forge_session_runner_receipt_history.dart';
import 'forge_session_runner_reconciliation_projection.dart';
import 'forge_run_execution_evidence.dart';
import 'forge_execution_reconciliation_observation.dart';
import 'forge_device_enrollment_heartbeat_lifecycle_registry.dart';

part 'forge_conversations_api_transport.dart';
part 'forge_conversations_device_observation_api.dart';
part 'forge_conversations_inventory_resource_convergence_api.dart';
part 'forge_conversations_client_instance_resource_view_api.dart';
part 'forge_conversations_client_instance_session_view_api.dart';
part 'forge_conversations_client_instance_session_resource_convergence_api.dart';
part 'forge_conversations_pending_intent_api.dart';
part 'forge_conversations_pending_intent_api_validation.dart';
part 'forge_conversations_execution_consent_api.dart';
part 'forge_conversations_session_runner_receipt_api.dart';
part 'forge_conversations_session_runner_receipt_history_api.dart';
part 'forge_conversations_session_runner_reconciliation_projection_api.dart';
part 'forge_conversations_run_execution_evidence_api.dart';
part 'forge_conversations_local_runner_preview_api.dart';
part 'forge_conversations_run_attempt_lease_dispatch_preflight_api.dart';
part 'forge_conversations_runner_dispatch_plan_preview_api.dart';
part 'forge_conversations_runner_dispatch_admission_api.dart';
part 'forge_conversations_runner_transport_admission_api.dart';
part 'forge_conversations_runner_execution_boundary_api.dart';
part 'forge_conversations_runner_attempt_boundary_api.dart';
part 'forge_conversations_runner_execution_intent_api.dart';
part 'forge_conversations_run_observed_api.dart';
part 'forge_conversations_execution_reconciliation_api.dart';
part 'forge_conversations_lifecycle_registry_api.dart';
part 'forge_conversations_registry_placement_preview_api.dart';
part 'forge_conversations_scheduler_selection_preview_api.dart';
part 'forge_conversations_scheduler_selection_lease_api.dart';
part 'forge_conversations_device_credential_candidate_api.dart';
part 'forge_conversations_prompt_append_receipt_api.dart';
part 'forge_conversations_change_stream_api.dart';

part 'forge_conversations_readers.dart';
part 'forge_conversations_json.dart';
part 'forge_conversations_http.dart';

/// Authenticated, bounded transport for Forge's owner-scoped conversation API.
/// It does not persist tokens. A configured OAuth refresh callback can retry
/// one request after a 401; write retries preserve the original idempotency
/// key so the authorization retry cannot create a second operation.
class ForgeConversationsApi {
  static const int maxPageSize = 128;
  static const int maxRunPageSize = 25;
  static const int maxRunTimelinePageSize = 128;

  final Uri _origin;
  final String accessToken;
  final String? Function()? accessTokenProvider;
  final Future<String?> Function(String failedAccessToken)? refreshAccessToken;
  final http.Client _http;
  final Duration timeout;

  /// Uses a wall-clock deadline for explicitly opted-in candidate readers.
  /// Ordinary callers retain zone-local timeout behavior.
  final bool useWallClockTimeout;
  final Set<String> _rejectedAccessTokens = <String>{};

  ForgeConversationsApi({
    required String baseUrl,
    required this.accessToken,
    this.accessTokenProvider,
    this.refreshAccessToken,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
    this.useWallClockTimeout = false,
  }) : _origin = _parseOrigin(baseUrl),
       _http = httpClient ?? http.Client() {
    if (accessToken.trim().isEmpty || accessToken.contains(RegExp(r'[\r\n]'))) {
      throw ArgumentError.value(accessToken, 'accessToken');
    }
  }

  Future<ForgeConversationPage> listConversations({
    String? afterID,
    int limit = 50,
  }) async {
    final boundedLimit = _boundedLimit(limit);
    if (afterID != null &&
        afterID.isNotEmpty &&
        !_validConversationRequestID(afterID)) {
      throw ArgumentError.value(afterID, 'afterID');
    }
    final query = <String, String>{'limit': boundedLimit.toString()};
    if (afterID != null && afterID.isNotEmpty) query['after_id'] = afterID;
    final root = await _requestJson('GET', '/conversations', query: query);
    return ForgeConversationPage.fromJson(
      root,
      limit: boundedLimit,
      afterID: afterID == null || afterID.isEmpty ? null : afterID,
    );
  }

  Future<ForgeOwnedConversation> getConversation({
    required String conversationID,
  }) async {
    if (!_validConversationRequestID(conversationID)) {
      throw ArgumentError.value(conversationID, 'conversationID');
    }
    final path = '/conversations/${Uri.encodeComponent(conversationID)}';
    final root = await _requestJson('GET', path);
    final entry = ForgeOwnedConversation.fromJson(root);
    if (entry.conversation.id != conversationID) {
      throw const FormatException('Forge returned another conversation.');
    }
    return entry;
  }

  Future<ForgeConversationChangePage> conversationChanges({
    required int afterCursor,
    int limit = 100,
  }) async {
    if (afterCursor < 0 || afterCursor > 9007199254740991) {
      throw ArgumentError.value(afterCursor, 'afterCursor');
    }
    final boundedLimit = _boundedLimit(limit);
    final root = await _requestJson(
      'GET',
      '/conversation-changes',
      query: {
        'after_cursor': afterCursor.toString(),
        'limit': boundedLimit.toString(),
      },
    );
    return ForgeConversationChangePage.fromJson(
      root,
      requestedAfterCursor: afterCursor,
      limit: boundedLimit,
    );
  }

  Future<ForgeConversation> createConversation({
    required ForgeConversationScope scope,
    required String title,
    required String idempotencyKey,
  }) async {
    final root = await _requestJson(
      'POST',
      '/conversations',
      body: {'scope': scope.toJson(), 'title': title},
      idempotencyKey: idempotencyKey,
      expectedStatuses: const {201},
    );
    final created = ForgeConversation.fromJson(root);
    if (created.scope.kind != scope.kind ||
        created.scope.id != scope.id ||
        created.title != title) {
      throw const FormatException(
        'Forge returned a conversation that does not match the create request.',
      );
    }
    return created;
  }

  Future<ForgeConversationPromptPage> listPrompts({
    required String conversationID,
    ForgePromptCursor? before,
    int limit = 100,
  }) async {
    final boundedLimit = _boundedLimit(limit);
    if (!_validConversationRequestID(conversationID)) {
      throw ArgumentError.value(conversationID, 'conversationID');
    }
    if (before != null &&
        (before.createdAtMS < 0 ||
            before.createdAtMS > 9007199254740991 ||
            !_validConversationRequestID(before.promptID))) {
      throw ArgumentError.value(before, 'before');
    }
    final query = <String, String>{'limit': boundedLimit.toString()};
    if (before != null) {
      query['before_created_at_ms'] = before.createdAtMS.toString();
      query['before_prompt_id'] = before.promptID;
    }
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/prompts';
    final root = await _requestJson('GET', path, query: query);
    final page = ForgeConversationPromptPage.fromJson(
      root,
      limit: boundedLimit,
    );
    if (page.conversationID != conversationID ||
        page.prompts.any((prompt) => prompt.conversationID != conversationID)) {
      throw const FormatException(
        'Forge returned prompts for another session.',
      );
    }
    return page;
  }

  Future<ForgeConversationRunPage> listRuns({
    required String conversationID,
    ForgeRunCursor? before,
    int limit = maxRunPageSize,
  }) async {
    final boundedLimit = limit.clamp(1, maxRunPageSize).toInt();
    if (!_validRunRequestID(conversationID) ||
        (before != null &&
            (before.createdAtMS < 0 ||
                before.createdAtMS > 9007199254740991 ||
                !_validRunRequestID(before.runID)))) {
      throw ArgumentError.value(before, 'before');
    }
    final query = <String, String>{'limit': boundedLimit.toString()};
    if (before != null) {
      query['before_created_at_ms'] = before.createdAtMS.toString();
      query['before_run_id'] = before.runID;
    }
    final path = '/conversations/${Uri.encodeComponent(conversationID)}/runs';
    final root = await _requestJson('GET', path, query: query);
    return ForgeConversationRunPage.fromJson(
      root,
      requestedConversationID: conversationID,
      before: before,
      limit: boundedLimit,
    );
  }

  Future<ForgeRunTimelinePage> listRunTimeline({
    required String conversationID,
    required String runID,
    int afterSequence = 0,
    int limit = maxRunTimelinePageSize,
  }) async {
    final boundedLimit = limit.clamp(1, maxRunTimelinePageSize).toInt();
    if (!_validRunRequestID(conversationID) || !_validRunRequestID(runID)) {
      throw ArgumentError.value('$conversationID/$runID', 'run IDs');
    }
    if (afterSequence < 0 || afterSequence > 9007199254740991) {
      throw ArgumentError.value(afterSequence, 'afterSequence');
    }
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/runs/'
        '${Uri.encodeComponent(runID)}/timeline';
    final root = await _requestJson(
      'GET',
      path,
      query: {
        'after_sequence': afterSequence.toString(),
        'limit': boundedLimit.toString(),
      },
    );
    return ForgeRunTimelinePage.fromJson(
      root,
      requestedConversationID: conversationID,
      requestedRunID: runID,
      requestedAfterSequence: afterSequence,
      limit: boundedLimit,
    );
  }

  Future<ForgePromptAppendResult> appendPrompt({
    required String conversationID,
    required String content,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    if (!_validConversationRequestID(conversationID)) {
      throw ArgumentError.value(conversationID, 'conversationID');
    }
    if (content.trim().isEmpty || utf8.encode(content).length > 256 * 1024) {
      throw ArgumentError.value(content, 'content');
    }
    if (!_validIdempotencyKey(idempotencyKey)) {
      throw ArgumentError.value(idempotencyKey, 'idempotencyKey');
    }
    if (expectedVersion < 1 || expectedVersion > 9007199254740991) {
      throw ArgumentError.value(expectedVersion, 'expectedVersion');
    }
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/prompts';
    final root = await _requestJson(
      'POST',
      path,
      body: {'content': content, 'expected_version': expectedVersion},
      idempotencyKey: idempotencyKey,
      expectedStatuses: const {200, 201},
    );
    final result = ForgePromptAppendResult.fromJson(root);
    if (result.prompt.conversationID != conversationID ||
        result.prompt.content != content ||
        result.prompt.role != 'user' ||
        !_validPromptResponseID(result.prompt.id) ||
        result.aggregateVersion != expectedVersion + 1) {
      throw const FormatException('Forge returned an invalid prompt result.');
    }
    return result;
  }

  /// Submits one caller-supplied, offline placement declaration for an
  /// authenticated comparison. The server must bind the declaration owner to
  /// its verified Snaplink principal; this method never treats the result as
  /// inventory, reservation, scheduling, or execution authority.
  Future<ForgeDevicePlacementResult> previewDevicePlacement({
    required ForgeDevicePlacementRequest request,
  }) async {
    // Keep the client-side contract fail-closed before sending malformed
    // declarations, while still using the server as the authoritative owner
    // boundary and evaluator.
    final validatedRequest = ForgeDevicePlacementRequest.fromJson(
      request.toJson(),
    );
    final expected = dryRunForgeDevicePlacement(validatedRequest);
    final root = await _requestJson(
      'POST',
      '/device-placement/preview',
      body: validatedRequest.toJson(),
    );
    final result = ForgeDevicePlacementResult.fromJson(root);
    final expectedDeviceIDs = validatedRequest.devices
        .map((device) => device.deviceID)
        .toSet();
    if (result.owner != validatedRequest.owner ||
        result.evaluatedAtMS != validatedRequest.evaluatedAtMS ||
        result.deviceResults.length != validatedRequest.devices.length ||
        result.deviceResults.map((device) => device.deviceID).toSet().length !=
            expectedDeviceIDs.length ||
        result.deviceResults.any(
          (device) => !expectedDeviceIDs.contains(device.deviceID),
        ) ||
        !_samePlacementPreview(result, expected)) {
      throw const FormatException('Forge returned another placement preview.');
    }
    return result;
  }

  static int _boundedLimit(int value) => value.clamp(1, maxPageSize);
  static Uri _parseOrigin(String value) => _parseForgeApiOrigin(value);

  void close() => _http.close();
}
