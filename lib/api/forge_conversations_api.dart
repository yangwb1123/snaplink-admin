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

/// Reads the explicitly injected, owner-bound inventory candidate.
///
/// The callback is intentionally supplied by the caller so the Sessions
/// screen cannot invent an owner from a bearer token or silently enable the
/// production `/devices` route. A production caller must keep this unset
/// until the ADR-0114/P3b decision is accepted.
typedef ForgeDeviceInventoryCandidateReader =
    Future<ForgeDeviceInventoryPage> Function(ForgeDeviceOwner owner);

/// Reads the explicit owner-bound Runner execution-intent preview candidate.
/// The callback remains opt-in so normal Web/App/Mobile construction never
/// opens the preview route implicitly.
typedef ForgeRunnerExecutionIntentReader =
    Future<ForgeRunnerExecutionIntentObservation> Function(
      ForgeRunnerExecutionIntentRequest request,
    );

/// Reads the explicitly injected, owner-bound lossless v2 inventory
/// candidate. The callback stays unset by default so the production
/// `/devices/observations/v2` route remains disabled until ADR-0114/P3b is
/// accepted.
typedef ForgeDeviceInventoryV2Reader =
    Future<ForgeDeviceInventoryPageV2> Function(ForgeDeviceOwner owner);

/// Reads the v2 inventory and composed resource view as one explicit pair.
/// The callback stays opt-in so a shared Sessions surface cannot present two
/// different resource images as one observation by default.
typedef ForgeDeviceInventoryResourceConvergenceReader =
    Future<ForgeDeviceInventoryResourceConvergence> Function(
      ForgeDeviceOwner owner,
    );

/// Reads one explicit owner-bound registry placement preview. The callback is
/// intentionally separate from the v2 inventory reader because the HTTP
/// response is a compact evaluation projection without the caller fixture's
/// observation and requirements fields.
typedef ForgeDeviceRegistryPlacementPreviewReader =
    Future<ForgeDeviceRegistryPlacementPreview> Function(
      ForgeDeviceOwner owner,
      ForgeDevicePlacementRequirements requirements,
    );

/// Reads one explicit authenticated EXECUTE scheduler-selection preview. The
/// request is bound to a Conversation/Run/Attempt and remains display-only;
/// the callback must not issue a lease, reserve capacity, or dispatch work.
typedef ForgeSchedulerSelectionPreviewReader =
    Future<ForgeSchedulerSelectionPreview> Function(
      ForgeSchedulerSelectionPreviewRequest request,
    );

/// Claims one explicitly supplied owner-bound scheduler lease. The callback
/// is kept separate from the read-only scheduler preview so a shared
/// Sessions surface cannot create a reservation unless its caller opts in
/// with a fixed request and idempotency key.
typedef ForgeSchedulerSelectionLeaseReader =
    Future<ForgeSchedulerSelectionLease> Function(
      ForgeSchedulerSelectionLeaseRequest request,
      String idempotencyKey,
    );

/// Renews one explicitly supplied owner-bound scheduler lease proof. The
/// callback is separate from the claim reader so a shared Sessions surface
/// cannot renew a lease unless its caller opts in with the exact proof and a
/// fresh idempotency key.
typedef ForgeSchedulerSelectionLeaseRenewalReader =
    Future<ForgeSchedulerSelectionLease> Function(
      ForgeSchedulerSelectionLeaseRenewalRequest request,
      String idempotencyKey,
    );

/// Releases one explicitly supplied owner-bound scheduler lease proof. The
/// callback stays separate from claim and renewal so a Sessions surface can
/// mark a reservation inactive only when its caller opts in with the exact
/// proof and an explicit idempotency key.
typedef ForgeSchedulerSelectionLeaseReleaseReader =
    Future<ForgeSchedulerSelectionLeaseRelease> Function(
      ForgeSchedulerSelectionLeaseReleaseRequest request,
      String idempotencyKey,
    );

/// Reads one explicit owner/Run-bound durable lease-to-Runner admission
/// preview. The result is metadata only; it never authorizes or dispatches.
typedef ForgeRunnerDispatchAdmissionReader =
    Future<ForgeRunnerDispatchAdmission> Function(
      ForgeRunnerDispatchAdmissionRequest request,
    );

/// Reads one explicit owner/Run-bound Runner transport admission preview. The
/// result is metadata only; it never sends a transport payload or authorizes
/// execution.
typedef ForgeRunnerTransportAdmissionReader =
    Future<ForgeRunnerTransportAdmission> Function(
      ForgeRunnerTransportAdmissionRequest request,
    );

/// Reads one explicit owner/Run-bound Runner execution-boundary preview. The
/// result is metadata only; it never opens a Runner connection or dispatches.
typedef ForgeRunnerExecutionBoundaryReader =
    Future<ForgeRunnerExecutionBoundaryObservation> Function(
      ForgeRunnerExecutionBoundaryPreviewRequest request,
    );

/// Reads the explicitly injected, owner-bound client-instance/resource-view
/// candidate. The callback remains unset by default so the production
/// `/client-instances/resource-view` route cannot be reached accidentally.
typedef ForgeClientInstanceResourceViewReader =
    Future<ForgeClientInstanceResourceView> Function(ForgeDeviceOwner owner);

/// Reads the explicitly injected, owner-bound client-instance/session-view
/// candidate. The callback remains unset by default so the production
/// `/client-instances/session-view` route cannot be reached accidentally.
typedef ForgeClientInstanceSessionViewReader =
    Future<ForgeClientInstanceSessionView> Function(ForgeDeviceOwner owner);

/// Reads the explicit owner-bound client-instance session/resource pair. The
/// callback remains unset by default so the shared Sessions surface cannot
/// issue either candidate GET until a caller opts in with a declared owner.
typedef ForgeClientInstanceSessionResourceConvergenceReader =
    Future<ForgeClientInstanceSessionResourceConvergence> Function(
      ForgeDeviceOwner owner,
    );

/// Reads one caller-supplied, content-free Run observation for the selected
/// owner Conversation/Run pair.
///
/// This callback is deliberately injected rather than bound to a production
/// observer route. The Sessions screen re-decodes the returned value and
/// checks its selected Conversation/Run binding before displaying it. Keep it
/// unset until a reviewed read-only adapter is available.
typedef ForgeRunObservedReader =
    Future<ForgeRunObserved> Function(String conversationID, String runID);

/// Independently reads one content-free session Runner receipt for the
/// selected Conversation/Run. It remains unset by default. The Sessions
/// surface accepts its result only as one atomically converged pair with an
/// explicitly read [ForgeRunObserved].
typedef ForgeSessionRunnerReceiptObservationReader =
    Future<ForgeSessionRunnerReceiptObservation> Function(
      String conversationID,
      String runID,
    );

/// Reads one explicit binding of a content-free Run observation to its
/// matching session Runner receipt. The callback remains an injected
/// candidate seam so the shared Sessions surface cannot reach the route
/// unless its caller opts in with both source observations.
typedef ForgeRunExecutionEvidenceReader =
    Future<ForgeRunExecutionEvidence> Function(
      String conversationID,
      String runID,
      ForgeRunObserved runObserved,
      ForgeSessionRunnerReceiptObservation sessionReceiptObserved,
    );

/// Reads one explicit owner/Conversation/Run-bound Runner receipt history
/// reduction. The callback remains opt-in so the shared Sessions surface does
/// not contact the accepted EXECUTE candidate route by default.
typedef ForgeSessionRunnerReceiptHistoryReader =
    Future<ForgeSessionRunnerReceiptHistory> Function(
      String conversationID,
      String runID,
      ForgeSessionRunnerReceiptHistory history,
    );

/// Reads one explicit owner/Conversation/Run-bound manual reconciliation
/// projection derived from a complete receipt history. The callback remains
/// opt-in so the shared Sessions surface does not contact the preview route
/// by default.
typedef ForgeSessionRunnerReconciliationProjectionReader =
    Future<ForgeSessionRunnerReconciliationProjection> Function(
      String conversationID,
      String runID,
      ForgeSessionRunnerReceiptHistory history,
    );

/// Reads one caller-supplied, owner-bound execution reconciliation preview.
///
/// The callback remains an explicit injection so the Sessions screen cannot
/// derive a restart image from a bearer token or silently open the candidate
/// route. The input contains the Conversation/Run/Attempt/lease binding and
/// is re-decoded before the response is displayed.
typedef ForgeExecutionReconciliationReader =
    Future<ForgeExecutionReconciliationObservation> Function(
      ForgeExecutionReconciliationInput input,
    );

/// Reads one owner-bound execution-consent preview for the selected
/// Conversation. The callback remains an explicit candidate seam so a shared
/// Sessions surface cannot reach the preview route unless its caller opts in.
typedef ForgeExecutionConsentPreviewReader =
    Future<ForgeExecutionConsentPreview> Function({
      required ForgeDeviceOwner owner,
      required String conversationID,
    });

/// Reads one explicitly supplied, owner-bound Runner dispatch-plan preview.
///
/// The request carries the Conversation/Run/Attempt/lease declaration that
/// the candidate transport must bind to. The callback remains an injected
/// candidate seam so the shared Sessions surface cannot reach the preview
/// route unless a caller opts in explicitly.
typedef ForgeRunnerDispatchPlanPreviewReader =
    Future<ForgeRunnerDispatchPlanPreview> Function(
      ForgeRunAttemptLeaseDispatchPreflightRequest request,
    );

/// Reads one explicitly supplied, owner/path-bound local Runner execution
/// readiness preview. The request is a caller-declared Prompt/Run/lease
/// binding; the callback must not mint a lease, persist a receipt, dispatch a
/// command, or grant execution authority.
typedef ForgeLocalRunnerPreviewReader =
    Future<ForgeLocalRunnerPreviewObservation> Function(
      ForgeLocalRunnerPreviewRequest request,
    );

/// Reads the explicitly injected owner-bound lifecycle registry candidate.
/// The default Gate leaves this callback unset, so the candidate route is
/// unreachable from normal Web/App/Mobile construction.
typedef ForgeLifecycleRegistryReader =
    Future<ForgeDeviceEnrollmentHeartbeatLifecycleRegistry> Function(
      ForgeDeviceOwner owner,
    );

/// Posts one explicitly reviewed owner-bound credential lifecycle candidate.
/// The request is metadata-only; the callback must not mint or persist a
/// credential. Keeping this seam separate from the ordinary conversation
/// client prevents the production Gate from reaching the injected candidate
/// route accidentally.
typedef ForgeDeviceCredentialLifecycleCandidateReader =
    Future<ForgeDeviceCredentialLifecycleCandidate> Function({
      required ForgeDeviceOwner owner,
      required ForgeDeviceCredentialLifecycleRequest request,
    });

/// Reads the explicitly injected, owner-scoped pending Run-intent candidate.
///
/// The callback is intentionally supplied by the caller so the Sessions
/// screen cannot silently opt the production route into the inert execution
/// surface. It returns metadata only; the screen never receives a Prompt
/// body, creates a Run, selects a device, or dispatches work. Keep this unset
/// until the caller has an accepted governance decision for the candidate.
typedef ForgePendingRunIntentReader =
    Future<ForgePendingRunIntentListPage> Function(String conversationID);

/// Reads one bounded owner-scoped pending Run-intent page.
///
/// The nullable cursor is `null` for the first page and must be passed back
/// from the prior response for older pages. The callback remains an explicit
/// injection so adding read pagination cannot silently enable the production
/// `/run-intents` route before its governance decision is accepted.
typedef ForgePendingRunIntentPageReader =
    Future<ForgePendingRunIntentListPage> Function(
      String conversationID,
      ForgePendingRunIntentCursor? before,
    );

/// Reads one owner-scoped, payload-free pending Run-intent timeline.
///
/// The callback is intentionally supplied by the caller and is invoked only
/// after an owner expands one receipt in the Sessions surface. The screen
/// never receives Prompt content, creates a Run, selects a device, or
/// dispatches work. Keep this unset until the caller has an accepted
/// governance decision for the candidate.
typedef ForgePendingRunIntentTimelineReader =
    Future<ForgePendingRunIntentTimelinePage> Function(
      String conversationID,
      String intentID,
    );

/// Submits one explicit, owner-bound pending Run-intent candidate.
///
/// The submitter is kept as a Gate seam so the shared Sessions surface cannot
/// silently expose the write route in production. The server receipt remains
/// inert: it creates no Run, selects no device, and grants no execution
/// authority.
typedef ForgePendingRunIntentSubmitter =
    Future<ForgePendingRunIntentSubmission> Function({
      required ForgeDeviceOwner owner,
      required String conversationID,
      required String content,
      required int expectedVersion,
      required String idempotencyKey,
    });

/// Submits one explicit owner-bound Prompt append and returns only its
/// content-free receipt. The callback stays separate from the ordinary
/// append result so a Sessions surface cannot consume a receipt projection
/// without an explicit owner declaration and opt-in wiring.
typedef ForgePromptAppendReceiptSubmitter =
    Future<ForgePromptAppendReceiptObservation> Function({
      required ForgeDeviceOwner owner,
      required String conversationID,
      required String content,
      required int expectedVersion,
      required String idempotencyKey,
    });

class ForgeConversationsApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const ForgeConversationsApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}

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

  /// The preview route is a deterministic P3a comparison over the exact
  /// caller declaration. Keep a server response from silently changing the
  /// eligibility or exclusion projection before it reaches a shared client.
  /// The route still has no inventory, reservation, or execution authority.
  bool _samePlacementPreview(
    ForgeDevicePlacementResult actual,
    ForgeDevicePlacementResult expected,
  ) => jsonEncode(actual.toJson()) == jsonEncode(expected.toJson());

  Future<ForgeJson> _requestJson(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? idempotencyKey,
    Set<int> expectedStatuses = const {200},
    bool retryUnauthorized = true,
  }) async {
    final uri = _origin.resolve('/api/v1$path').replace(queryParameters: query);
    final initialAccessToken = _currentAccessToken();
    if (!_isSafeBearerToken(initialAccessToken)) {
      throw const ForgeConversationsApiException(
        statusCode: 401,
        code: 'missing_access_token',
        message: 'The Forge session has expired. Sign in again.',
      );
    }
    var response = await _sendWithReadRetry(
      method,
      uri,
      body: body,
      idempotencyKey: idempotencyKey,
      bearerToken: initialAccessToken,
    );
    if (response.statusCode == 401 &&
        refreshAccessToken != null &&
        retryUnauthorized) {
      String? rotatedAccessToken;
      try {
        rotatedAccessToken = await refreshAccessToken!(initialAccessToken);
      } on Exception {
        _rejectedAccessTokens.add(initialAccessToken);
        throw const ForgeConversationsApiException(
          statusCode: 503,
          code: 'token_refresh_failed',
          message: 'Snaplink could not refresh the Forge session.',
        );
      }
      if (rotatedAccessToken != null &&
          _isSafeBearerToken(rotatedAccessToken) &&
          rotatedAccessToken != initialAccessToken) {
        response = await _sendWithReadRetry(
          method,
          uri,
          body: body,
          idempotencyKey: idempotencyKey,
          bearerToken: rotatedAccessToken,
        );
        if (response.statusCode == 401) {
          _rejectedAccessTokens
            ..add(initialAccessToken)
            ..add(rotatedAccessToken);
        }
      } else {
        _rejectedAccessTokens.add(initialAccessToken);
      }
    }
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw const ForgeConversationsApiException(
        statusCode: 502,
        code: 'redirect_rejected',
        message: 'Forge redirected the request; the response was rejected.',
      );
    }
    final root = _decodeRootResponse(response);
    if (response.statusCode >= 400) {
      throw _decodeError(response.statusCode, root);
    }
    if (!expectedStatuses.contains(response.statusCode)) {
      throw const ForgeConversationsApiException(
        statusCode: 502,
        code: 'unexpected_status',
        message: 'Forge returned an unexpected response.',
      );
    }
    return root;
  }

  String _currentAccessToken() {
    final current = accessTokenProvider?.call();
    final token = accessTokenProvider == null || current == null
        ? accessToken
        : current;
    return _rejectedAccessTokens.contains(token) ? '' : token;
  }

  ForgeJson _decodeRoot(String body) {
    _rejectDuplicateForgeJsonKeys(body);
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Invalid Forge API response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  ForgeConversationsApiException _decodeError(int status, ForgeJson root) {
    final code = root['code'];
    final message = root['message'];
    return ForgeConversationsApiException(
      statusCode: status,
      code: code is String && code.isNotEmpty ? code : 'http_error',
      message: message is String && message.isNotEmpty
          ? message
          : 'Forge rejected the request (HTTP $status).',
    );
  }

  static int _boundedLimit(int value) => value.clamp(1, maxPageSize);
  static Uri _parseOrigin(String value) {
    final uri = Uri.tryParse(value.trim());
    final host = uri?.host.toLowerCase() ?? '';
    final parts = host.split('.');
    final loopback =
        host == 'localhost' ||
        host == '::1' ||
        (parts.length == 4 &&
            parts.first == '127' &&
            parts.every((part) {
              final octet = int.tryParse(part);
              return octet != null && octet >= 0 && octet <= 255;
            }));
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'https' && !(uri.scheme == 'http' && loopback)) ||
        !(uri.path.isEmpty || uri.path == '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(
        value,
        'baseUrl',
        'Expected a safe HTTPS origin.',
      );
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    );
  }

  void close() => _http.close();
}

bool _validRunRequestID(String value) =>
    value.trim().isNotEmpty &&
    utf8.encode(value).length <= 128 &&
    !value.runes.any((rune) => rune < 0x20 || (rune >= 0x7f && rune <= 0x9f));

bool _validConversationRequestID(String value) =>
    _validRunRequestID(value) && !value.contains('/');

/// Prompt IDs are response metadata, but they become the cursor and entity
/// identity used by every client after an append. Keep the ordinary write
/// response aligned with Core/Runtime before exposing it to a session UI.
bool _validPromptResponseID(String value) =>
    value.trim().isNotEmpty &&
    utf8.encode(value).length <= 128 &&
    !value.runes.any((rune) => rune < 0x20 || (rune >= 0x7f && rune <= 0x9f));

bool _validIdempotencyKey(String value) =>
    value.isNotEmpty &&
    value == value.trim() &&
    utf8.encode(value).length <= 256 &&
    !value.runes.any((rune) => rune < 0x20 || (rune >= 0x7f && rune <= 0x9f));

bool _isSafeBearerToken(String value) =>
    value.isNotEmpty &&
    value == value.trim() &&
    !value.contains(RegExp(r'[\r\n]'));

/// Dart's JSON decoder keeps the last value when an object repeats a key.
/// Forge responses are owner-scoped contracts, so accepting that ambiguity
/// could let a later field silently replace a validated earlier field. Scan
/// the raw response first and reject duplicate keys at every object depth.
void _rejectDuplicateForgeJsonKeys(String body) {
  _ForgeJsonDuplicateKeyScanner(body).scan();
}

bool _isForgeJsonWhitespace(String value) =>
    value == ' ' || value == '\t' || value == '\r' || value == '\n';

/// A small JSON grammar scanner used only to detect repeated object keys.
///
/// A character search is insufficient here: braces and quoted colons are
/// ordinary string data, and escaped key spellings such as `"a"` and
/// `"\\u0061"` identify the same JSON member. The scanner follows the JSON
/// structure and decodes only member names; the normal decoder still owns the
/// final response shape/type validation.
class _ForgeJsonDuplicateKeyScanner {
  final String _body;
  var _index = 0;

  _ForgeJsonDuplicateKeyScanner(this._body);

  void scan() {
    _skipWhitespace();
    _scanValue();
    _skipWhitespace();
    if (_index != _body.length) {
      throw const FormatException('Forge returned invalid JSON.');
    }
  }

  void _scanValue() {
    if (_index >= _body.length) {
      throw const FormatException('Forge returned invalid JSON.');
    }
    switch (_body[_index]) {
      case '{':
        _scanObject();
      case '[':
        _scanArray();
      case '"':
        _scanString();
      case 't':
        _scanLiteral('true');
      case 'f':
        _scanLiteral('false');
      case 'n':
        _scanLiteral('null');
      default:
        _scanNumber();
    }
  }

  void _scanObject() {
    _index++; // {
    _skipWhitespace();
    final keys = <String>{};
    if (_consume('}')) return;
    while (true) {
      if (_index >= _body.length || _body[_index] != '"') {
        throw const FormatException('Forge returned invalid JSON.');
      }
      final key = _scanString();
      if (!keys.add(key)) {
        throw const FormatException('Forge returned duplicate JSON fields.');
      }
      _skipWhitespace();
      _expect(':');
      _skipWhitespace();
      _scanValue();
      _skipWhitespace();
      if (_consume('}')) return;
      _expect(',');
      _skipWhitespace();
    }
  }

  void _scanArray() {
    _index++; // [
    _skipWhitespace();
    if (_consume(']')) return;
    while (true) {
      _scanValue();
      _skipWhitespace();
      if (_consume(']')) return;
      _expect(',');
      _skipWhitespace();
    }
  }

  String _scanString() {
    final start = _index;
    _expect('"');
    while (_index < _body.length) {
      final character = _body[_index++];
      if (character == '"') {
        final decoded = jsonDecode(_body.substring(start, _index));
        if (decoded is! String) {
          throw const FormatException('Forge returned invalid JSON.');
        }
        return decoded;
      }
      if (character == '\\') {
        if (_index >= _body.length) {
          throw const FormatException('Forge returned invalid JSON.');
        }
        final escaped = _body[_index++];
        if (escaped == 'u') {
          if (_index + 4 > _body.length) {
            throw const FormatException('Forge returned invalid JSON.');
          }
          for (var digit = 0; digit < 4; digit++) {
            if (!_isHexDigit(_body[_index++])) {
              throw const FormatException('Forge returned invalid JSON.');
            }
          }
        } else if (!'"\\/bfnrt'.contains(escaped)) {
          throw const FormatException('Forge returned invalid JSON.');
        }
        continue;
      }
      if (character.codeUnitAt(0) < 0x20) {
        throw const FormatException('Forge returned invalid JSON.');
      }
    }
    throw const FormatException('Forge returned invalid JSON.');
  }

  void _scanLiteral(String literal) {
    if (!_body.startsWith(literal, _index)) {
      throw const FormatException('Forge returned invalid JSON.');
    }
    _index += literal.length;
  }

  void _scanNumber() {
    final start = _index;
    if (_consume('-')) {
      if (_index >= _body.length) {
        throw const FormatException('Forge returned invalid JSON.');
      }
    }
    if (_consume('0')) {
      if (_index < _body.length && _isDigit(_body[_index])) {
        throw const FormatException('Forge returned invalid JSON.');
      }
    } else {
      if (_index >= _body.length || !_isNonZeroDigit(_body[_index])) {
        throw const FormatException('Forge returned invalid JSON.');
      }
      while (_index < _body.length && _isDigit(_body[_index])) {
        _index++;
      }
    }
    if (_consume('.')) {
      if (_index >= _body.length || !_isDigit(_body[_index])) {
        throw const FormatException('Forge returned invalid JSON.');
      }
      while (_index < _body.length && _isDigit(_body[_index])) {
        _index++;
      }
    }
    if (_index < _body.length &&
        (_body[_index] == 'e' || _body[_index] == 'E')) {
      _index++;
      if (_index < _body.length &&
          (_body[_index] == '+' || _body[_index] == '-')) {
        _index++;
      }
      if (_index >= _body.length || !_isDigit(_body[_index])) {
        throw const FormatException('Forge returned invalid JSON.');
      }
      while (_index < _body.length && _isDigit(_body[_index])) {
        _index++;
      }
    }
    if (_index == start) {
      throw const FormatException('Forge returned invalid JSON.');
    }
  }

  void _skipWhitespace() {
    while (_index < _body.length && _isForgeJsonWhitespace(_body[_index])) {
      _index++;
    }
  }

  void _expect(String character) {
    if (!_consume(character)) {
      throw const FormatException('Forge returned invalid JSON.');
    }
  }

  bool _consume(String character) {
    if (_index < _body.length && _body[_index] == character) {
      _index++;
      return true;
    }
    return false;
  }

  static bool _isDigit(String character) =>
      character.codeUnitAt(0) >= 0x30 && character.codeUnitAt(0) <= 0x39;

  static bool _isNonZeroDigit(String character) =>
      character.codeUnitAt(0) >= 0x31 && character.codeUnitAt(0) <= 0x39;

  static bool _isHexDigit(String character) {
    final code = character.codeUnitAt(0);
    return (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x46) ||
        (code >= 0x61 && code <= 0x66);
  }
}
