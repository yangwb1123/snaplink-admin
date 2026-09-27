import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_conversations_models.dart';
import 'package:sso_admin/api/forge_prompt_append_receipt.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';
import 'package:sso_admin/api/forge_scheduler_selection_preview.dart';
import 'package:sso_admin/api/forge_scheduler_selection_lease.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/session.dart';
import 'package:sso_admin/services/forge_change_cursor_store.dart';
import 'package:sso_admin/services/forge_run_timeline_cursor_store.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/services/forge_conversation_metadata_cache.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/services/forge_oauth_token_refresh.dart';
import 'package:sso_admin/services/product_api_origin.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/api/forge_session_placement.dart';
import 'package:sso_admin/api/forge_run_intent_observation.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_local_runner_preview.dart';
import 'package:sso_admin/api/forge_run_observed.dart';
import 'package:sso_admin/api/forge_run_receipt_observation_convergence.dart';
import 'package:sso_admin/api/forge_run_execution_evidence.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_vectors.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_history.dart';
import 'package:sso_admin/api/forge_session_runner_reconciliation_projection.dart';
import 'package:sso_admin/api/forge_execution_reconciliation_observation.dart';
import 'package:sso_admin/api/forge_device_enrollment_heartbeat_lifecycle_registry.dart';
import 'package:sso_admin/api/forge_device_credential_candidate.dart';
import 'package:sso_admin/api/forge_session_device_observation_wire.dart';
import 'package:sso_admin/api/forge_attempt_request_preview.dart';
import 'package:sso_admin/api/forge_pending_run_intent.dart';
import 'package:sso_admin/api/forge_runner_lease_fencing.dart';
import 'package:sso_admin/api/forge_execution_lease_checkpoint.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_client_instance_session_resource_convergence.dart';
import 'package:sso_admin/api/forge_preflight_fixture.dart';
import 'package:sso_admin/api/forge_run_attempt_lease_dispatch_preflight.dart';
import 'package:sso_admin/api/forge_runner_dispatch_plan_preview.dart';
import 'package:sso_admin/api/forge_runner_dispatch_admission.dart';
import 'package:sso_admin/api/forge_runner_transport_admission.dart';
import 'package:sso_admin/api/forge_runner_execution_boundary.dart';
import 'package:sso_admin/api/forge_runner_attempt_boundary.dart';

import 'forge_sessions_device_observation.dart';
import 'forge_device_inventory_panel.dart';
import 'forge_device_resource_summary_panel.dart';
import 'forge_device_inventory_v2_panel.dart';
import 'forge_device_inventory_placement_evaluation_v2_panel.dart';
import 'forge_device_inventory_placement_evaluation_panel.dart';
import 'forge_device_inventory_placement_batch_evaluation_panel.dart';
import 'forge_run_intent_observation_card.dart';
import 'forge_runner_execution_intent_card.dart';
import 'forge_run_observed_card.dart';
import 'forge_run_execution_evidence_card.dart';
import 'forge_session_runner_receipt_observation_card.dart';
import 'forge_session_runner_receipt_vectors_panel.dart';
import 'forge_session_runner_receipt_history_panel.dart';
import 'forge_session_runner_reconciliation_projection_panel.dart';
import 'forge_execution_reconciliation_observation_card.dart';
import 'forge_execution_consent_preview_card.dart';
import 'forge_attempt_request_preview_card.dart';
import 'forge_pending_run_intent_card.dart';
import 'forge_pending_run_intent_metadata_panel.dart';
import 'forge_pending_run_intent_submission_card.dart';
import 'forge_runner_lease_fencing_preview_card.dart';
import 'forge_execution_lease_checkpoint_preview_card.dart';
import 'forge_client_instance_session_view_panel.dart';
import 'forge_client_instance_resource_view_panel.dart';
import 'forge_lifecycle_registry_panel.dart';
import 'forge_device_credential_candidate_panel.dart';
import 'forge_device_registry_placement_preview_panel.dart';
import 'forge_scheduler_selection_preview_panel.dart';
import 'forge_scheduler_selection_lease_panel.dart';
import 'forge_scheduler_selection_lease_release_panel.dart';
import 'forge_local_runner_preview_card.dart';
import 'package:sso_admin/screens/agent/forge_runner_dispatch_plan_preview_card.dart';
import 'forge_runner_dispatch_admission_card.dart';
import 'forge_runner_transport_admission_card.dart';
import 'forge_runner_execution_boundary_card.dart';
import 'forge_runner_attempt_boundary_card.dart';
import 'package:sso_admin/screens/agent/forge_preflight_fixture_card.dart';
import '../../services/agent_workspace_file.dart';

part 'forge_sessions_screen_view.dart';
part 'forge_sessions_screen_helpers.dart';
part 'forge_runs_panel.dart';

class ForgeSessionsScreen extends StatefulWidget {
  final String accessToken;
  final String apiOrigin;

  /// Enables the explicitly opt-in owner-scoped SSE/long-poll change feed.
  /// The default Sessions construction stays on bounded polling.
  final bool enableConversationChangesStream;

  /// Maximum server wait for one opt-in change-stream request. The API
  /// transport remains bounded and validates the value before sending it.
  final int conversationChangesStreamWaitMS;

  /// Optional owner-scoped deep-link selection. The route never grants
  /// access; the authenticated detail read remains authoritative.
  final String? initialConversationID;

  /// Optional local client-instance selection hint. It is accepted only when
  /// an owner-bound display observation declares the instance; it never
  /// changes the authenticated Conversation request or grants authority.
  final String? initialClientInstanceID;
  final http.Client? httpClient;
  final http.Client? oauthHttpClient;
  final Duration oauthRevocationTimeout;
  final ForgeCredentialStore? credentialStore;

  /// Optional caller-supplied P3a observation. It is never fetched by this
  /// screen; matching Conversation/Run IDs are required before display.
  final ForgeSessionDeviceObservation? deviceObservation;

  /// Optional caller-supplied declaration to preview once through the
  /// authenticated P3a session route. No declaration is generated by the
  /// screen; Conversation/Run IDs must match the selected Run.
  final ForgeSessionPlacementRequest? deviceObservationRequest;

  /// Optional caller-supplied, pure prompt-to-Run observation. The screen
  /// renders it only for the selected Conversation/Run and only while all
  /// preview and authority fields remain display-only.
  final ForgeRunIntentObservation? runIntentObservation;

  /// Optional caller-supplied pure Prompt/Run to Runner binding. It is
  /// rendered only for the matching selected Run while every authority bit
  /// remains false.
  final ForgeRunnerExecutionIntentObservation? runnerExecutionIntentObservation;
  final ForgeRunnerExecutionIntentRequest? runnerExecutionIntentRequest;
  final ForgeRunnerExecutionIntentReader? runnerExecutionIntentReader;

  /// Optional local Runner execution-readiness observation. It is rendered
  /// through the existing metadata-only Runner intent card and never grants
  /// execution authority.
  final ForgeLocalRunnerPreviewObservation? localRunnerPreview;

  /// Explicit request and reader for the private local Runner execution
  /// readiness candidate. The default screen leaves both unset.
  final ForgeLocalRunnerPreviewRequest? localRunnerPreviewRequest;
  final ForgeLocalRunnerPreviewReader? localRunnerPreviewReader;

  /// Optional caller-supplied, content-free Run metadata observation. It is
  /// rendered only for the matching selected Conversation/Run after strict
  /// re-decoding; the opaque owner reference is never treated as identity.
  final ForgeRunObserved? runObserved;

  /// Optional caller-supplied reader for one content-free Run metadata
  /// observation. The screen invokes it only for the selected
  /// Conversation/Run, strictly re-decodes the result, and never derives an
  /// observer route or owner identity from the bearer token.
  final ForgeRunObservedReader? runObservedReader;

  /// Optional independent reader for the selected Run's content-free terminal
  /// receipt. It is consumed only together with [runObservedReader]; the two
  /// results must converge before either fetched projection is displayed.
  final ForgeSessionRunnerReceiptObservationReader?
  sessionRunnerReceiptObservationReader;

  /// Optional caller-supplied, content-free binding of one Run to one
  /// observed Runner receipt. It is rendered only for the selected
  /// Conversation/Run after strict parsing and while every authority bit
  /// remains false. The owner reference is a digest and is never converted
  /// into an owner identity by this screen.
  final ForgeRunExecutionEvidence? runExecutionEvidence;

  /// Optional reader for one authenticated Run/receipt evidence binding. The
  /// screen invokes it only for the selected Conversation/Run and re-decodes
  /// the result before display; leaving it unset keeps the default surface
  /// request-free.
  final ForgeRunExecutionEvidenceReader? runExecutionEvidenceReader;

  /// Optional caller-supplied session-bound terminal receipt observation. It
  /// remains process-local and is rendered only for the selected Run while
  /// every authority bit stays false.
  final ForgeSessionRunnerReceiptObservation? sessionRunnerReceiptObservation;

  /// Optional canonical completed/failed/uncertain receipt vectors. The
  /// vectors remain local display-only values and never create a request,
  /// persist a receipt, or grant execution authority.
  final ForgeSessionRunnerReceiptVectors? sessionRunnerReceiptVectorsPreview;
  final ForgeSessionRunnerReceiptVectorsFileReader?
  sessionRunnerReceiptVectorsFileReader;

  /// Optional bounded ordered receipt history. The history remains a local
  /// display-only value and is imported only through the explicit reader
  /// action; leaving both values unset keeps the default screen request-free.
  final ForgeSessionRunnerReceiptHistory? sessionRunnerReceiptHistoryPreview;
  final ForgeSessionRunnerReceiptHistoryFileReader?
  sessionRunnerReceiptHistoryFileReader;

  /// Optional caller-supplied manual reconciliation projection. It remains
  /// a local, display-only value and never retries or mutates a receipt.
  final ForgeSessionRunnerReconciliationProjection?
  sessionRunnerReconciliationProjectionPreview;
  final ForgeSessionRunnerReconciliationProjectionFileReader?
  sessionRunnerReconciliationProjectionFileReader;

  /// Explicit request and reader for the authenticated manual reconciliation
  /// projection candidate. Both values are required before this screen makes
  /// a POST; the default Web/App/Mobile surface remains request-free.
  final ForgeSessionRunnerReceiptHistory?
  sessionRunnerReconciliationProjectionRequest;
  final ForgeSessionRunnerReconciliationProjectionReader?
  sessionRunnerReconciliationProjectionReader;

  /// Explicit request and reader for the accepted EXECUTE history-reduction
  /// preview. The default screen leaves both unset and request-free.
  final ForgeSessionRunnerReceiptHistory? sessionRunnerReceiptHistoryRequest;
  final ForgeSessionRunnerReceiptHistoryReader?
  sessionRunnerReceiptHistoryReader;

  /// Optional caller-supplied restart-boundary reconciliation observation. It
  /// is rendered only for the selected Run after strict re-decoding; it never
  /// retries work, renews a lease, selects a target, or grants authority.
  final ForgeExecutionReconciliationObservation?
  executionReconciliationObservation;

  /// Optional caller-supplied restart image and reader for the authenticated
  /// execution-reconciliation candidate. Both values are required before
  /// this screen makes a request; the default screen remains request-free.
  final ForgeExecutionReconciliationInput? executionReconciliationInput;
  final ForgeExecutionReconciliationReader? executionReconciliationReader;

  /// Explicit owner and reader for the private, read-only execution-consent
  /// preview candidate. The selected Conversation ID is supplied by this
  /// screen; the default route leaves both values unset and request-free.
  final ForgeDeviceOwner? executionConsentPreviewOwner;
  final ForgeExecutionConsentPreviewReader? executionConsentPreviewReader;

  /// Optional caller-supplied offline Attempt request contract. It remains a
  /// display-only value and never creates a Run or dispatches a task.
  final ForgeAttemptRequestPreviewFixture? attemptRequestPreview;

  /// Optional local Runner Attempt lifecycle boundary observation. It is
  /// rendered only for the explicit owner and selected session scope below.
  final ForgeRunnerAttemptBoundaryObservation? runnerAttemptBoundaryPreview;
  final ForgeRunnerAttemptBoundaryScope? runnerAttemptBoundaryScope;
  final ForgeRunnerAttemptBoundaryFileReader? runnerAttemptBoundaryFileReader;

  /// Explicit request and reader for the authenticated, metadata-only Attempt
  /// boundary candidate. The default screen leaves both unset and request-free.
  final ForgeRunnerAttemptBoundaryPreviewRequest? runnerAttemptBoundaryRequest;
  final ForgeRunnerAttemptBoundaryReader? runnerAttemptBoundaryReader;

  /// Enables the explicit local Attempt boundary projection/import seam. The
  /// default screen keeps it disabled and request-free.
  final bool enableRunnerAttemptBoundaryProjection;

  /// Optional caller-supplied pending Run-intent receipt. It remains a
  /// metadata-only display value and never creates or dispatches a Run.
  final ForgePendingRunIntentFixture? pendingRunIntentPreview;

  /// Explicit submitter for the private candidate scheduling-review action.
  /// The default screen leaves it unset, so the action and POST route are
  /// absent from normal Web/App/Mobile construction.
  final ForgeDeviceOwner? pendingRunIntentOwner;
  final ForgePendingRunIntentSubmitter? pendingRunIntentSubmitter;

  /// Explicit owner and submitter for the content-free Prompt append receipt
  /// consumer. Supplying either value opts the screen into the receipt path;
  /// both are required before a Prompt can be sent through that path. The
  /// default Web/App/Mobile surface leaves both unset and keeps its ordinary
  /// append behavior unchanged.
  final ForgeDeviceOwner? promptAppendReceiptOwner;
  final ForgePromptAppendReceiptSubmitter? promptAppendReceiptSubmitter;

  /// When enabled, an explicit Prompt append waits for a fresh, converged
  /// owner-bound inventory/resource observation. If a client-instance
  /// session/resource pair is also configured, its resource image must match
  /// the inventory/resource pair before the append is enabled.
  final bool requireDeviceInventoryResourceConvergenceForPromptAppend;

  /// Explicit owner and reader for the private, authenticated inventory
  /// candidate. Both values are required before this screen makes a request;
  /// the default route therefore remains free of `/devices` traffic.
  ///
  /// The owner must come from a verified caller-owned source. The screen never
  /// derives it from the bearer token, and the reader must keep the candidate
  /// disabled until ADR-0114/P3b is accepted.
  final ForgeDeviceOwner? deviceInventoryOwner;
  final ForgeDeviceInventoryCandidateReader? deviceInventoryReader;

  /// Optional, explicitly injected owner-bound lossless v2 inventory reader.
  /// The default screen leaves it unset, so no v2 device request is made.
  final ForgeDeviceInventoryV2Reader? deviceInventoryV2Reader;

  /// Optional explicit paired v2 inventory/resource reader. The default
  /// screen leaves it unset and therefore does not issue either candidate
  /// GET as a convergence pair.
  final ForgeDeviceOwner? deviceInventoryResourceConvergenceOwner;
  final ForgeDeviceInventoryResourceConvergenceReader?
  deviceInventoryResourceConvergenceReader;

  /// Optional explicit requirements and reader for the authenticated
  /// registry-backed placement-preview candidate. The default screen leaves
  /// both unset and therefore does not issue a POST.
  final ForgeDevicePlacementRequirements?
  deviceInventoryRegistryPlacementRequirements;
  final ForgeDeviceRegistryPlacementPreviewReader?
  deviceInventoryRegistryPlacementPreviewReader;

  /// Optional caller-supplied scheduler-selection preview. It is displayed
  /// only for its bound Conversation/Run/Attempt and never creates a lease.
  final ForgeSchedulerSelectionPreview? schedulerSelectionPreview;

  /// Explicit request and reader for the planning-only scheduler-preview
  /// candidate. Both values are required before this screen makes a POST;
  /// the default Web/App/Mobile route remains request-free.
  final ForgeSchedulerSelectionPreviewRequest? schedulerSelectionPreviewRequest;
  final ForgeSchedulerSelectionPreviewReader? schedulerSelectionPreviewReader;

  /// Optional explicit scheduler-lease request and reader. The reader is
  /// reached only when the caller opts into the effectful candidate.
  final ForgeSchedulerSelectionLease? schedulerSelectionLease;
  final ForgeSchedulerSelectionLeaseRequest? schedulerSelectionLeaseRequest;
  final ForgeSchedulerSelectionLeaseReader? schedulerSelectionLeaseReader;
  final String? schedulerSelectionLeaseIdempotencyKey;

  /// Optional explicit scheduler-lease renewal request and reader. The
  /// renewal candidate stays request-free until the caller supplies all four
  /// values, including a fresh idempotency key.
  final ForgeSchedulerSelectionLeaseRenewalRequest?
  schedulerSelectionLeaseRenewalRequest;
  final ForgeSchedulerSelectionLeaseRenewalReader?
  schedulerSelectionLeaseRenewalReader;
  final String? schedulerSelectionLeaseRenewalIdempotencyKey;

  /// Optional explicit scheduler-lease release request and reader. Release
  /// marks the durable reservation inactive while preserving its epoch.
  final ForgeSchedulerSelectionLeaseRelease? schedulerSelectionLeaseRelease;
  final ForgeSchedulerSelectionLeaseReleaseRequest?
  schedulerSelectionLeaseReleaseRequest;
  final ForgeSchedulerSelectionLeaseReleaseReader?
  schedulerSelectionLeaseReleaseReader;
  final String? schedulerSelectionLeaseReleaseIdempotencyKey;

  /// Optional, caller-supplied v2 persisted inventory observation. It is
  /// rendered as a local read-only preview and never causes a device request.
  final ForgeDeviceInventoryPageV2? deviceInventoryV2Preview;

  /// Optional bounded JSON reader for the local v2 inventory preview. The
  /// default screen uses the platform workspace picker; a supplied reader is
  /// still process-local and never opens an inventory route.
  final ForgeDeviceInventoryV2FileReader? deviceInventoryV2FileReader;

  /// Optional, caller-supplied complete multi-instance resource summary. It
  /// is rendered as a local read-only preview and never causes a device or
  /// placement request.
  final ForgeDeviceResourceSummaryFixture? deviceResourceSummaryPreview;

  /// Optional bounded JSON reader for the local multi-instance resource
  /// summary. The default screen uses the platform workspace picker; the
  /// reader remains request-free and carries no target-selection authority.
  final ForgeDeviceResourceSummaryFileReader? deviceResourceSummaryFileReader;

  /// Optional, caller-supplied v2 placement comparison. It is rendered as a
  /// local read-only preview and never causes a device request or selects a
  /// target.
  final ForgeDeviceInventoryPlacementEvaluationV2?
  deviceInventoryPlacementEvaluationV2Preview;

  /// Optional bounded JSON reader for the local v2 placement comparison. The
  /// default screen uses the platform workspace picker; the value remains a
  /// request-free, unverified comparison with no target-selection authority.
  final ForgeDeviceInventoryPlacementEvaluationV2FileReader?
  deviceInventoryPlacementEvaluationV2FileReader;

  /// Optional, caller-supplied persisted-inventory placement evaluation. It
  /// is rendered as a local read-only preview and never selects a target.
  final ForgeDeviceInventoryPlacementEvaluationFixture?
  deviceInventoryPlacementEvaluationPreview;

  /// Optional bounded JSON reader for the local placement evaluation preview.
  /// A supplied reader remains request-free and process-local.
  final ForgeDeviceInventoryPlacementEvaluationFileReader?
  deviceInventoryPlacementEvaluationFileReader;

  /// Optional, caller-supplied persisted-inventory placement batch
  /// comparison. It is rendered as a local read-only preview and never
  /// selects a target or issues a device request.
  final ForgeDeviceInventoryPlacementBatchEvaluationFixture?
  deviceInventoryPlacementBatchEvaluationPreview;

  /// Optional bounded JSON reader for the local persisted-inventory placement
  /// batch preview. It remains request-free and never selects a target.
  final ForgeDeviceInventoryPlacementBatchEvaluationFileReader?
  deviceInventoryPlacementBatchEvaluationFileReader;

  /// Explicit reader for the private, owner-scoped pending Run-intent
  /// metadata candidate. The callback is optional and the default route never
  /// requests `/run-intents`; it also never exposes Prompt content or any
  /// execution action.
  final ForgePendingRunIntentReader? pendingRunIntentReader;

  /// Optional paged reader for the private pending Run-intent candidate. The
  /// first call receives a null cursor and later calls receive the validated
  /// cursor from the previous page. The default route remains request-free.
  final ForgePendingRunIntentPageReader? pendingRunIntentPageReader;

  /// Explicit reader for one payload-free pending Run-intent timeline. The
  /// callback is invoked only after the owner expands a receipt; the default
  /// route never requests the timeline endpoint or exposes execution action.
  final ForgePendingRunIntentTimelineReader? pendingRunIntentTimelineReader;

  /// Optional initial local Runner lease/fencing fixture. It is rendered only
  /// as metadata and never creates a lease, selects a target, or dispatches a
  /// command.
  final ForgeRunnerLeaseFencingFixture? runnerLeaseFencingPreview;

  /// Optional bounded JSON reader for the local Runner lease/fencing preview.
  /// The default screen uses the platform workspace file picker; callers can
  /// inject a reader for Web/App/Mobile tests without opening any API route.
  final ForgeRunnerLeaseFencingFileReader? runnerLeaseFencingFileReader;

  /// Optional local execution-lease restart image. It is strictly re-decoded
  /// before display and never restores a lease or grants execution authority.
  final ForgeExecutionLeaseCheckpointFixture? executionLeaseCheckpointPreview;

  /// Optional bounded JSON reader for the local execution-lease checkpoint
  /// preview. The default screen uses the platform workspace file picker.
  final ForgeExecutionLeaseCheckpointFileReader?
  executionLeaseCheckpointFileReader;

  /// Optional local client-instance/session metadata. It is strictly
  /// re-decoded before display and never creates a request or authority.
  final ForgeClientInstanceSessionView? clientInstanceSessionViewPreview;

  /// Optional bounded JSON reader for the local client-instance/session
  /// observation. The default screen uses the platform workspace picker; the
  /// reader remains process-local and cannot grant Prompt or execution
  /// authority.
  final ForgeClientInstanceSessionViewFileReader?
  clientInstanceSessionViewFileReader;

  /// Optional local client-instance/resource metadata. It is strictly
  /// re-decoded before display and never creates a request or authority.
  final ForgeClientInstanceResourceView? clientInstanceResourceViewPreview;

  /// Optional bounded JSON reader for the local client-instance/resource
  /// observation. The default screen uses the platform workspace picker; the
  /// reader remains process-local and cannot grant scheduling authority.
  final ForgeClientInstanceResourceViewFileReader?
  clientInstanceResourceViewFileReader;

  /// Explicit owner and reader for the private client-instance/resource-view
  /// candidate. Both values are required before this screen makes a request;
  /// the default screen leaves them unset.
  final ForgeDeviceOwner? clientInstanceResourceViewOwner;
  final ForgeClientInstanceResourceViewReader? clientInstanceResourceViewReader;

  /// Optional local Run → Attempt → lease dispatch preflight. It is strictly
  /// re-decoded before display and never creates a request or dispatches work.
  final ForgePreflightFixture? runAttemptLeaseDispatchPreflightPreview;

  /// Explicitly injected request and reader for the private, stateless
  /// Run → Attempt → lease dispatch preflight candidate. Both values are
  /// required before this screen makes a request; the default screen leaves
  /// them unset, so no preflight route is contacted.
  final ForgeRunAttemptLeaseDispatchPreflightRequest?
  runAttemptLeaseDispatchPreflightRequest;
  final ForgeRunAttemptLeaseDispatchPreflightReader?
  runAttemptLeaseDispatchPreflightReader;

  /// Optional local Runner dispatch-plan comparison. It is strictly
  /// re-decoded before display and never selects, reserves, authorizes, or
  /// dispatches a target.
  final ForgeRunnerDispatchPlanPreview? runnerDispatchPlanPreview;

  /// Explicitly injected request and reader for the private Runner
  /// dispatch-plan comparison candidate. Both are required before this
  /// screen makes a request; the default screen remains request-free.
  final ForgeRunAttemptLeaseDispatchPreflightRequest?
  runnerDispatchPlanPreviewRequest;
  final ForgeRunnerDispatchPlanPreviewReader? runnerDispatchPlanPreviewReader;

  /// Optional lease-to-Runner admission recheck. It is metadata-only and
  /// never authorizes or dispatches a command.
  final ForgeRunnerDispatchAdmission? runnerDispatchAdmission;

  /// Explicit request and reader for the owner-authenticated admission
  /// candidate. The default screen leaves both unset and request-free.
  final ForgeRunnerDispatchAdmissionRequest? runnerDispatchAdmissionRequest;
  final ForgeRunnerDispatchAdmissionReader? runnerDispatchAdmissionReader;

  /// Optional lease-bound Runner transport admission preview. It is strictly
  /// metadata-only and never opens a Runner connection or sends a payload.
  final ForgeRunnerTransportAdmission? runnerTransportAdmission;

  /// Explicit request and reader for the owner-authenticated transport
  /// admission candidate. The default screen leaves both unset and
  /// request-free.
  final ForgeRunnerTransportAdmissionRequest? runnerTransportAdmissionRequest;
  final ForgeRunnerTransportAdmissionReader? runnerTransportAdmissionReader;

  /// Optional server-owned Runner execution-boundary preview. It is strictly
  /// display-only and never opens a Runner connection.
  final ForgeRunnerExecutionBoundaryObservation? runnerExecutionBoundary;
  final ForgeRunnerExecutionBoundaryPreviewRequest?
  runnerExecutionBoundaryRequest;
  final ForgeRunnerExecutionBoundaryReader? runnerExecutionBoundaryReader;

  /// Explicit owner and reader for the private client-instance/session-view
  /// candidate. Both values are required before this screen makes a request;
  /// the default screen leaves them unset.
  final ForgeDeviceOwner? clientInstanceSessionViewOwner;
  final ForgeClientInstanceSessionViewReader? clientInstanceSessionViewReader;

  /// Explicit owner and reader for the paired client-instance session and
  /// resource observations. When supplied, the screen consumes both views
  /// from one validated read pair before rendering the existing cards.
  final ForgeDeviceOwner? clientInstanceSessionResourceConvergenceOwner;
  final ForgeClientInstanceSessionResourceConvergenceReader?
  clientInstanceSessionResourceConvergenceReader;

  /// Explicit owner and reader for the private lifecycle-registry GET
  /// candidate. Both values are required before this screen makes a request;
  /// the default screen remains request-free.
  final ForgeDeviceOwner? lifecycleRegistryOwner;
  final ForgeLifecycleRegistryReader? lifecycleRegistryReader;

  /// Explicit owner, metadata request, and reader for the private credential
  /// lifecycle candidate. The default screen leaves these unset and therefore
  /// never posts to the candidate route.
  final ForgeDeviceOwner? deviceCredentialCandidateOwner;
  final ForgeDeviceCredentialLifecycleRequest? deviceCredentialCandidateRequest;
  final ForgeDeviceCredentialLifecycleCandidateReader?
  deviceCredentialCandidateReader;

  const ForgeSessionsScreen({
    super.key,
    required this.accessToken,
    required this.apiOrigin,
    this.enableConversationChangesStream = false,
    this.conversationChangesStreamWaitMS = 15000,
    this.initialConversationID,
    this.initialClientInstanceID,
    this.httpClient,
    this.oauthHttpClient,
    this.oauthRevocationTimeout = const Duration(seconds: 5),
    this.credentialStore,
    this.deviceObservation,
    this.deviceObservationRequest,
    this.runIntentObservation,
    this.runnerExecutionIntentObservation,
    this.runnerExecutionIntentRequest,
    this.runnerExecutionIntentReader,
    this.localRunnerPreview,
    this.localRunnerPreviewRequest,
    this.localRunnerPreviewReader,
    this.runObserved,
    this.runObservedReader,
    this.sessionRunnerReceiptObservationReader,
    this.runExecutionEvidence,
    this.runExecutionEvidenceReader,
    this.sessionRunnerReceiptObservation,
    this.sessionRunnerReceiptVectorsPreview,
    this.sessionRunnerReceiptVectorsFileReader,
    this.sessionRunnerReceiptHistoryPreview,
    this.sessionRunnerReceiptHistoryFileReader,
    this.sessionRunnerReconciliationProjectionPreview,
    this.sessionRunnerReconciliationProjectionFileReader,
    this.sessionRunnerReconciliationProjectionRequest,
    this.sessionRunnerReconciliationProjectionReader,
    this.sessionRunnerReceiptHistoryRequest,
    this.sessionRunnerReceiptHistoryReader,
    this.executionReconciliationObservation,
    this.executionReconciliationInput,
    this.executionReconciliationReader,
    this.executionConsentPreviewOwner,
    this.executionConsentPreviewReader,
    this.attemptRequestPreview,
    this.runnerAttemptBoundaryPreview,
    this.runnerAttemptBoundaryScope,
    this.runnerAttemptBoundaryFileReader,
    this.runnerAttemptBoundaryRequest,
    this.runnerAttemptBoundaryReader,
    this.enableRunnerAttemptBoundaryProjection = false,
    this.pendingRunIntentPreview,
    this.pendingRunIntentOwner,
    this.pendingRunIntentSubmitter,
    this.promptAppendReceiptOwner,
    this.promptAppendReceiptSubmitter,
    this.requireDeviceInventoryResourceConvergenceForPromptAppend = false,
    this.deviceInventoryOwner,
    this.deviceInventoryReader,
    this.deviceInventoryV2Reader,
    this.deviceInventoryResourceConvergenceOwner,
    this.deviceInventoryResourceConvergenceReader,
    this.deviceInventoryRegistryPlacementRequirements,
    this.deviceInventoryRegistryPlacementPreviewReader,
    this.schedulerSelectionPreview,
    this.schedulerSelectionPreviewRequest,
    this.schedulerSelectionPreviewReader,
    this.schedulerSelectionLease,
    this.schedulerSelectionLeaseRequest,
    this.schedulerSelectionLeaseReader,
    this.schedulerSelectionLeaseIdempotencyKey,
    this.schedulerSelectionLeaseRenewalRequest,
    this.schedulerSelectionLeaseRenewalReader,
    this.schedulerSelectionLeaseRenewalIdempotencyKey,
    this.schedulerSelectionLeaseRelease,
    this.schedulerSelectionLeaseReleaseRequest,
    this.schedulerSelectionLeaseReleaseReader,
    this.schedulerSelectionLeaseReleaseIdempotencyKey,
    this.deviceInventoryV2Preview,
    this.deviceInventoryV2FileReader,
    this.deviceResourceSummaryPreview,
    this.deviceResourceSummaryFileReader,
    this.deviceInventoryPlacementEvaluationV2Preview,
    this.deviceInventoryPlacementEvaluationV2FileReader,
    this.deviceInventoryPlacementEvaluationPreview,
    this.deviceInventoryPlacementEvaluationFileReader,
    this.deviceInventoryPlacementBatchEvaluationPreview,
    this.deviceInventoryPlacementBatchEvaluationFileReader,
    this.pendingRunIntentReader,
    this.pendingRunIntentPageReader,
    this.pendingRunIntentTimelineReader,
    this.runnerLeaseFencingPreview,
    this.runnerLeaseFencingFileReader,
    this.executionLeaseCheckpointPreview,
    this.executionLeaseCheckpointFileReader,
    this.clientInstanceSessionViewPreview,
    this.clientInstanceSessionViewFileReader,
    this.clientInstanceResourceViewPreview,
    this.clientInstanceResourceViewFileReader,
    this.clientInstanceResourceViewOwner,
    this.clientInstanceResourceViewReader,
    this.clientInstanceSessionViewOwner,
    this.clientInstanceSessionViewReader,
    this.clientInstanceSessionResourceConvergenceOwner,
    this.clientInstanceSessionResourceConvergenceReader,
    this.lifecycleRegistryOwner,
    this.lifecycleRegistryReader,
    this.deviceCredentialCandidateOwner,
    this.deviceCredentialCandidateRequest,
    this.deviceCredentialCandidateReader,
    this.runAttemptLeaseDispatchPreflightPreview,
    this.runAttemptLeaseDispatchPreflightRequest,
    this.runAttemptLeaseDispatchPreflightReader,
    this.runnerDispatchPlanPreview,
    this.runnerDispatchPlanPreviewRequest,
    this.runnerDispatchPlanPreviewReader,
    this.runnerDispatchAdmission,
    this.runnerDispatchAdmissionRequest,
    this.runnerDispatchAdmissionReader,
    this.runnerTransportAdmission,
    this.runnerTransportAdmissionRequest,
    this.runnerTransportAdmissionReader,
    this.runnerExecutionBoundary,
    this.runnerExecutionBoundaryRequest,
    this.runnerExecutionBoundaryReader,
  });

  @override
  State<ForgeSessionsScreen> createState() => _ForgeSessionsScreenState();
}

class _PendingRunIntentRequest {
  final String content;
  final int expectedVersion;
  final String idempotencyKey;

  const _PendingRunIntentRequest({
    required this.content,
    required this.expectedVersion,
    required this.idempotencyKey,
  });
}

enum _ForgeChangeSyncOutcome {
  skipped,
  failed,
  unchanged,
  changed,
  advancedHidden,
}

enum _ForgeChangePollOutcome { skipped, failed, succeeded }

class _ForgeSessionsScreenState extends State<ForgeSessionsScreen>
    with WidgetsBindingObserver {
  static const _changePollBaseDelay = Duration(seconds: 15);
  static const _changePollMaxDelay = Duration(minutes: 2);
  static const _changePollMaxFailureStreak = 3;
  static const _changeStreamReconnectDelay = Duration(milliseconds: 50);

  late final ForgeConversationsApi _api;
  late final ForgeOAuthTokenRefresh _tokenRefresh;
  late final ForgeCredentialStore _credentialStore =
      widget.credentialStore ?? ForgeCredentialStore();
  late final ForgeConversationMetadataCache _conversationMetadataCache =
      ForgeConversationMetadataCache(
        accessToken: widget.accessToken,
        apiOrigin: widget.apiOrigin,
        clientId: ForgeConversationsOAuth.clientId,
        resource: ForgeConversationsOAuth.resource,
      );
  late final ForgeChangeCursorStore _changeCursorStore;
  late final Future<void> _cursorReady;
  final _titleController = TextEditingController();
  final _scopeIDController = TextEditingController();
  final _promptController = TextEditingController();
  List<ForgeOwnedConversation> _conversations = const [];
  List<ForgeConversationPrompt> _prompts = const [];
  List<ForgeConversationRun> _runs = const [];
  List<ForgeRunTimelineEvent> _runEvents = const [];
  ForgeOwnedConversation? _selected;
  ForgeConversationRun? _selectedRun;
  ForgePromptCursor? _promptCursor;
  ForgeRunCursor? _runCursor;
  String? _nextAfterID;
  String _scopeKind = 'global';
  String? _conversationError;
  bool _conversationsStale = false;
  String? _promptError;
  String? _createError;
  String? _appendError;
  String? _changeError;
  String? _runError;
  String? _runTimelineError;
  ForgeSessionDeviceObservation? _fetchedDeviceObservation;
  ForgeSessionDeviceObservation? _importedDeviceObservation;
  ForgeRunnerExecutionIntentObservation?
  _importedRunnerExecutionIntentObservation;
  ForgeLocalRunnerPreviewObservation? _fetchedLocalRunnerPreview;
  String? _localRunnerPreviewError;
  bool _localRunnerPreviewStale = false;
  bool _loadingLocalRunnerPreview = false;
  int _localRunnerPreviewGeneration = 0;
  ForgeSessionRunnerReceiptObservation?
  _importedSessionRunnerReceiptObservation;
  ForgeSessionRunnerReceiptVectors? _sessionRunnerReceiptVectorsPreview;
  String? _sessionRunnerReceiptVectorsPreviewError;
  bool _loadingSessionRunnerReceiptVectorsPreview = false;
  ForgeSessionRunnerReceiptHistory? _sessionRunnerReceiptHistoryPreview;
  String? _sessionRunnerReceiptHistoryPreviewError;
  bool _loadingSessionRunnerReceiptHistoryPreview = false;
  ForgeSessionRunnerReconciliationProjection?
  _sessionRunnerReconciliationProjectionPreview;
  String? _sessionRunnerReconciliationProjectionPreviewError;
  bool _loadingSessionRunnerReconciliationProjectionPreview = false;
  ForgeSessionRunnerReconciliationProjection?
  _fetchedSessionRunnerReconciliationProjection;
  String? _sessionRunnerReconciliationProjectionError;
  bool _sessionRunnerReconciliationProjectionStale = false;
  bool _loadingSessionRunnerReconciliationProjection = false;
  int _sessionRunnerReconciliationProjectionGeneration = 0;
  ForgeSessionRunnerReceiptHistory? _fetchedSessionRunnerReceiptHistory;
  String? _sessionRunnerReceiptHistoryError;
  bool _sessionRunnerReceiptHistoryStale = false;
  bool _loadingSessionRunnerReceiptHistory = false;
  int _sessionRunnerReceiptHistoryGeneration = 0;
  String? _deviceObservationError;
  String? _deviceObservationKey;
  bool _loadingDeviceObservation = false;
  int _deviceObservationGeneration = 0;
  ForgeRunObserved? _fetchedRunObserved;
  ForgeSessionRunnerReceiptObservation? _fetchedSessionRunnerReceiptObservation;
  String? _runObservedError;
  bool _runObservedStale = false;
  bool _loadingRunObserved = false;
  int _runObservedGeneration = 0;
  ForgeRunExecutionEvidence? _fetchedRunExecutionEvidence;
  String? _runExecutionEvidenceError;
  bool _runExecutionEvidenceStale = false;
  bool _loadingRunExecutionEvidence = false;
  int _runExecutionEvidenceGeneration = 0;
  ForgeDeviceInventoryPage? _fetchedDeviceInventory;
  String? _deviceInventoryError;
  bool _deviceInventoryStale = false;
  bool _loadingDeviceInventory = false;
  int _deviceInventoryGeneration = 0;
  ForgeDeviceInventoryPageV2? _fetchedDeviceInventoryV2;
  String? _deviceInventoryV2Error;
  bool _deviceInventoryV2Stale = false;
  bool _loadingDeviceInventoryV2 = false;
  int _deviceInventoryV2Generation = 0;
  Future<void>? _deviceInventoryV2Refresh;
  bool _deviceInventoryV2RefreshWasForced = false;
  ForgeDeviceInventoryResourceConvergence?
  _fetchedDeviceInventoryResourceConvergence;
  String? _deviceInventoryResourceConvergenceError;
  bool _deviceInventoryResourceConvergenceStale = false;
  bool _loadingDeviceInventoryResourceConvergence = false;
  int _deviceInventoryResourceConvergenceGeneration = 0;
  ForgeDeviceInventoryPageV2? _deviceInventoryV2Preview;
  String? _deviceInventoryV2PreviewError;
  bool _loadingDeviceInventoryV2Preview = false;
  ForgeDeviceResourceSummaryFixture? _deviceResourceSummaryPreview;
  String? _deviceResourceSummaryPreviewError;
  bool _loadingDeviceResourceSummaryPreview = false;
  ForgeDeviceInventoryPlacementEvaluationV2?
  _deviceInventoryPlacementEvaluationV2Preview;
  String? _deviceInventoryPlacementEvaluationV2PreviewError;
  bool _loadingDeviceInventoryPlacementEvaluationV2Preview = false;
  ForgeDeviceInventoryPlacementEvaluationFixture?
  _deviceInventoryPlacementEvaluationPreview;
  String? _deviceInventoryPlacementEvaluationPreviewError;
  bool _loadingDeviceInventoryPlacementEvaluationPreview = false;
  ForgeDeviceInventoryPlacementBatchEvaluationFixture?
  _deviceInventoryPlacementBatchEvaluationPreview;
  String? _deviceInventoryPlacementBatchEvaluationPreviewError;
  bool _loadingDeviceInventoryPlacementBatchEvaluationPreview = false;
  ForgeDeviceRegistryPlacementPreview?
  _fetchedDeviceInventoryRegistryPlacementPreview;
  String? _deviceInventoryRegistryPlacementPreviewError;
  bool _deviceInventoryRegistryPlacementPreviewStale = false;
  bool _loadingDeviceInventoryRegistryPlacementPreview = false;
  int _deviceInventoryRegistryPlacementPreviewGeneration = 0;
  ForgeSchedulerSelectionPreview? _fetchedSchedulerSelectionPreview;
  String? _schedulerSelectionPreviewError;
  bool _schedulerSelectionPreviewStale = false;
  bool _loadingSchedulerSelectionPreview = false;
  int _schedulerSelectionPreviewGeneration = 0;
  ForgeSchedulerSelectionLease? _fetchedSchedulerSelectionLease;
  String? _schedulerSelectionLeaseError;
  bool _schedulerSelectionLeaseStale = false;
  bool _loadingSchedulerSelectionLease = false;
  int _schedulerSelectionLeaseGeneration = 0;
  ForgeSchedulerSelectionLeaseRelease? _fetchedSchedulerSelectionLeaseRelease;
  String? _schedulerSelectionLeaseReleaseError;
  bool _schedulerSelectionLeaseReleaseStale = false;
  bool _loadingSchedulerSelectionLeaseRelease = false;
  int _schedulerSelectionLeaseReleaseGeneration = 0;
  ForgeClientInstanceResourceView? _fetchedClientInstanceResourceView;
  String? _clientInstanceResourceViewError;
  bool _clientInstanceResourceViewStale = false;
  bool _loadingClientInstanceResourceView = false;
  int _clientInstanceResourceViewGeneration = 0;
  Future<void>? _clientInstanceResourceViewRefresh;
  bool _clientInstanceResourceViewRefreshWasForced = false;
  ForgeClientInstanceResourceView? _clientInstanceResourceViewPreview;
  String? _clientInstanceResourceViewPreviewError;
  bool _loadingClientInstanceResourceViewPreview = false;
  ForgeClientInstanceSessionView? _fetchedClientInstanceSessionView;
  String? _clientInstanceSessionViewError;
  bool _clientInstanceSessionViewStale = false;
  bool _loadingClientInstanceSessionView = false;
  int _clientInstanceSessionViewGeneration = 0;
  ForgeClientInstanceSessionView? _clientInstanceSessionViewPreview;
  String? _clientInstanceSessionViewPreviewError;
  bool _loadingClientInstanceSessionViewPreview = false;
  ForgeClientInstanceSessionResourceConvergence?
  _fetchedClientInstanceSessionResourceConvergence;
  String? _clientInstanceSessionResourceConvergenceError;
  bool _clientInstanceSessionResourceConvergenceStale = false;
  bool _loadingClientInstanceSessionResourceConvergence = false;
  int _clientInstanceSessionResourceConvergenceGeneration = 0;
  ForgeDeviceEnrollmentHeartbeatLifecycleRegistry? _fetchedLifecycleRegistry;
  String? _lifecycleRegistryError;
  bool _lifecycleRegistryStale = false;
  bool _loadingLifecycleRegistry = false;
  int _lifecycleRegistryGeneration = 0;
  ForgeDeviceCredentialLifecycleCandidate? _fetchedDeviceCredentialCandidate;
  String? _deviceCredentialCandidateError;
  bool _deviceCredentialCandidateStale = false;
  bool _loadingDeviceCredentialCandidate = false;
  int _deviceCredentialCandidateGeneration = 0;
  ForgeExecutionReconciliationObservation?
  _fetchedExecutionReconciliationObservation;
  String? _executionReconciliationError;
  bool _executionReconciliationStale = false;
  bool _loadingExecutionReconciliation = false;
  int _executionReconciliationGeneration = 0;
  ForgeExecutionConsentPreview? _fetchedExecutionConsentPreview;
  String? _executionConsentPreviewError;
  bool _executionConsentPreviewStale = false;
  bool _loadingExecutionConsentPreview = false;
  int _executionConsentPreviewGeneration = 0;
  // This is a process-local display filter over the owner-scoped Conversation
  // page.  The instance/session envelope is explicitly unverified, so the
  // filter never changes the authenticated request, Prompt write, or session
  // authority.  Keeping the selection here (rather than in the API client)
  // also makes the default Gate/request-free path unchanged.
  String? _selectedClientInstanceID;
  bool _clientInstanceFilterNeedsPrivateReload = false;
  // Guards an in-flight owner conversation refresh from restoring the
  // selection that was active before a local client-instance filter changed.
  // The filter is a local projection boundary, so a late page must not widen
  // the visible list or reselect a conversation outside the chosen instance.
  int _clientInstanceFilterGeneration = 0;
  ForgePreflightFixture? _fetchedRunAttemptLeaseDispatchPreflight;
  String? _runAttemptLeaseDispatchPreflightError;
  bool _runAttemptLeaseDispatchPreflightStale = false;
  bool _loadingRunAttemptLeaseDispatchPreflight = false;
  int _runAttemptLeaseDispatchPreflightGeneration = 0;
  ForgeRunnerDispatchPlanPreview? _fetchedRunnerDispatchPlanPreview;
  String? _runnerDispatchPlanPreviewError;
  bool _runnerDispatchPlanPreviewStale = false;
  bool _loadingRunnerDispatchPlanPreview = false;
  int _runnerDispatchPlanPreviewGeneration = 0;
  ForgeRunnerExecutionIntentObservation? _fetchedRunnerExecutionIntent;
  String? _runnerExecutionIntentError;
  bool _runnerExecutionIntentStale = false;
  bool _loadingRunnerExecutionIntent = false;
  int _runnerExecutionIntentGeneration = 0;
  ForgeRunnerDispatchAdmission? _fetchedRunnerDispatchAdmission;
  String? _runnerDispatchAdmissionError;
  bool _runnerDispatchAdmissionStale = false;
  bool _loadingRunnerDispatchAdmission = false;
  int _runnerDispatchAdmissionGeneration = 0;
  ForgeRunnerTransportAdmission? _fetchedRunnerTransportAdmission;
  String? _runnerTransportAdmissionError;
  bool _runnerTransportAdmissionStale = false;
  bool _loadingRunnerTransportAdmission = false;
  int _runnerTransportAdmissionGeneration = 0;
  ForgeRunnerExecutionBoundaryObservation? _fetchedRunnerExecutionBoundary;
  String? _runnerExecutionBoundaryError;
  bool _runnerExecutionBoundaryStale = false;
  bool _loadingRunnerExecutionBoundary = false;
  int _runnerExecutionBoundaryGeneration = 0;
  ForgePendingRunIntentListPage? _fetchedPendingRunIntents;
  String? _pendingRunIntentError;
  bool _loadingPendingRunIntents = false;
  bool _loadingMorePendingRunIntents = false;
  int _pendingRunIntentGeneration = 0;
  final Map<String, ForgePendingRunIntentTimelinePage>
  _fetchedPendingRunIntentTimelines = {};
  final Map<String, String> _pendingRunIntentTimelineErrors = {};
  final Set<String> _loadingPendingRunIntentTimelines = {};
  int _pendingRunIntentTimelineGeneration = 0;
  ForgeRunnerLeaseFencingFixture? _runnerLeaseFencingPreview;
  String? _runnerLeaseFencingError;
  bool _loadingRunnerLeaseFencing = false;
  ForgeExecutionLeaseCheckpointFixture? _executionLeaseCheckpointPreview;
  String? _executionLeaseCheckpointError;
  bool _loadingExecutionLeaseCheckpoint = false;
  ForgeRunnerAttemptBoundaryObservation? _runnerAttemptBoundaryPreview;
  String? _runnerAttemptBoundaryPreviewError;
  bool _loadingRunnerAttemptBoundaryPreview = false;
  ForgeRunnerAttemptBoundaryObservation? _fetchedRunnerAttemptBoundary;
  String? _runnerAttemptBoundaryError;
  bool _runnerAttemptBoundaryStale = false;
  bool _loadingRunnerAttemptBoundary = false;
  int _runnerAttemptBoundaryGeneration = 0;
  String? _signOutError;
  _PendingCreate? _pendingCreate;
  _PendingPrompt? _pendingPrompt;
  bool _loadingConversations = false;
  bool _loadingPrompts = false;
  bool _creating = false;
  bool _appending = false;
  bool _submittingPendingRunIntent = false;
  bool _hasMoreConversations = false;
  bool _hasMorePrompts = false;
  bool _loadingRuns = false;
  bool _loadingRunTimeline = false;
  bool _hasMoreRuns = false;
  bool _hasMoreRunEvents = false;
  int _changeCursor = 0;
  bool _syncingChanges = false;
  int _conversationGeneration = 0;
  bool _signingOut = false;
  Timer? _changeSyncTimer;
  Timer? _changeStreamReconnectTimer;
  Duration _changePollDelay = _changePollBaseDelay;
  int _changePollFailureStreak = 0;
  bool _changeSyncEnabled = false;
  bool _changePollInFlight = false;
  bool _changeStreamInFlight = false;
  bool _changeStreamFallbackToPolling = false;
  bool _initialLoadComplete = false;
  int _changeStreamGeneration = 0;
  bool _refreshingOnResume = false;
  // Once sign-out starts, keep owner-scoped state out of the widget tree while
  // revocation and secure-store cleanup finish.  The route may remain mounted
  // for several seconds when a provider is slow or unavailable.
  bool _sessionViewInvalidated = false;
  // An authorization rejection invalidates the current credential slot. Keep
  // lifecycle callbacks from restarting owner polling until the route is
  // recreated through the Forge login flow.
  bool _authorizationInvalidated = false;
  late final void Function() _cancelLocationChange;
  bool _hasObservedLocationSelection = false;
  String? _observedLocationConversationID;
  bool _hasPendingLocationSelection = false;
  String? _pendingLocationConversationID;
  int _locationSelectionGeneration = 0;
  bool _restoringLocationSelection = false;
  int _promptGeneration = 0;
  int _runGeneration = 0;
  int _runTimelineGeneration = 0;
  int _runTimelineSequence = 0;
  ForgePendingRunIntentSubmission? _pendingRunIntentSubmission;
  _PendingRunIntentRequest? _pendingRunIntentRequest;
  String? _pendingRunIntentSubmitError;

  @override
  void initState() {
    super.initState();
    _selectedClientInstanceID = _initialClientInstanceID();
    WidgetsBinding.instance.addObserver(this);
    _tokenRefresh = ForgeOAuthTokenRefresh(
      baseUrl: ProductApiOrigin.baseUrl,
      httpClient: widget.oauthHttpClient,
      revocationTimeout: widget.oauthRevocationTimeout,
      credentialStore: _credentialStore,
    );
    _api = ForgeConversationsApi(
      baseUrl: widget.apiOrigin,
      accessToken: widget.accessToken,
      accessTokenProvider: () =>
          Session.readForClient(ForgeConversationsOAuth.clientId),
      refreshAccessToken: _tokenRefresh.refreshAfterUnauthorized,
      httpClient: widget.httpClient,
    );
    _changeCursorStore = ForgeChangeCursorStore(
      accessToken: widget.accessToken,
      apiOrigin: widget.apiOrigin,
      clientId: ForgeConversationsOAuth.clientId,
      resource: ForgeConversationsOAuth.resource,
    );
    _cursorReady = _restoreChangeCursor();
    _runnerLeaseFencingPreview = _safeRunnerLeaseFencingPreview(
      widget.runnerLeaseFencingPreview,
    );
    _executionLeaseCheckpointPreview = _safeExecutionLeaseCheckpointPreview(
      widget.executionLeaseCheckpointPreview,
    );
    _runnerAttemptBoundaryPreview = _safeRunnerAttemptBoundaryPreview(
      widget.runnerAttemptBoundaryPreview,
    );
    _sessionRunnerReceiptVectorsPreview =
        _safeSessionRunnerReceiptVectorsPreview(
          widget.sessionRunnerReceiptVectorsPreview,
        );
    _sessionRunnerReceiptHistoryPreview =
        _safeSessionRunnerReceiptHistoryPreview(
          widget.sessionRunnerReceiptHistoryPreview,
        );
    _sessionRunnerReconciliationProjectionPreview =
        _safeSessionRunnerReconciliationProjectionPreview(
          widget.sessionRunnerReconciliationProjectionPreview,
        );
    _deviceInventoryV2Preview = _safeDeviceInventoryV2Preview(
      widget.deviceInventoryV2Preview,
    );
    _deviceResourceSummaryPreview = _safeDeviceResourceSummaryPreview(
      widget.deviceResourceSummaryPreview,
    );
    _clientInstanceResourceViewPreview = _safeClientInstanceResourceViewPreview(
      widget.clientInstanceResourceViewPreview,
    );
    _clientInstanceSessionViewPreview = _safeClientInstanceSessionViewPreview(
      widget.clientInstanceSessionViewPreview,
    );
    _deviceInventoryPlacementEvaluationV2Preview =
        _safeDeviceInventoryPlacementEvaluationV2Preview(
          widget.deviceInventoryPlacementEvaluationV2Preview,
        );
    _deviceInventoryPlacementEvaluationPreview =
        _safeDeviceInventoryPlacementEvaluationPreview(
          widget.deviceInventoryPlacementEvaluationPreview,
        );
    _deviceInventoryPlacementBatchEvaluationPreview =
        _safeDeviceInventoryPlacementBatchEvaluationPreview(
          widget.deviceInventoryPlacementBatchEvaluationPreview,
        );
    _cancelLocationChange = BrowserNavigation.listenToLocationChange(
      _onLocationChange,
    );
    // Keep the optional candidate read behind the initial owner session
    // snapshot. The two authenticated reads otherwise race during cold start
    // against a coordinator that is still warming its Runtime bridge.
    unawaited(_initialLoad());
    _startChangeSyncTimer();
  }

  Future<void> _initialLoad() async {
    // Prime an explicitly requested local instance projection before the
    // owner Conversation list. This prevents the first list item from being
    // hydrated as a private Prompt/Run selection before the display filter
    // has established which sessions belong to the requested instance.
    if (_selectedClientInstanceID != null) {
      await _loadDeviceInventoryResourceConvergenceIfRequested();
      await _loadClientInstanceSessionResourceConvergenceIfRequested();
      await _loadClientInstanceSessionViewIfRequested();
      await _loadClientInstanceResourceViewIfRequested();
    }
    await _refreshConversations(selectID: widget.initialConversationID);
    if (mounted) {
      await _loadPendingRunIntentsIfRequested();
      await _loadDeviceInventoryIfRequested();
      await _loadDeviceInventoryV2IfRequested();
      await _loadDeviceInventoryResourceConvergenceIfRequested();
      await _loadDeviceInventoryRegistryPlacementPreviewIfRequested();
      await _loadSchedulerSelectionPreviewIfRequested();
      await _loadSchedulerSelectionLeaseIfRequested();
      await _loadSchedulerSelectionLeaseReleaseIfRequested();
      await _loadClientInstanceSessionResourceConvergenceIfRequested();
      await _loadClientInstanceSessionViewIfRequested();
      await _loadClientInstanceResourceViewIfRequested();
      await _loadLifecycleRegistryIfRequested();
      await _loadDeviceCredentialCandidateIfRequested();
      await _loadRunAttemptLeaseDispatchPreflightIfRequested();
      await _loadRunnerDispatchPlanPreviewIfRequested();
      await _loadRunnerExecutionIntentIfRequested();
      await _loadRunnerDispatchAdmissionIfRequested();
      await _loadRunnerTransportAdmissionIfRequested();
      await _loadRunnerExecutionBoundaryIfRequested();
      await _loadRunnerAttemptBoundaryIfRequested();
      await _loadLocalRunnerPreviewIfRequested();
      await _loadExecutionReconciliationIfRequested();
      await _loadExecutionConsentPreviewIfRequested();
      await _loadRunExecutionEvidenceIfRequested();
      await _loadSessionRunnerReceiptHistoryIfRequested();
      await _loadSessionRunnerReconciliationProjectionIfRequested();
    }
    if (mounted) {
      _initialLoadComplete = true;
      _startChangeSyncTimer();
    }
  }

  String? _initialClientInstanceID() {
    final value = widget.initialClientInstanceID?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelLocationChange();
    _stopChangeSyncTimer();
    _api.close();
    _tokenRefresh.close();
    _titleController.dispose();
    _scopeIDController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ForgeSessionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableConversationChangesStream !=
            widget.enableConversationChangesStream ||
        oldWidget.conversationChangesStreamWaitMS !=
            widget.conversationChangesStreamWaitMS) {
      _changeStreamFallbackToPolling = false;
      _changeStreamGeneration++;
      _changeStreamReconnectTimer?.cancel();
      _changeStreamReconnectTimer = null;
      if (widget.enableConversationChangesStream) {
        _startChangeSyncTimer();
      } else {
        _startChangeSyncTimer();
      }
    }
    final deviceObservationChanged = !_sameDeviceObservationRequest(
      oldWidget.deviceObservationRequest,
      widget.deviceObservationRequest,
    );
    final deviceInventoryChanged =
        oldWidget.deviceInventoryOwner != widget.deviceInventoryOwner ||
        oldWidget.deviceInventoryReader != widget.deviceInventoryReader;
    final deviceInventoryV2Changed =
        oldWidget.deviceInventoryOwner != widget.deviceInventoryOwner ||
        oldWidget.deviceInventoryV2Reader != widget.deviceInventoryV2Reader;
    final deviceInventoryResourceConvergenceChanged =
        oldWidget.deviceInventoryResourceConvergenceOwner !=
            widget.deviceInventoryResourceConvergenceOwner ||
        oldWidget.deviceInventoryResourceConvergenceReader !=
            widget.deviceInventoryResourceConvergenceReader;
    final deviceInventoryRegistryPlacementPreviewChanged =
        oldWidget.deviceInventoryOwner != widget.deviceInventoryOwner ||
        oldWidget.deviceInventoryRegistryPlacementRequirements !=
            widget.deviceInventoryRegistryPlacementRequirements ||
        oldWidget.deviceInventoryRegistryPlacementPreviewReader !=
            widget.deviceInventoryRegistryPlacementPreviewReader;
    final schedulerSelectionPreviewChanged =
        oldWidget.schedulerSelectionPreviewRequest !=
            widget.schedulerSelectionPreviewRequest ||
        oldWidget.schedulerSelectionPreviewReader !=
            widget.schedulerSelectionPreviewReader;
    final schedulerSelectionLeaseChanged =
        oldWidget.schedulerSelectionLeaseRequest !=
            widget.schedulerSelectionLeaseRequest ||
        oldWidget.schedulerSelectionLeaseReader !=
            widget.schedulerSelectionLeaseReader ||
        oldWidget.schedulerSelectionLeaseIdempotencyKey !=
            widget.schedulerSelectionLeaseIdempotencyKey ||
        oldWidget.schedulerSelectionLeaseRenewalRequest !=
            widget.schedulerSelectionLeaseRenewalRequest ||
        oldWidget.schedulerSelectionLeaseRenewalReader !=
            widget.schedulerSelectionLeaseRenewalReader ||
        oldWidget.schedulerSelectionLeaseRenewalIdempotencyKey !=
            widget.schedulerSelectionLeaseRenewalIdempotencyKey;
    final schedulerSelectionLeaseReleaseChanged =
        oldWidget.schedulerSelectionLeaseReleaseRequest !=
            widget.schedulerSelectionLeaseReleaseRequest ||
        oldWidget.schedulerSelectionLeaseReleaseReader !=
            widget.schedulerSelectionLeaseReleaseReader ||
        oldWidget.schedulerSelectionLeaseReleaseIdempotencyKey !=
            widget.schedulerSelectionLeaseReleaseIdempotencyKey;
    final clientInstanceResourceViewChanged =
        oldWidget.clientInstanceResourceViewOwner !=
            widget.clientInstanceResourceViewOwner ||
        oldWidget.clientInstanceResourceViewReader !=
            widget.clientInstanceResourceViewReader;
    final clientInstanceResourceViewPreviewChanged =
        oldWidget.clientInstanceResourceViewPreview !=
        widget.clientInstanceResourceViewPreview;
    final clientInstanceSessionViewChanged =
        oldWidget.clientInstanceSessionViewOwner !=
            widget.clientInstanceSessionViewOwner ||
        oldWidget.clientInstanceSessionViewReader !=
            widget.clientInstanceSessionViewReader;
    final clientInstanceSessionViewPreviewChanged =
        oldWidget.clientInstanceSessionViewPreview !=
        widget.clientInstanceSessionViewPreview;
    final clientInstanceSessionResourceConvergenceChanged =
        oldWidget.clientInstanceSessionResourceConvergenceOwner !=
            widget.clientInstanceSessionResourceConvergenceOwner ||
        oldWidget.clientInstanceSessionResourceConvergenceReader !=
            widget.clientInstanceSessionResourceConvergenceReader;
    final lifecycleRegistryChanged =
        oldWidget.lifecycleRegistryOwner != widget.lifecycleRegistryOwner ||
        oldWidget.lifecycleRegistryReader != widget.lifecycleRegistryReader;
    final deviceCredentialCandidateChanged =
        oldWidget.deviceCredentialCandidateOwner !=
            widget.deviceCredentialCandidateOwner ||
        !_sameDeviceCredentialCandidateRequest(
          oldWidget.deviceCredentialCandidateRequest,
          widget.deviceCredentialCandidateRequest,
        ) ||
        oldWidget.deviceCredentialCandidateReader !=
            widget.deviceCredentialCandidateReader;
    final runAttemptLeaseDispatchPreflightChanged =
        oldWidget.runAttemptLeaseDispatchPreflightRequest !=
            widget.runAttemptLeaseDispatchPreflightRequest ||
        oldWidget.runAttemptLeaseDispatchPreflightReader !=
            widget.runAttemptLeaseDispatchPreflightReader;
    final runnerDispatchPlanPreviewChanged =
        oldWidget.runnerDispatchPlanPreviewRequest !=
            widget.runnerDispatchPlanPreviewRequest ||
        oldWidget.runnerDispatchPlanPreviewReader !=
            widget.runnerDispatchPlanPreviewReader;
    final runnerExecutionIntentChanged =
        oldWidget.runnerExecutionIntentRequest !=
            widget.runnerExecutionIntentRequest ||
        oldWidget.runnerExecutionIntentReader !=
            widget.runnerExecutionIntentReader;
    final runnerDispatchAdmissionChanged =
        oldWidget.runnerDispatchAdmissionRequest !=
            widget.runnerDispatchAdmissionRequest ||
        oldWidget.runnerDispatchAdmissionReader !=
            widget.runnerDispatchAdmissionReader;
    final runnerTransportAdmissionChanged =
        oldWidget.runnerTransportAdmissionRequest !=
            widget.runnerTransportAdmissionRequest ||
        oldWidget.runnerTransportAdmissionReader !=
            widget.runnerTransportAdmissionReader;
    final runnerExecutionBoundaryChanged =
        oldWidget.runnerExecutionBoundaryRequest !=
            widget.runnerExecutionBoundaryRequest ||
        oldWidget.runnerExecutionBoundaryReader !=
            widget.runnerExecutionBoundaryReader;
    final runnerAttemptBoundaryCandidateChanged =
        oldWidget.runnerAttemptBoundaryRequest !=
            widget.runnerAttemptBoundaryRequest ||
        oldWidget.runnerAttemptBoundaryReader !=
            widget.runnerAttemptBoundaryReader;
    final runnerAttemptBoundaryProjectionChanged =
        oldWidget.runnerAttemptBoundaryPreview !=
            widget.runnerAttemptBoundaryPreview ||
        oldWidget.runnerAttemptBoundaryScope !=
            widget.runnerAttemptBoundaryScope ||
        oldWidget.runnerAttemptBoundaryFileReader !=
            widget.runnerAttemptBoundaryFileReader ||
        oldWidget.enableRunnerAttemptBoundaryProjection !=
            widget.enableRunnerAttemptBoundaryProjection;
    final localRunnerPreviewChanged =
        oldWidget.localRunnerPreviewRequest !=
            widget.localRunnerPreviewRequest ||
        oldWidget.localRunnerPreviewReader != widget.localRunnerPreviewReader;
    final executionReconciliationChanged =
        oldWidget.executionReconciliationInput !=
            widget.executionReconciliationInput ||
        oldWidget.executionReconciliationReader !=
            widget.executionReconciliationReader;
    final executionConsentPreviewChanged =
        oldWidget.executionConsentPreviewOwner !=
            widget.executionConsentPreviewOwner ||
        oldWidget.executionConsentPreviewReader !=
            widget.executionConsentPreviewReader;
    final runObservedReaderChanged =
        oldWidget.runObservedReader != widget.runObservedReader ||
        oldWidget.sessionRunnerReceiptObservationReader !=
            widget.sessionRunnerReceiptObservationReader;
    final runExecutionEvidenceChanged =
        oldWidget.runExecutionEvidenceReader !=
            widget.runExecutionEvidenceReader ||
        oldWidget.runObserved != widget.runObserved ||
        oldWidget.sessionRunnerReceiptObservation !=
            widget.sessionRunnerReceiptObservation;
    final sessionRunnerReceiptHistoryCandidateChanged =
        oldWidget.sessionRunnerReceiptHistoryRequest !=
            widget.sessionRunnerReceiptHistoryRequest ||
        oldWidget.sessionRunnerReceiptHistoryReader !=
            widget.sessionRunnerReceiptHistoryReader;
    final sessionRunnerReconciliationProjectionCandidateChanged =
        oldWidget.sessionRunnerReconciliationProjectionRequest !=
            widget.sessionRunnerReconciliationProjectionRequest ||
        oldWidget.sessionRunnerReconciliationProjectionReader !=
            widget.sessionRunnerReconciliationProjectionReader;
    final pendingRunIntentChanged =
        oldWidget.pendingRunIntentReader != widget.pendingRunIntentReader ||
        oldWidget.pendingRunIntentPageReader !=
            widget.pendingRunIntentPageReader ||
        oldWidget.pendingRunIntentTimelineReader !=
            widget.pendingRunIntentTimelineReader;
    if (deviceObservationChanged) {
      // A parent can replace the caller-supplied declaration while keeping
      // this screen mounted (for example, after a Web/App/Mobile preview
      // completes). Drop the previous response before evaluating the new
      // request so a changed declaration cannot be shown as if it were still
      // current.
      setState(_clearDeviceObservation);
      final conversationID = _selected?.conversation.id;
      final runID = _selectedRun?.runID;
      if (conversationID != null && runID != null) {
        unawaited(_loadDeviceObservationIfRequested(conversationID, runID));
      }
    }
    if (deviceInventoryChanged) {
      setState(_clearDeviceInventory);
      unawaited(_loadDeviceInventoryIfRequested());
    }
    if (deviceInventoryV2Changed) {
      setState(_clearDeviceInventoryV2);
      unawaited(_loadDeviceInventoryV2IfRequested());
    }
    if (deviceInventoryResourceConvergenceChanged) {
      setState(_clearDeviceInventoryResourceConvergence);
      unawaited(_loadDeviceInventoryResourceConvergenceIfRequested());
    }
    if (deviceInventoryRegistryPlacementPreviewChanged) {
      setState(_clearDeviceInventoryRegistryPlacementPreview);
      unawaited(_loadDeviceInventoryRegistryPlacementPreviewIfRequested());
    }
    if (schedulerSelectionPreviewChanged) {
      setState(_clearSchedulerSelectionPreview);
      unawaited(_loadSchedulerSelectionPreviewIfRequested());
    }
    if (schedulerSelectionLeaseChanged) {
      setState(_clearSchedulerSelectionLease);
      unawaited(_loadSchedulerSelectionLeaseIfRequested());
    }
    if (schedulerSelectionLeaseReleaseChanged) {
      setState(_clearSchedulerSelectionLeaseRelease);
      unawaited(_loadSchedulerSelectionLeaseReleaseIfRequested());
    }
    if (clientInstanceResourceViewChanged) {
      setState(_clearClientInstanceResourceView);
      unawaited(_loadClientInstanceResourceViewIfRequested());
    }
    if (clientInstanceSessionViewChanged) {
      setState(_clearClientInstanceSessionView);
      unawaited(_loadClientInstanceSessionViewIfRequested());
    }
    if (clientInstanceSessionResourceConvergenceChanged) {
      setState(_clearClientInstanceSessionResourceConvergence);
      unawaited(_loadClientInstanceSessionResourceConvergenceIfRequested());
    }
    if (lifecycleRegistryChanged) {
      setState(_clearLifecycleRegistry);
      unawaited(_loadLifecycleRegistryIfRequested());
    }
    if (deviceCredentialCandidateChanged) {
      setState(_clearDeviceCredentialCandidate);
      unawaited(_loadDeviceCredentialCandidateIfRequested());
    }
    if (runAttemptLeaseDispatchPreflightChanged) {
      setState(_clearRunAttemptLeaseDispatchPreflight);
      unawaited(_loadRunAttemptLeaseDispatchPreflightIfRequested());
    }
    if (runnerDispatchPlanPreviewChanged) {
      setState(_clearRunnerDispatchPlanPreview);
      unawaited(_loadRunnerDispatchPlanPreviewIfRequested());
    }
    if (runnerExecutionIntentChanged) {
      setState(_clearRunnerExecutionIntent);
      unawaited(_loadRunnerExecutionIntentIfRequested());
    }
    if (runnerDispatchAdmissionChanged) {
      setState(_clearRunnerDispatchAdmission);
      unawaited(_loadRunnerDispatchAdmissionIfRequested());
    }
    if (runnerTransportAdmissionChanged) {
      setState(_clearRunnerTransportAdmission);
      unawaited(_loadRunnerTransportAdmissionIfRequested());
    }
    if (runnerExecutionBoundaryChanged) {
      setState(_clearRunnerExecutionBoundary);
      unawaited(_loadRunnerExecutionBoundaryIfRequested());
    }
    if (runnerAttemptBoundaryCandidateChanged) {
      setState(_clearRunnerAttemptBoundary);
      unawaited(_loadRunnerAttemptBoundaryIfRequested());
    }
    if (runnerAttemptBoundaryProjectionChanged) {
      setState(() {
        _clearRunnerAttemptBoundaryPreview();
        _runnerAttemptBoundaryPreview = _safeRunnerAttemptBoundaryPreview(
          widget.runnerAttemptBoundaryPreview,
        );
      });
    }
    if (localRunnerPreviewChanged) {
      setState(_clearLocalRunnerPreview);
      unawaited(_loadLocalRunnerPreviewIfRequested());
    }
    if (executionReconciliationChanged) {
      setState(_clearExecutionReconciliation);
      unawaited(_loadExecutionReconciliationIfRequested());
    }
    if (executionConsentPreviewChanged) {
      setState(_clearExecutionConsentPreview);
      unawaited(_loadExecutionConsentPreviewIfRequested());
    }
    if (runObservedReaderChanged) {
      setState(_clearRunObserved);
      final conversationID = _selected?.conversation.id;
      final runID = _selectedRun?.runID;
      if (conversationID != null && runID != null) {
        unawaited(
          _loadRunObservedIfRequested(
            conversationID: conversationID,
            runID: runID,
          ),
        );
      }
    }
    if (runExecutionEvidenceChanged) {
      setState(_clearRunExecutionEvidence);
      final conversationID = _selected?.conversation.id;
      final runID = _selectedRun?.runID;
      if (conversationID != null && runID != null) {
        unawaited(
          _loadRunExecutionEvidenceIfRequested(
            conversationID: conversationID,
            runID: runID,
          ),
        );
      }
    }
    if (sessionRunnerReceiptHistoryCandidateChanged) {
      setState(_clearSessionRunnerReceiptHistory);
      final conversationID = _selected?.conversation.id;
      final runID = _selectedRun?.runID;
      if (conversationID != null && runID != null) {
        unawaited(
          _loadSessionRunnerReceiptHistoryIfRequested(
            conversationID: conversationID,
            runID: runID,
          ),
        );
      }
    }
    if (sessionRunnerReconciliationProjectionCandidateChanged) {
      setState(_clearSessionRunnerReconciliationProjection);
      final conversationID = _selected?.conversation.id;
      final runID = _selectedRun?.runID;
      if (conversationID != null && runID != null) {
        unawaited(
          _loadSessionRunnerReconciliationProjectionIfRequested(
            conversationID: conversationID,
            runID: runID,
          ),
        );
      }
    }
    if (pendingRunIntentChanged) {
      setState(_clearPendingRunIntents);
      unawaited(_loadPendingRunIntentsIfRequested());
    }
    if (clientInstanceResourceViewPreviewChanged ||
        clientInstanceSessionViewPreviewChanged) {
      _reconcileSelectedClientInstanceProjection();
    }
    if (oldWidget.runnerLeaseFencingPreview !=
        widget.runnerLeaseFencingPreview) {
      setState(() {
        _runnerLeaseFencingPreview = _safeRunnerLeaseFencingPreview(
          widget.runnerLeaseFencingPreview,
        );
        _runnerLeaseFencingError = null;
      });
    }
    if (oldWidget.executionLeaseCheckpointPreview !=
        widget.executionLeaseCheckpointPreview) {
      setState(() {
        _executionLeaseCheckpointPreview = _safeExecutionLeaseCheckpointPreview(
          widget.executionLeaseCheckpointPreview,
        );
        _executionLeaseCheckpointError = null;
      });
    }
    if (oldWidget.sessionRunnerReceiptVectorsPreview !=
        widget.sessionRunnerReceiptVectorsPreview) {
      setState(() {
        _sessionRunnerReceiptVectorsPreview =
            _safeSessionRunnerReceiptVectorsPreview(
              widget.sessionRunnerReceiptVectorsPreview,
            );
        _sessionRunnerReceiptVectorsPreviewError = null;
      });
    }
    if (oldWidget.sessionRunnerReceiptHistoryPreview !=
        widget.sessionRunnerReceiptHistoryPreview) {
      setState(() {
        _sessionRunnerReceiptHistoryPreview =
            _safeSessionRunnerReceiptHistoryPreview(
              widget.sessionRunnerReceiptHistoryPreview,
            );
        _sessionRunnerReceiptHistoryPreviewError = null;
      });
    }
    if (oldWidget.sessionRunnerReconciliationProjectionPreview !=
        widget.sessionRunnerReconciliationProjectionPreview) {
      setState(() {
        _sessionRunnerReconciliationProjectionPreview =
            _safeSessionRunnerReconciliationProjectionPreview(
              widget.sessionRunnerReconciliationProjectionPreview,
            );
        _sessionRunnerReconciliationProjectionPreviewError = null;
      });
    }
    if (oldWidget.deviceInventoryV2Preview != widget.deviceInventoryV2Preview) {
      setState(() {
        _deviceInventoryV2Preview = _safeDeviceInventoryV2Preview(
          widget.deviceInventoryV2Preview,
        );
        _deviceInventoryV2PreviewError = null;
      });
    }
    if (oldWidget.deviceResourceSummaryPreview !=
        widget.deviceResourceSummaryPreview) {
      setState(() {
        _deviceResourceSummaryPreview = _safeDeviceResourceSummaryPreview(
          widget.deviceResourceSummaryPreview,
        );
        _deviceResourceSummaryPreviewError = null;
      });
    }
    if (oldWidget.clientInstanceResourceViewPreview !=
        widget.clientInstanceResourceViewPreview) {
      setState(() {
        _clientInstanceResourceViewPreview =
            _safeClientInstanceResourceViewPreview(
              widget.clientInstanceResourceViewPreview,
            );
        _clientInstanceResourceViewPreviewError = null;
      });
      _reconcileSelectedClientInstanceProjection();
    }
    if (oldWidget.clientInstanceSessionViewPreview !=
        widget.clientInstanceSessionViewPreview) {
      setState(() {
        _clientInstanceSessionViewPreview =
            _safeClientInstanceSessionViewPreview(
              widget.clientInstanceSessionViewPreview,
            );
        _clientInstanceSessionViewPreviewError = null;
      });
      _reconcileSelectedClientInstanceProjection();
    }
    if (oldWidget.deviceInventoryPlacementEvaluationV2Preview !=
        widget.deviceInventoryPlacementEvaluationV2Preview) {
      setState(() {
        _deviceInventoryPlacementEvaluationV2Preview =
            _safeDeviceInventoryPlacementEvaluationV2Preview(
              widget.deviceInventoryPlacementEvaluationV2Preview,
            );
        _deviceInventoryPlacementEvaluationV2PreviewError = null;
      });
    }
    if (oldWidget.deviceInventoryPlacementEvaluationPreview !=
        widget.deviceInventoryPlacementEvaluationPreview) {
      setState(() {
        _deviceInventoryPlacementEvaluationPreview =
            _safeDeviceInventoryPlacementEvaluationPreview(
              widget.deviceInventoryPlacementEvaluationPreview,
            );
        _deviceInventoryPlacementEvaluationPreviewError = null;
      });
    }
    if (oldWidget.deviceInventoryPlacementBatchEvaluationPreview !=
        widget.deviceInventoryPlacementBatchEvaluationPreview) {
      setState(() {
        _deviceInventoryPlacementBatchEvaluationPreview =
            _safeDeviceInventoryPlacementBatchEvaluationPreview(
              widget.deviceInventoryPlacementBatchEvaluationPreview,
            );
        _deviceInventoryPlacementBatchEvaluationPreviewError = null;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startChangeSyncTimer();
      _refreshOnResume();
      return;
    }
    _stopChangeSyncTimer();
  }

  /// Mobile platforms and desktop window integrations can report more than
  /// one `resumed` notification while a route is returning to the foreground.
  /// Coalesce those notifications so a single resume cannot issue overlapping
  /// feed, session, and Run reads.
  void _refreshOnResume() {
    if (_refreshingOnResume ||
        _sessionViewInvalidated ||
        _authorizationInvalidated) {
      return;
    }
    _refreshingOnResume = true;
    unawaited(_refreshAndSyncOnResume());
  }

  Future<void> _refreshAndSyncOnResume() async {
    try {
      await _refreshAndSync();
    } finally {
      _refreshingOnResume = false;
    }
  }

  void _startChangeSyncTimer({bool immediate = false}) {
    if (_sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    _changeSyncEnabled = true;
    if (widget.enableConversationChangesStream &&
        !_changeStreamFallbackToPolling) {
      if (!_initialLoadComplete) return;
      _scheduleChangeStreamReconnect();
      return;
    }
    if (_changeSyncTimer != null || _changePollInFlight) return;
    _changeSyncTimer = Timer(immediate ? Duration.zero : _changePollDelay, () {
      _changeSyncTimer = null;
      unawaited(_runScheduledChangePoll());
    });
  }

  /// A successful feed read also proves that the transport recovered. Retry a
  /// failed conversation snapshot so a transient outage does not leave the
  /// screen empty until the user manually refreshes or backgrounds the app.
  Future<_ForgeChangePollOutcome> _pollForChanges() async {
    if (_sessionViewInvalidated || _authorizationInvalidated) {
      return _ForgeChangePollOutcome.skipped;
    }
    final syncOutcome = await _syncChanges();
    if (syncOutcome == _ForgeChangeSyncOutcome.skipped) {
      return _ForgeChangePollOutcome.skipped;
    }
    // A change-bearing sync already refreshes pending Run-intent metadata as
    // part of its selected-conversation update. The scheduled path must also
    // refresh the explicit reader when the feed is unchanged (or recovered
    // after a transient failure), otherwise an opted-in metadata panel can
    // remain stale between foreground/manual refreshes. The default reader
    // remains request-free.
    if (syncOutcome != _ForgeChangeSyncOutcome.changed &&
        syncOutcome != _ForgeChangeSyncOutcome.advancedHidden) {
      await _loadPendingRunIntentsIfRequested(force: true);
    }
    // The scheduled path invokes _syncChanges directly rather than the
    // manual/resume wrapper. Refresh explicitly injected v1 and v2 inventory
    // readers here so either opted-in resource view cannot remain stale
    // between foreground refreshes; the default readers remain request-free.
    // These owner-scoped observations are independent GETs. Start them from
    // the same poll frame so one slow candidate cannot consume the entire
    // transport window before the other proof image is refreshed.
    await Future.wait([
      _loadDeviceInventoryIfRequested(force: true),
      _loadDeviceInventoryV2IfRequested(force: true),
      _loadDeviceInventoryResourceConvergenceIfRequested(force: true),
    ]);
    // Registry-backed placement is another explicit display-only reader. It
    // follows the same owner-scoped cadence when enabled and remains a no-op
    // for the default Gate.
    await _loadDeviceInventoryRegistryPlacementPreviewIfRequested(force: true);
    await _loadSchedulerSelectionPreviewIfRequested(force: true);
    // Client-instance views are also explicit display-only readers. When an
    // instance is selected, _syncChanges has already refreshed them before
    // touching owner-scoped state; repeating the reads here could produce a
    // newer projection than the Conversation page was filtered against.
    if (_selectedClientInstanceID == null) {
      await _loadClientInstanceSessionResourceConvergenceIfRequested(
        force: true,
      );
      await _loadClientInstanceSessionViewIfRequested(force: true);
      await _loadClientInstanceResourceViewIfRequested(force: true);
    }
    await _loadLifecycleRegistryIfRequested(force: true);
    await _loadExecutionConsentPreviewIfRequested(force: true);
    var succeeded = syncOutcome != _ForgeChangeSyncOutcome.failed;
    if (syncOutcome == _ForgeChangeSyncOutcome.advancedHidden) {
      return succeeded
          ? _ForgeChangePollOutcome.succeeded
          : _ForgeChangePollOutcome.failed;
    }
    if (!mounted ||
        _changeError != null ||
        (_conversationError == null && !_conversationsStale)) {
      return succeeded
          ? _ForgeChangePollOutcome.succeeded
          : _ForgeChangePollOutcome.failed;
    }
    if (!_selectedClientInstanceProjectionReadyForOwnerReads()) {
      return _ForgeChangePollOutcome.failed;
    }
    succeeded = await _refreshConversations() && succeeded;
    return succeeded
        ? _ForgeChangePollOutcome.succeeded
        : _ForgeChangePollOutcome.failed;
  }

  Future<void> _runScheduledChangePoll() async {
    if (!_changeSyncEnabled ||
        _sessionViewInvalidated ||
        _authorizationInvalidated ||
        _changePollInFlight) {
      return;
    }
    _changePollInFlight = true;
    final outcome = await _pollForChanges();
    _changePollInFlight = false;
    if (!_changeSyncEnabled ||
        _sessionViewInvalidated ||
        _authorizationInvalidated ||
        !mounted) {
      return;
    }
    switch (outcome) {
      case _ForgeChangePollOutcome.succeeded:
        _changePollFailureStreak = 0;
        _changePollDelay = _changePollBaseDelay;
      case _ForgeChangePollOutcome.failed:
        _changePollFailureStreak = min(
          _changePollFailureStreak + 1,
          _changePollMaxFailureStreak,
        );
        final multiplier = 1 << _changePollFailureStreak;
        _changePollDelay = Duration(
          milliseconds: min(
            _changePollBaseDelay.inMilliseconds * multiplier,
            _changePollMaxDelay.inMilliseconds,
          ),
        );
      case _ForgeChangePollOutcome.skipped:
        break;
    }
    _startChangeSyncTimer();
  }

  void _scheduleChangeStreamReconnect({bool immediate = false}) {
    if (!_changeSyncEnabled ||
        _sessionViewInvalidated ||
        _authorizationInvalidated ||
        !widget.enableConversationChangesStream ||
        _changeStreamFallbackToPolling ||
        !_initialLoadComplete ||
        _changeStreamReconnectTimer != null ||
        _changeStreamInFlight) {
      return;
    }
    final generation = _changeStreamGeneration;
    _changeStreamReconnectTimer = Timer(
      immediate ? Duration.zero : _changeStreamReconnectDelay,
      () {
        _changeStreamReconnectTimer = null;
        if (generation != _changeStreamGeneration) return;
        unawaited(_runScheduledChangeStream(generation));
      },
    );
  }

  Future<void> _runScheduledChangeStream(int generation) async {
    if (generation != _changeStreamGeneration ||
        !_changeSyncEnabled ||
        _sessionViewInvalidated ||
        _authorizationInvalidated ||
        !mounted ||
        _changeStreamInFlight ||
        _changeStreamFallbackToPolling) {
      return;
    }
    _changeStreamInFlight = true;
    final outcome = await _syncChanges(stream: true);
    _changeStreamInFlight = false;
    if (generation != _changeStreamGeneration ||
        !_changeSyncEnabled ||
        _sessionViewInvalidated ||
        _authorizationInvalidated ||
        !mounted) {
      return;
    }
    if (outcome == _ForgeChangeSyncOutcome.failed) {
      // A stream transport, authorization, or framing failure must not leave
      // the shared Sessions surface stale. Degrade this screen instance to
      // the already-tested bounded polling path.
      _changeStreamFallbackToPolling = true;
      _startChangeSyncTimer(immediate: true);
      return;
    }
    if (outcome == _ForgeChangeSyncOutcome.skipped) {
      // A manual refresh may own the shared merge gate briefly. Leave a
      // bounded gap before retrying instead of spinning microtasks while it
      // completes.
      _scheduleChangeStreamReconnect();
      return;
    }
    // A 204 timeout and an unchanged page both reconnect through one bounded
    // single-flight stream. Cursor persistence still belongs to _syncChanges
    // and occurs only after the page has been merged successfully.
    _scheduleChangeStreamReconnect(immediate: true);
  }

  void _stopChangeSyncTimer() {
    _changeSyncEnabled = false;
    _changeSyncTimer?.cancel();
    _changeSyncTimer = null;
    _changeStreamReconnectTimer?.cancel();
    _changeStreamReconnectTimer = null;
    _changeStreamGeneration++;
  }

  void _onLocationChange() {
    if (!mounted) return;
    final location = BrowserNavigation.currentUri;
    if (!_isForgeSessionsLocation(location)) return;
    final conversationID = _conversationIDFromLocation(location);
    if (_hasObservedLocationSelection &&
        _observedLocationConversationID == conversationID) {
      if (_selected?.conversation.id == conversationID) {
        _takePendingLocationSelection();
      }
      return;
    }
    _hasObservedLocationSelection = true;
    _observedLocationConversationID = conversationID;
    if (_selected?.conversation.id == conversationID) {
      _takePendingLocationSelection();
      return;
    }

    _hasPendingLocationSelection = true;
    _pendingLocationConversationID = conversationID;
    final generation = ++_locationSelectionGeneration;
    if (_loadingConversations || _restoringLocationSelection) return;
    unawaited(_restoreLocationSelection(conversationID, generation));
  }

  Future<void> _restoreLocationSelection(
    String? conversationID,
    int generation,
  ) async {
    if (!mounted || generation != _locationSelectionGeneration) return;
    _restoringLocationSelection = true;
    try {
      if (conversationID == null) {
        if (!mounted || generation != _locationSelectionGeneration) return;
        _takePendingLocationSelection();
        if (_selected == null) return;
        setState(() {
          _selected = null;
          _clearConversationDetails();
        });
        return;
      }

      final local = _findConversation(_conversations, conversationID);
      if (local != null) {
        _takePendingLocationSelection();
        await _selectConversation(
          local,
          updateLocation: false,
          locationGeneration: generation,
        );
        return;
      }

      // Keep the first list page intact while resolving a URL that points to
      // an older owner-scoped session. _refreshConversations performs the
      // authenticated detail fallback exactly once for that selection.
      await _refreshConversations(selectID: conversationID);
    } finally {
      _restoringLocationSelection = false;
      if (mounted && !_loadingConversations && _hasPendingLocationSelection) {
        final nextGeneration = _locationSelectionGeneration;
        if (nextGeneration != generation) {
          final nextConversationID = _pendingLocationConversationID;
          unawaited(
            _restoreLocationSelection(nextConversationID, nextGeneration),
          );
        }
      }
    }
  }

  String? _takePendingLocationSelection() {
    if (!_hasPendingLocationSelection) return null;
    final conversationID = _pendingLocationConversationID;
    _hasPendingLocationSelection = false;
    _pendingLocationConversationID = null;
    return conversationID;
  }

  bool _isForgeSessionsLocation(Uri location) {
    final segments = location.pathSegments;
    if (segments.length == 1 && segments[0] == 'forge') return true;
    if (segments.length == 2 && segments[0] == 'forge' && segments[1].isEmpty) {
      return true;
    }
    return segments.length == 3 &&
        segments[0] == 'forge' &&
        segments[1] == 'conversations' &&
        segments[2].isNotEmpty;
  }

  String? _conversationIDFromLocation(Uri location) {
    final segments = location.pathSegments;
    if (segments.length != 3 ||
        segments[0] != 'forge' ||
        segments[1] != 'conversations' ||
        segments[2].isEmpty) {
      return null;
    }
    return segments[2];
  }

  Future<bool> _refreshConversations({
    bool loadMore = false,
    String? selectID,
    bool loadPendingRunIntents = true,
  }) async {
    if (_loadingConversations && !loadMore) return false;
    final generation = ++_conversationGeneration;
    final clientInstanceFilterGeneration = _clientInstanceFilterGeneration;
    var resolvingOwnerSelection = false;
    var revalidatingCurrentSelection = false;
    ForgeConversationPage? loadedPage;
    var loadedConversations = const <ForgeOwnedConversation>[];
    setState(() {
      _loadingConversations = true;
      _conversationError = null;
    });
    try {
      final page = await _api.listConversations(
        afterID: loadMore ? _nextAfterID : null,
      );
      loadedPage = page;
      if (!mounted || generation != _conversationGeneration) return false;
      var merged = _mergeConversations(
        incoming: page.conversations,
        existing: _conversations,
        append: loadMore,
      );
      loadedConversations = merged;
      final hasPendingSelection = _hasPendingLocationSelection;
      final pendingSelectionID = _takePendingLocationSelection();
      final wantedID = hasPendingSelection
          ? pendingSelectionID
          : selectID ?? _selected?.conversation.id;
      var selected = _findConversation(merged, wantedID);
      final canResolveOwnerSelection =
          _selectedClientInstanceID == null ||
          _conversationIDDeclaredBySelectedClientInstance(wantedID);
      if (selected == null &&
          wantedID != null &&
          (selectID != null || hasPendingSelection) &&
          !loadMore &&
          canResolveOwnerSelection) {
        // A deep link can point to an older session outside the first page.
        // Fetch only its owner-filtered metadata; this remains a read-only
        // selection and does not alter pagination or write authority.
        resolvingOwnerSelection = true;
        final linked = await _api.getConversation(conversationID: wantedID);
        resolvingOwnerSelection = false;
        if (!mounted || generation != _conversationGeneration) return false;
        merged = _mergeConversations(
          incoming: [linked, ...merged],
          existing: const [],
          append: false,
        );
        loadedConversations = merged;
        selected = linked;
      }
      if (selected == null &&
          !loadMore &&
          !hasPendingSelection &&
          selectID == null &&
          _selected != null) {
        // The first page can legitimately omit an older selected session, but
        // it can also omit one that was deleted or revoked. Re-read the
        // missing row through the authenticated owner detail path before
        // retaining it; blindly merging the previous selection would keep a
        // deleted session visible and permit stale Prompt/Run reads.
        final currentID = _selected!.conversation.id;
        if (_conversationIDDeclaredBySelectedClientInstance(currentID)) {
          revalidatingCurrentSelection = true;
          final linked = await _api.getConversation(conversationID: currentID);
          revalidatingCurrentSelection = false;
          if (!mounted || generation != _conversationGeneration) return false;
          merged = _mergeConversations(
            incoming: [linked, ...merged],
            existing: const [],
            append: false,
          );
          loadedConversations = merged;
          selected = _findConversation(merged, currentID);
        }
      }
      if (!hasPendingSelection && selectID == null) {
        selected ??= _selected;
        selected ??= merged.isEmpty ? null : merged.first;
      }
      final filterChanged =
          clientInstanceFilterGeneration != _clientInstanceFilterGeneration;
      if (filterChanged) {
        // A local instance selection happened while the owner page was in
        // flight. Preserve the selection chosen by that filter operation and
        // let it own Prompt/Run hydration; do not restore the stale page
        // selection from before the filter changed.
        selected = _selected;
      }
      if (!filterChanged && _selectedClientInstanceID != null) {
        // An instance deep link is a local projection boundary. Select only
        // a session declared by that observation, and keep private
        // Prompt/Run readers idle when the declaration is unavailable or
        // does not contain the requested session.
        final visible = _conversationsForClientInstance(
          merged,
          _declaredClientInstanceRows(),
          _selectedClientInstanceID,
        );
        selected =
            _findConversation(visible, selected?.conversation.id) ??
            (visible.isEmpty ? null : visible.first);
      }
      setState(() {
        _conversations = merged;
        _nextAfterID = page.nextAfterID;
        _hasMoreConversations = page.hasMore && page.nextAfterID != null;
        _selected = selected;
        _conversationsStale = false;
        _loadingConversations = false;
      });
      await _conversationMetadataCache.save(merged);
      if (!mounted || generation != _conversationGeneration) return false;
      if (!loadMore && selected != null && !filterChanged) {
        await _loadPrompts(selected.conversation.id);
        final runsLoaded = await _loadRuns(selected.conversation.id);
        await _loadExecutionConsentPreviewIfRequested(
          conversationID: selected.conversation.id,
        );
        if (loadPendingRunIntents) {
          await _loadPendingRunIntentsIfRequested();
        }
        return runsLoaded;
      } else if (selected == null || filterChanged) {
        if (filterChanged) return true;
        setState(() {
          _prompts = const [];
          _promptCursor = null;
          _hasMorePrompts = false;
          _runs = const [];
          _runCursor = null;
          _hasMoreRuns = false;
          _selectedRun = null;
          _runEvents = const [];
          _runTimelineSequence = 0;
          _hasMoreRunEvents = false;
          _loadingRuns = false;
          _loadingRunTimeline = false;
        });
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      final authorizationFailure = _isAuthorizationFailure(error);
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          (!authorizationFailure && generation != _conversationGeneration)) {
        return false;
      }
      if (authorizationFailure) {
        setState(() {
          _conversationError = _friendlyError(
            error,
            'Could not load Forge sessions.',
          );
          _loadingConversations = false;
        });
        return false;
      }
      // A same-document URL is only a selection hint. When its owner-scoped
      // detail lookup fails, keep the last successfully rendered session
      // snapshot and its Prompt/Run state instead of treating that failure as
      // a failed list read. The user can still retry through the normal
      // refresh path, while the inaccessible ID never becomes selected.
      final current = _conversations;
      if (resolvingOwnerSelection && current.isNotEmpty) {
        setState(() {
          _conversationError = _friendlyError(
            error,
            'Could not open the requested Forge session.',
          );
          _conversationsStale = false;
          _loadingConversations = false;
        });
        return false;
      }
      if (revalidatingCurrentSelection) {
        // The owner list was read successfully, but the missing selected row
        // could not be revalidated. Keep only the fresh list and clear all
        // private details, so a 404/foreign response or a transient detail
        // failure cannot leave the old session selected.
        final selectedID = _selected?.conversation.id;
        final fresh = loadedConversations
            .where((entry) => entry.conversation.id != selectedID)
            .toList(growable: false);
        setState(() {
          _conversations = List.unmodifiable(fresh);
          _nextAfterID = loadedPage?.nextAfterID;
          _hasMoreConversations =
              loadedPage?.hasMore == true && loadedPage?.nextAfterID != null;
          _selected = null;
          _conversationsStale = false;
          _conversationError = _friendlyError(
            error,
            'Could not verify the selected Forge session.',
          );
          _loadingConversations = false;
          _clearConversationDetails();
        });
        return false;
      }
      final canFallback = _canUseConversationMetadataCache(error);
      final cached = canFallback
          ? await _conversationMetadataCache.load()
          : null;
      if (!mounted) return false;
      // A failed older page must not discard the already rendered first page;
      // it is still authoritative local state and can be retried with the
      // same cursor. Deterministic failures on the initial snapshot clear
      // the list below instead of presenting it as an offline fallback.
      if (!canFallback && loadMore && current.isNotEmpty) {
        setState(() {
          _conversationError = _friendlyError(
            error,
            'Could not load Forge sessions.',
          );
          _conversationsStale = false;
          _loadingConversations = false;
        });
        return false;
      }
      final fallback = canFallback && current.isNotEmpty
          ? current
          : canFallback
          ? cached?.conversations
          : null;
      if (fallback != null) {
        final visibleFallback = _selectedClientInstanceID == null
            ? fallback
            : _conversationsForClientInstance(
                    fallback,
                    _declaredClientInstanceRows(),
                    _selectedClientInstanceID,
                  )
                  .where(
                    (entry) => fallback.any(
                      (candidate) =>
                          candidate.conversation.id == entry.conversation.id,
                    ),
                  )
                  .toList(growable: false);
        final selected =
            _findConversation(visibleFallback, _selected?.conversation.id) ??
            (visibleFallback.isEmpty ? null : visibleFallback.first);
        final restoringSnapshot = current.isEmpty;
        setState(() {
          _conversations = fallback;
          if (restoringSnapshot) {
            _nextAfterID = null;
            _hasMoreConversations = false;
          }
          _selected = selected;
          _conversationsStale = true;
          _conversationError = null;
          _loadingConversations = false;
          if (restoringSnapshot) _clearConversationDetails();
        });
        return false;
      }
      setState(() {
        if (!canFallback) {
          _conversations = const [];
          _selected = null;
          _nextAfterID = null;
          _hasMoreConversations = false;
          _clearConversationDetails();
        }
        _conversationError = _friendlyError(
          error,
          'Could not load Forge sessions.',
        );
        _conversationsStale = false;
        _loadingConversations = false;
      });
      return false;
    }
  }

  Future<void> _refreshAndSync() async {
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    final syncOutcome = await _syncChanges();
    final pendingReadDuringSync =
        syncOutcome == _ForgeChangeSyncOutcome.changed;
    if (syncOutcome == _ForgeChangeSyncOutcome.unchanged ||
        syncOutcome == _ForgeChangeSyncOutcome.changed) {
      _changePollFailureStreak = 0;
      _changePollDelay = _changePollBaseDelay;
    }
    if (mounted &&
        syncOutcome != _ForgeChangeSyncOutcome.advancedHidden &&
        _selectedClientInstanceProjectionReadyForOwnerReads()) {
      await _refreshConversations(loadPendingRunIntents: false);
    }
    if (mounted &&
        syncOutcome != _ForgeChangeSyncOutcome.advancedHidden &&
        (!pendingReadDuringSync || _fetchedPendingRunIntents == null)) {
      await _loadPendingRunIntentsIfRequested(force: true);
    }
    await Future.wait([
      _loadDeviceInventoryIfRequested(force: true),
      _loadDeviceInventoryV2IfRequested(force: true),
      _loadDeviceInventoryRegistryPlacementPreviewIfRequested(force: true),
    ]);
    await _loadSchedulerSelectionPreviewIfRequested(force: true);
    if (_selectedClientInstanceID == null) {
      await _loadClientInstanceSessionResourceConvergenceIfRequested(
        force: true,
      );
      await _loadClientInstanceSessionViewIfRequested(force: true);
      await _loadClientInstanceResourceViewIfRequested(force: true);
    }
    await _loadLifecycleRegistryIfRequested(force: true);
    await _loadExecutionConsentPreviewIfRequested(force: true);
    await _loadRunObservedIfRequested(force: true);
    await _loadRunAttemptLeaseDispatchPreflightIfRequested(force: true);
    await _loadRunnerDispatchPlanPreviewIfRequested(force: true);
    await _loadRunnerExecutionIntentIfRequested(force: true);
    await _loadRunnerDispatchAdmissionIfRequested(force: true);
    await _loadRunnerAttemptBoundaryIfRequested(force: true);
    await _loadLocalRunnerPreviewIfRequested(force: true);
    await _loadExecutionReconciliationIfRequested(force: true);
  }

  ForgeRunnerLeaseFencingFixture? _safeRunnerLeaseFencingPreview(
    ForgeRunnerLeaseFencingFixture? candidate,
  ) {
    if (candidate == null ||
        candidate.schemaVersion != forgeRunnerLeaseFencingSchema ||
        candidate.evaluationMode != forgeRunnerLeaseFencingEvaluationMode ||
        !candidate.authority.isOffline ||
        candidate.cases.length != 16) {
      return null;
    }
    return candidate;
  }

  ForgeRunnerAttemptBoundaryObservation? _safeRunnerAttemptBoundaryPreview(
    ForgeRunnerAttemptBoundaryObservation? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeRunnerAttemptBoundaryObservation.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeExecutionLeaseCheckpointFixture? _safeExecutionLeaseCheckpointPreview(
    ForgeExecutionLeaseCheckpointFixture? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeExecutionLeaseCheckpointFixture.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeSessionRunnerReceiptVectors? _safeSessionRunnerReceiptVectorsPreview(
    ForgeSessionRunnerReceiptVectors? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeSessionRunnerReceiptVectors.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeSessionRunnerReceiptHistory? _safeSessionRunnerReceiptHistoryPreview(
    ForgeSessionRunnerReceiptHistory? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeSessionRunnerReceiptHistory.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeSessionRunnerReconciliationProjection?
  _safeSessionRunnerReconciliationProjectionPreview(
    ForgeSessionRunnerReconciliationProjection? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeSessionRunnerReconciliationProjection.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceInventoryPageV2? _safeDeviceInventoryV2Preview(
    ForgeDeviceInventoryPageV2? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeDeviceInventoryPageV2.fromJson(candidate.toJson());
      return validated;
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceResourceSummaryFixture? _safeDeviceResourceSummaryPreview(
    ForgeDeviceResourceSummaryFixture? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeDeviceResourceSummaryFixture.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeClientInstanceResourceView? _safeClientInstanceResourceViewPreview(
    ForgeClientInstanceResourceView? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeClientInstanceResourceView.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeClientInstanceSessionView? _safeClientInstanceSessionViewPreview(
    ForgeClientInstanceSessionView? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeClientInstanceSessionView.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceInventoryPlacementEvaluationV2?
  _safeDeviceInventoryPlacementEvaluationV2Preview(
    ForgeDeviceInventoryPlacementEvaluationV2? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeDeviceInventoryPlacementEvaluationV2.fromJson(
        candidate.toJson(),
      );
      return validated.authority.anyGranted ||
              validated.selectedDeviceID != null ||
              validated.selectedInstanceID != null
          ? null
          : validated;
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceInventoryPlacementEvaluationFixture?
  _safeDeviceInventoryPlacementEvaluationPreview(
    ForgeDeviceInventoryPlacementEvaluationFixture? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeDeviceInventoryPlacementEvaluationFixture.fromJson(
        _placementEvaluationJson(candidate),
      );
      return validated.authority.anyGranted ? null : validated;
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceInventoryPlacementBatchEvaluationFixture?
  _safeDeviceInventoryPlacementBatchEvaluationPreview(
    ForgeDeviceInventoryPlacementBatchEvaluationFixture? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated =
          ForgeDeviceInventoryPlacementBatchEvaluationFixture.fromJson(
            _batchEvaluationJson(candidate),
          );
      return validated.authority.anyGranted ||
              validated.selectedDeviceID != null ||
              validated.selectedInstanceID != null
          ? null
          : validated;
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> _batchEvaluationJson(
    ForgeDeviceInventoryPlacementBatchEvaluationFixture value,
  ) => {
    'schema_version': value.schemaVersion,
    'evaluation_mode': value.evaluationMode,
    'source_fixture': value.sourceFixture,
    'evaluation_owner': value.evaluationOwner.toJson(),
    'evaluated_at_ms': value.evaluatedAtMS,
    'requirements': value.requirements.toJson(),
    'cases': value.cases
        .map(
          (item) => {
            'name': item.name,
            'source_case': item.sourceCase,
            'device_id': item.deviceID,
            'instance_id': item.instanceID,
            if (item.snapshotObservedAtMS != null)
              'snapshot_observed_at_ms': item.snapshotObservedAtMS,
            if (item.capabilityLeaseExpiresAtMS != null)
              'capability_lease_expires_at_ms': item.capabilityLeaseExpiresAtMS,
            'expected': {
              'revision': item.expected.revision,
              'device_id': item.expected.deviceID,
              'instance_id': item.expected.instanceID,
              'matches_requirements': item.expected.matchesRequirements,
              'exclusion_reasons': item.expected.exclusionReasons,
            },
          },
        )
        .toList(growable: false),
    'empty_inputs_allowed': value.emptyInputsAllowed,
    'selected_device_id': value.selectedDeviceID,
    'selected_instance_id': value.selectedInstanceID,
    'authority': {
      'identity_verified': value.authority.identityVerified,
      'heartbeat_persisted': value.authority.heartbeatPersisted,
      'inventory_authoritative': value.authority.inventoryAuthoritative,
      'placement_selected': value.authority.placementSelected,
      'reservation_created': value.authority.reservationCreated,
      'execution_authorized': value.authority.executionAuthorized,
      'dispatch_performed': value.authority.dispatchPerformed,
    },
    'error_cases': value.errorCases
        .map((item) => {'name': item.name, 'error': item.error})
        .toList(growable: false),
  };

  Map<String, dynamic> _placementEvaluationJson(
    ForgeDeviceInventoryPlacementEvaluationFixture value,
  ) => {
    'schema_version': value.schemaVersion,
    'evaluation_mode': value.evaluationMode,
    'source_fixture': value.sourceFixture,
    'source_case': value.sourceCase,
    'evaluated_at_ms': value.evaluatedAtMS,
    'policy_requirements': value.policyRequirements.toJson(),
    'authority': value.authority.toJson(),
    'expected': value.expected.toJson(),
  };

  Future<void> _importRunnerAttemptBoundaryPreview() async {
    if (_loadingRunnerAttemptBoundaryPreview ||
        !widget.enableRunnerAttemptBoundaryProjection ||
        widget.runnerAttemptBoundaryScope == null) {
      return;
    }
    setState(() {
      _loadingRunnerAttemptBoundaryPreview = true;
      _runnerAttemptBoundaryPreviewError = null;
      _runnerAttemptBoundaryPreview = null;
    });
    try {
      final reader = widget.runnerAttemptBoundaryFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: forgeRunnerAttemptBoundaryMaxInputBytes,
              ))();
      if (source == null) return;
      final observation = ForgeRunnerAttemptBoundaryObservation.fromJsonText(
        source,
      );
      final selectedConversationID = _selected?.conversation.id;
      final selectedRunID = _selectedRun?.runID;
      final scope = widget.runnerAttemptBoundaryScope!;
      if (!observation.isDisplayOnly ||
          !scope.matches(observation) ||
          !scope.matchesSelected(selectedConversationID, selectedRunID)) {
        throw const FormatException(
          'Runner Attempt boundary projection is outside the selected scope.',
        );
      }
      if (!mounted) return;
      setState(() => _runnerAttemptBoundaryPreview = observation);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _runnerAttemptBoundaryPreview = null;
        _runnerAttemptBoundaryPreviewError =
            'Invalid or stale Runner Attempt boundary projection.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingRunnerAttemptBoundaryPreview = false);
      }
    }
  }

  Future<void> _importRunnerLeaseFencingPreview() async {
    if (_loadingRunnerLeaseFencing) return;
    setState(() {
      _loadingRunnerLeaseFencing = true;
      _runnerLeaseFencingError = null;
    });
    try {
      final reader = widget.runnerLeaseFencingFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final fixture = ForgeRunnerLeaseFencingFixture.fromJsonText(source);
      if (_safeRunnerLeaseFencingPreview(fixture) == null) {
        throw const FormatException(
          'Runner lease fixture is not an offline 16-case contract.',
        );
      }
      if (!mounted) return;
      setState(() => _runnerLeaseFencingPreview = fixture);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _runnerLeaseFencingError =
            'Invalid or unavailable Runner lease/fencing preview.';
      });
    } finally {
      if (mounted) setState(() => _loadingRunnerLeaseFencing = false);
    }
  }

  Future<void> _importExecutionLeaseCheckpointPreview() async {
    if (_loadingExecutionLeaseCheckpoint) return;
    setState(() {
      _loadingExecutionLeaseCheckpoint = true;
      _executionLeaseCheckpointError = null;
    });
    try {
      final reader = widget.executionLeaseCheckpointFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final fixture = ForgeExecutionLeaseCheckpointFixture.fromJsonText(source);
      if (_safeExecutionLeaseCheckpointPreview(fixture) == null) {
        throw const FormatException(
          'Execution lease checkpoint is not an offline four-case contract.',
        );
      }
      if (!mounted) return;
      setState(() => _executionLeaseCheckpointPreview = fixture);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _executionLeaseCheckpointError =
            'Invalid or unavailable execution-lease checkpoint preview.';
      });
    } finally {
      if (mounted) setState(() => _loadingExecutionLeaseCheckpoint = false);
    }
  }

  Future<void> _importSessionRunnerReceiptVectorsPreview() async {
    if (_loadingSessionRunnerReceiptVectorsPreview) return;
    setState(() {
      _loadingSessionRunnerReceiptVectorsPreview = true;
      _sessionRunnerReceiptVectorsPreviewError = null;
    });
    try {
      final reader = widget.sessionRunnerReceiptVectorsFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final fixture = ForgeSessionRunnerReceiptVectors.fromJsonText(source);
      if (_safeSessionRunnerReceiptVectorsPreview(fixture) == null) {
        throw const FormatException(
          'Session Runner receipt vectors are not display-only.',
        );
      }
      if (!mounted) return;
      setState(() => _sessionRunnerReceiptVectorsPreview = fixture);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessionRunnerReceiptVectorsPreviewError =
            'Invalid or unavailable session Runner receipt vectors.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSessionRunnerReceiptVectorsPreview = false);
      }
    }
  }

  Future<void> _importSessionRunnerReceiptHistoryPreview() async {
    if (_loadingSessionRunnerReceiptHistoryPreview) return;
    setState(() {
      _loadingSessionRunnerReceiptHistoryPreview = true;
      _sessionRunnerReceiptHistoryPreviewError = null;
    });
    try {
      final reader = widget.sessionRunnerReceiptHistoryFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final history = ForgeSessionRunnerReceiptHistory.fromJsonText(source);
      if (_safeSessionRunnerReceiptHistoryPreview(history) == null) {
        throw const FormatException(
          'Session Runner receipt history is not display-only.',
        );
      }
      if (!mounted) return;
      setState(() => _sessionRunnerReceiptHistoryPreview = history);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessionRunnerReceiptHistoryPreviewError =
            'Invalid or unavailable session Runner receipt history.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSessionRunnerReceiptHistoryPreview = false);
      }
    }
  }

  Future<void> _importSessionRunnerReconciliationProjectionPreview() async {
    if (_loadingSessionRunnerReconciliationProjectionPreview) return;
    setState(() {
      _loadingSessionRunnerReconciliationProjectionPreview = true;
      _sessionRunnerReconciliationProjectionPreviewError = null;
    });
    try {
      final reader = widget.sessionRunnerReconciliationProjectionFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final projection =
          ForgeSessionRunnerReconciliationProjection.fromJsonText(source);
      if (_safeSessionRunnerReconciliationProjectionPreview(projection) ==
          null) {
        throw const FormatException(
          'Session Runner reconciliation projection is not display-only.',
        );
      }
      if (!mounted) return;
      setState(
        () => _sessionRunnerReconciliationProjectionPreview = projection,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessionRunnerReconciliationProjectionPreviewError =
            'Invalid or unavailable session Runner reconciliation projection.';
      });
    } finally {
      if (mounted) {
        setState(
          () => _loadingSessionRunnerReconciliationProjectionPreview = false,
        );
      }
    }
  }

  Future<void> _importDeviceInventoryV2Preview() async {
    if (_loadingDeviceInventoryV2Preview) return;
    setState(() {
      _loadingDeviceInventoryV2Preview = true;
      _deviceInventoryV2PreviewError = null;
    });
    try {
      final reader = widget.deviceInventoryV2FileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final page = ForgeDeviceInventoryPageV2.fromJsonText(source);
      if (_safeDeviceInventoryV2Preview(page) == null) {
        throw const FormatException(
          'Device inventory v2 is not a display-only observation.',
        );
      }
      if (!mounted) return;
      setState(() => _deviceInventoryV2Preview = page);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deviceInventoryV2PreviewError =
            'Invalid or unavailable v2 device inventory preview.';
      });
    } finally {
      if (mounted) setState(() => _loadingDeviceInventoryV2Preview = false);
    }
  }

  Future<void> _importDeviceResourceSummaryPreview() async {
    if (_loadingDeviceResourceSummaryPreview) return;
    setState(() {
      _loadingDeviceResourceSummaryPreview = true;
      _deviceResourceSummaryPreviewError = null;
    });
    try {
      final reader = widget.deviceResourceSummaryFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final fixture = ForgeDeviceResourceSummaryFixture.fromJsonText(source);
      if (_safeDeviceResourceSummaryPreview(fixture) == null) {
        throw const FormatException(
          'Device resource summary is not a display-only aggregate.',
        );
      }
      if (!mounted) return;
      setState(() => _deviceResourceSummaryPreview = fixture);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deviceResourceSummaryPreviewError =
            'Invalid or unavailable device resource summary preview.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingDeviceResourceSummaryPreview = false);
      }
    }
  }

  Future<void> _importClientInstanceResourceViewPreview() async {
    if (_loadingClientInstanceResourceViewPreview) return;
    setState(() {
      _loadingClientInstanceResourceViewPreview = true;
      _clientInstanceResourceViewPreviewError = null;
    });
    try {
      final reader = widget.clientInstanceResourceViewFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final view = ForgeClientInstanceResourceView.fromJsonText(source);
      if (_safeClientInstanceResourceViewPreview(view) == null) {
        throw const FormatException(
          'Client-instance resource view is not display-only.',
        );
      }
      if (!mounted) return;
      setState(() => _clientInstanceResourceViewPreview = view);
      _reconcileSelectedClientInstanceProjection();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _clientInstanceResourceViewPreviewError =
            'Invalid or unavailable client-instance resource view preview.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingClientInstanceResourceViewPreview = false);
      }
    }
  }

  Future<void> _importClientInstanceSessionViewPreview() async {
    if (_loadingClientInstanceSessionViewPreview) return;
    setState(() {
      _loadingClientInstanceSessionViewPreview = true;
      _clientInstanceSessionViewPreviewError = null;
    });
    try {
      final reader = widget.clientInstanceSessionViewFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final view = ForgeClientInstanceSessionView.fromJsonText(source);
      if (_safeClientInstanceSessionViewPreview(view) == null) {
        throw const FormatException(
          'Client-instance session view is not display-only.',
        );
      }
      if (!mounted) return;
      setState(() => _clientInstanceSessionViewPreview = view);
      _reconcileSelectedClientInstanceProjection();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _clientInstanceSessionViewPreviewError =
            'Invalid or unavailable client-instance session view preview.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingClientInstanceSessionViewPreview = false);
      }
    }
  }

  Future<void> _importDeviceInventoryPlacementEvaluationV2Preview() async {
    if (_loadingDeviceInventoryPlacementEvaluationV2Preview) return;
    setState(() {
      _loadingDeviceInventoryPlacementEvaluationV2Preview = true;
      _deviceInventoryPlacementEvaluationV2PreviewError = null;
    });
    try {
      final reader = widget.deviceInventoryPlacementEvaluationV2FileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final evaluation = ForgeDeviceInventoryPlacementEvaluationV2.fromJsonText(
        source,
      );
      if (_safeDeviceInventoryPlacementEvaluationV2Preview(evaluation) ==
          null) {
        throw const FormatException(
          'Device placement evaluation is not a display-only comparison.',
        );
      }
      if (!mounted) return;
      setState(() => _deviceInventoryPlacementEvaluationV2Preview = evaluation);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deviceInventoryPlacementEvaluationV2PreviewError =
            'Invalid or unavailable v2 device placement preview.';
      });
    } finally {
      if (mounted) {
        setState(
          () => _loadingDeviceInventoryPlacementEvaluationV2Preview = false,
        );
      }
    }
  }

  Future<void> _importDeviceInventoryPlacementEvaluationPreview() async {
    if (_loadingDeviceInventoryPlacementEvaluationPreview) return;
    setState(() {
      _loadingDeviceInventoryPlacementEvaluationPreview = true;
      _deviceInventoryPlacementEvaluationPreviewError = null;
    });
    try {
      final reader = widget.deviceInventoryPlacementEvaluationFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final evaluation =
          ForgeDeviceInventoryPlacementEvaluationFixture.fromJsonText(source);
      if (_safeDeviceInventoryPlacementEvaluationPreview(evaluation) == null) {
        throw const FormatException(
          'Device placement evaluation is not a display-only comparison.',
        );
      }
      if (!mounted) return;
      setState(() => _deviceInventoryPlacementEvaluationPreview = evaluation);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deviceInventoryPlacementEvaluationPreviewError =
            'Invalid or unavailable device placement evaluation preview.';
      });
    } finally {
      if (mounted) {
        setState(
          () => _loadingDeviceInventoryPlacementEvaluationPreview = false,
        );
      }
    }
  }

  Future<void> _importDeviceInventoryPlacementBatchEvaluationPreview() async {
    if (_loadingDeviceInventoryPlacementBatchEvaluationPreview) return;
    setState(() {
      _loadingDeviceInventoryPlacementBatchEvaluationPreview = true;
      _deviceInventoryPlacementBatchEvaluationPreviewError = null;
    });
    try {
      final reader = widget.deviceInventoryPlacementBatchEvaluationFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final evaluation =
          ForgeDeviceInventoryPlacementBatchEvaluationFixture.fromJsonText(
            source,
          );
      if (_safeDeviceInventoryPlacementBatchEvaluationPreview(evaluation) ==
          null) {
        throw const FormatException(
          'Placement batch evaluation is not a display-only comparison.',
        );
      }
      if (!mounted) return;
      setState(
        () => _deviceInventoryPlacementBatchEvaluationPreview = evaluation,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deviceInventoryPlacementBatchEvaluationPreviewError =
            'Invalid or unavailable placement batch preview.';
      });
    } finally {
      if (mounted) {
        setState(
          () => _loadingDeviceInventoryPlacementBatchEvaluationPreview = false,
        );
      }
    }
  }

  bool _canUseConversationMetadataCache(Object error) =>
      error is ForgeConversationsApiException &&
      (error.statusCode == 0 || error.statusCode >= 500);

  void _clearConversationDetails({bool clearOwnerObservations = true}) {
    _promptGeneration++;
    _runGeneration++;
    _runTimelineGeneration++;
    _clearDeviceObservation();
    if (clearOwnerObservations) {
      // Inventory and registry placement are owner-scoped screen resources,
      // rather than Conversation details. A local client-instance filter can
      // change the selected Conversation without invalidating these images;
      // sign-out, authorization failure, and route reset keep the default
      // clearing behavior.
      _clearDeviceInventory();
      _clearDeviceInventoryV2();
      _clearDeviceInventoryRegistryPlacementPreview();
    }
    _clearSchedulerSelectionPreview();
    // Client-instance/resource and client-instance/session observations are
    // owner-level projections for the whole screen, not Conversation detail.
    // Keep them mounted while switching Conversations so an instance filter
    // remains available when it selects a different visible session.
    _clearDeviceCredentialCandidate();
    _clearRunAttemptLeaseDispatchPreflight();
    _clearRunnerDispatchPlanPreview();
    _clearRunnerAttemptBoundaryPreview();
    _clearRunnerAttemptBoundary();
    _clearRunnerExecutionIntent();
    _clearRunnerDispatchAdmission();
    _clearExecutionReconciliation();
    _clearExecutionConsentPreview();
    _clearRunObserved();
    _clearRunExecutionEvidence();
    _clearSessionRunnerReceiptHistory();
    _clearSessionRunnerReconciliationProjection();
    _clearPendingRunIntents();
    _pendingRunIntentSubmission = null;
    _pendingRunIntentRequest = null;
    _pendingRunIntentSubmitError = null;
    _submittingPendingRunIntent = false;
    _pendingPrompt = null;
    _appendError = null;
    _appending = false;
    _clearImportedRunObservations();
    _prompts = const [];
    _promptCursor = null;
    _hasMorePrompts = false;
    _promptError = null;
    _loadingPrompts = false;
    _runs = const [];
    _runCursor = null;
    _hasMoreRuns = false;
    _selectedRun = null;
    _runEvents = const [];
    _runTimelineSequence = 0;
    _hasMoreRunEvents = false;
    _loadingRuns = false;
    _loadingRunTimeline = false;
  }

  /// Clears Run and Run-adjacent metadata when the selected local
  /// client-instance projection no longer declares the Conversation. The
  /// owner session itself remains selected so the caller can reselect it when
  /// the projection changes; no private Run request is allowed in the gap.
  void _clearRunDetailsForHiddenClientInstance() {
    _clientInstanceFilterNeedsPrivateReload = true;
    _promptGeneration++;
    _runGeneration++;
    _runTimelineGeneration++;
    _clearDeviceObservation();
    _clearRunAttemptLeaseDispatchPreflight();
    _clearSchedulerSelectionPreview();
    _clearRunnerDispatchPlanPreview();
    _clearRunnerAttemptBoundaryPreview();
    _clearRunnerAttemptBoundary();
    _clearRunnerExecutionIntent();
    _clearRunnerDispatchAdmission();
    _clearLocalRunnerPreview();
    _clearExecutionReconciliation();
    _clearRunObserved();
    _clearRunExecutionEvidence();
    _clearSessionRunnerReceiptHistory();
    _clearSessionRunnerReconciliationProjection();
    _clearExecutionConsentPreview();
    _clearPendingRunIntents();
    _pendingRunIntentSubmission = null;
    _pendingRunIntentRequest = null;
    _pendingRunIntentSubmitError = null;
    _submittingPendingRunIntent = false;
    _pendingPrompt = null;
    _appendError = null;
    _appending = false;
    _clearImportedRunObservations();
    _prompts = const [];
    _promptCursor = null;
    _hasMorePrompts = false;
    _promptError = null;
    _loadingPrompts = false;
    _runs = const [];
    _runCursor = null;
    _hasMoreRuns = false;
    _selectedRun = null;
    _runEvents = const [];
    _runTimelineSequence = 0;
    _hasMoreRunEvents = false;
    _runError = null;
    _runTimelineError = null;
    _loadingRuns = false;
    _loadingRunTimeline = false;
  }

  /// Revokes owner Prompt/Run state as soon as a refreshed local
  /// client-instance projection no longer declares the selected conversation.
  /// The selection itself remains a bookmark, but a later projection refresh
  /// must not resurrect the old private metadata without a new owner read.
  void _reconcileSelectedClientInstanceProjection() {
    final conversationID = _selected?.conversation.id;
    if (_selectedClientInstanceID == null || conversationID == null) return;
    if (_conversationVisibleFromSelectedClientInstance(conversationID)) return;
    if (mounted) setState(_clearRunDetailsForHiddenClientInstance);
  }

  void _clearDeviceObservation() {
    _deviceObservationGeneration++;
    _fetchedDeviceObservation = null;
    _importedDeviceObservation = null;
    _deviceObservationError = null;
    _deviceObservationKey = null;
    _loadingDeviceObservation = false;
  }

  void _clearDeviceInventory() {
    _deviceInventoryGeneration++;
    _fetchedDeviceInventory = null;
    _deviceInventoryError = null;
    _deviceInventoryStale = false;
    _loadingDeviceInventory = false;
  }

  void _clearDeviceInventoryV2() {
    _deviceInventoryV2Generation++;
    _fetchedDeviceInventoryV2 = null;
    _deviceInventoryV2Error = null;
    _deviceInventoryV2Stale = false;
    _loadingDeviceInventoryV2 = false;
  }

  void _clearDeviceInventoryResourceConvergence() {
    _deviceInventoryResourceConvergenceGeneration++;
    _fetchedDeviceInventoryResourceConvergence = null;
    _deviceInventoryResourceConvergenceError = null;
    _deviceInventoryResourceConvergenceStale = false;
    _loadingDeviceInventoryResourceConvergence = false;
    if (_selectedClientInstanceID != null) {
      _clearRunDetailsForHiddenClientInstance();
    }
  }

  void _clearDeviceInventoryRegistryPlacementPreview() {
    _deviceInventoryRegistryPlacementPreviewGeneration++;
    _fetchedDeviceInventoryRegistryPlacementPreview = null;
    _deviceInventoryRegistryPlacementPreviewError = null;
    _deviceInventoryRegistryPlacementPreviewStale = false;
    _loadingDeviceInventoryRegistryPlacementPreview = false;
  }

  void _clearSchedulerSelectionPreview() {
    _schedulerSelectionPreviewGeneration++;
    _fetchedSchedulerSelectionPreview = null;
    _schedulerSelectionPreviewError = null;
    _schedulerSelectionPreviewStale = false;
    _loadingSchedulerSelectionPreview = false;
  }

  void _clearSchedulerSelectionLease() {
    _schedulerSelectionLeaseGeneration++;
    _fetchedSchedulerSelectionLease = null;
    _schedulerSelectionLeaseError = null;
    _schedulerSelectionLeaseStale = false;
    _loadingSchedulerSelectionLease = false;
  }

  void _clearSchedulerSelectionLeaseRelease() {
    _schedulerSelectionLeaseReleaseGeneration++;
    _fetchedSchedulerSelectionLeaseRelease = null;
    _schedulerSelectionLeaseReleaseError = null;
    _schedulerSelectionLeaseReleaseStale = false;
    _loadingSchedulerSelectionLeaseRelease = false;
  }

  void _clearClientInstanceResourceView() {
    final hadActiveClientInstanceFilter = _selectedClientInstanceID != null;
    _clientInstanceResourceViewGeneration++;
    _fetchedClientInstanceResourceView = null;
    _clientInstanceResourceViewError = null;
    _clientInstanceResourceViewStale = false;
    _loadingClientInstanceResourceView = false;
    // Resource metadata drives the same local instance projection when no
    // dedicated session view is supplied. Revoke private Prompt/Run details
    // during a reader gap instead of allowing a restored resource declaration
    // to resurrect state fetched under the old projection.
    if (hadActiveClientInstanceFilter) {
      _clearRunDetailsForHiddenClientInstance();
    }
  }

  void _clearClientInstanceSessionView() {
    final hadActiveClientInstanceFilter = _selectedClientInstanceID != null;
    _clientInstanceSessionViewGeneration++;
    _fetchedClientInstanceSessionView = null;
    _clientInstanceSessionViewError = null;
    _clientInstanceSessionViewStale = false;
    _loadingClientInstanceSessionView = false;
    // Keep an active local filter while its session projection is being
    // revoked or replaced. Clearing it would broaden the list back to every
    // owner conversation during the gap; revoke the private Prompt/Run
    // details and let the renderer keep the projection empty until a new
    // declaration is available.
    if (hadActiveClientInstanceFilter) {
      _clearRunDetailsForHiddenClientInstance();
    }
  }

  void _clearClientInstanceSessionResourceConvergence() {
    _clientInstanceSessionResourceConvergenceGeneration++;
    _fetchedClientInstanceSessionResourceConvergence = null;
    _clientInstanceSessionResourceConvergenceError = null;
    _clientInstanceSessionResourceConvergenceStale = false;
    _loadingClientInstanceSessionResourceConvergence = false;
  }

  void _clearLifecycleRegistry() {
    _lifecycleRegistryGeneration++;
    _fetchedLifecycleRegistry = null;
    _lifecycleRegistryError = null;
    _lifecycleRegistryStale = false;
    _loadingLifecycleRegistry = false;
  }

  void _clearDeviceCredentialCandidate() {
    _deviceCredentialCandidateGeneration++;
    _fetchedDeviceCredentialCandidate = null;
    _deviceCredentialCandidateError = null;
    _deviceCredentialCandidateStale = false;
    _loadingDeviceCredentialCandidate = false;
  }

  /// Returns the owner-scoped conversations visible from one caller-declared
  /// client instance. The instance declaration is an observation only; an
  /// unknown instance or session simply produces an empty local projection.
  /// No server request or authority decision is made here.
  List<ForgeOwnedConversation> conversationsForClientInstance(
    Iterable<ForgeClientInstanceSessionViewInstance>? instances,
    String? instanceID,
  ) => _conversationsForClientInstance(_conversations, instances, instanceID);

  List<ForgeOwnedConversation> _conversationsForClientInstance(
    Iterable<ForgeOwnedConversation> source,
    Iterable<ForgeClientInstanceSessionViewInstance>? instances,
    String? instanceID,
  ) {
    if (instanceID == null) return source.toList(growable: false);
    if (instances == null) return const [];
    ForgeClientInstanceSessionViewInstance? instance;
    for (final candidate in instances) {
      if (candidate.instanceID == instanceID) {
        instance = candidate;
        break;
      }
    }
    if (instance == null) return const [];
    final sessionIDs = instance.sessionIDs.toSet();
    return source
        .where((entry) => sessionIDs.contains(entry.conversation.id))
        .toList(growable: false);
  }

  Iterable<ForgeClientInstanceSessionViewInstance>?
  _declaredClientInstanceRows() {
    final sessionView =
        _strictClientInstanceSessionView(
          widget.clientInstanceSessionViewPreview,
        ) ??
        _strictClientInstanceSessionView(_fetchedClientInstanceSessionView) ??
        _strictClientInstanceSessionView(_clientInstanceSessionViewPreview);
    final resourceView =
        _strictClientInstanceResourceView(
          widget.clientInstanceResourceViewPreview,
        ) ??
        _strictClientInstanceResourceView(_fetchedClientInstanceResourceView) ??
        _strictClientInstanceResourceView(_clientInstanceResourceViewPreview) ??
        _fetchedClientInstanceSessionResourceConvergence?.resourceView ??
        _fetchedDeviceInventoryResourceConvergence?.resourceView;

    // When the caller opted into two independent readers, neither response
    // can define the local filter by itself. During a reader gap or a
    // mismatched refresh, return no declaration so a selected instance cannot
    // broaden back to the owner-wide session list or hydrate private state
    // from a mixed snapshot. The combined reader already performs this join
    // before populating both fetched views.
    if (_independentClientInstanceReadersConfigured) {
      if (sessionView == null ||
          resourceView == null ||
          _loadingClientInstanceSessionView ||
          _loadingClientInstanceResourceView ||
          _clientInstanceSessionViewError != null ||
          _clientInstanceResourceViewError != null ||
          _clientInstanceSessionViewStale ||
          _clientInstanceResourceViewStale ||
          !forgeClientInstanceSessionResourceObservationsConverged(
            sessionView,
            resourceView,
          )) {
        return null;
      }
    }
    return sessionView?.instances ?? resourceView?.instances;
  }

  bool get _independentClientInstanceReadersConfigured =>
      widget.clientInstanceSessionViewOwner != null &&
      widget.clientInstanceSessionViewReader != null &&
      widget.clientInstanceResourceViewOwner != null &&
      widget.clientInstanceResourceViewReader != null;

  bool _conversationIDDeclaredBySelectedClientInstance(String? conversationID) {
    if (conversationID == null || _selectedClientInstanceID == null) {
      return true;
    }
    final rows = _declaredClientInstanceRows();
    if (rows == null) return false;
    for (final row in rows) {
      if (row.instanceID == _selectedClientInstanceID &&
          row.sessionIDs.contains(conversationID)) {
        return true;
      }
    }
    return false;
  }

  /// Selects a local client-instance session filter. Any change invalidates
  /// the private Prompt/Run projection, including when a shared Conversation
  /// remains visible from both instances; if the current session is outside
  /// the selected instance, select the first visible owner session so the
  /// Prompt panel cannot continue showing a hidden row.
  void selectClientInstanceFilter(
    Iterable<ForgeClientInstanceSessionViewInstance>? instances,
    String? instanceID,
  ) {
    final visible = conversationsForClientInstance(instances, instanceID);
    final currentID = _selected?.conversation.id;
    final currentVisible = visible.any(
      (entry) => entry.conversation.id == currentID,
    );
    final filterChanged = _selectedClientInstanceID != instanceID;
    _clientInstanceFilterGeneration++;
    setState(() {
      _selectedClientInstanceID = instanceID;
      if (!currentVisible) {
        _selected = null;
        _clearConversationDetails(clearOwnerObservations: false);
      } else if (filterChanged) {
        // A shared Conversation can be declared by more than one client
        // instance. Changing the local projection still requires a fresh
        // private read, even when the selected row remains visible. Keep the
        // owner-scoped observation panels mounted; only Prompt/Run state is
        // invalidated at this display boundary.
        _clearRunDetailsForHiddenClientInstance();
      }
    });
    if (visible.isNotEmpty && !currentVisible) {
      unawaited(_selectConversation(visible.first));
    }
  }

  /// Returns an explanatory error when the explicit Prompt journey is not
  /// backed by a fresh, owner-bound inventory/resource observation. This
  /// guard is disabled by default and only composes the already opt-in
  /// display readers; it never grants or infers Prompt authority.
  String? get _promptAppendInventoryResourceConvergenceError {
    final separateObservationError = _inventoryResourceObservationErrorFor(
      'Prompt append',
    );
    if (separateObservationError != null) return separateObservationError;
    if (!widget.requireDeviceInventoryResourceConvergenceForPromptAppend) {
      return null;
    }
    final inventoryOwner = widget.deviceInventoryResourceConvergenceOwner;
    final inventoryReader = widget.deviceInventoryResourceConvergenceReader;
    if (inventoryOwner == null || inventoryReader == null) {
      return 'Prompt append is waiting for an explicit inventory/resource convergence reader.';
    }
    final inventoryConvergence = _fetchedDeviceInventoryResourceConvergence;
    if (inventoryConvergence == null ||
        _loadingDeviceInventoryResourceConvergence ||
        _deviceInventoryResourceConvergenceError != null ||
        _deviceInventoryResourceConvergenceStale) {
      return 'Prompt append is waiting for a fresh validated inventory/resource observation.';
    }

    final sessionPairOwner =
        widget.clientInstanceSessionResourceConvergenceOwner;
    final sessionPairReader =
        widget.clientInstanceSessionResourceConvergenceReader;
    if (sessionPairOwner != null && sessionPairReader != null) {
      final sessionPair = _fetchedClientInstanceSessionResourceConvergence;
      if (sessionPair == null ||
          _loadingClientInstanceSessionResourceConvergence ||
          _clientInstanceSessionResourceConvergenceError != null ||
          _clientInstanceSessionResourceConvergenceStale) {
        return 'Prompt append is waiting for a fresh validated session/resource observation.';
      }
      if (sessionPair.owner != inventoryConvergence.owner ||
          jsonEncode(sessionPair.resourceView.toJson()) !=
              jsonEncode(inventoryConvergence.resourceView.toJson())) {
        return 'Prompt append is disabled because session/resource and inventory/resource observations do not converge.';
      }
    } else {
      final resourceOwner = widget.clientInstanceResourceViewOwner;
      final resourceReader = widget.clientInstanceResourceViewReader;
      if (resourceOwner != null && resourceReader != null) {
        if (_fetchedClientInstanceResourceView == null ||
            _loadingClientInstanceResourceView ||
            _clientInstanceResourceViewError != null ||
            _clientInstanceResourceViewStale) {
          return 'Prompt append is waiting for a fresh validated resource observation.';
        }
        if (jsonEncode(_fetchedClientInstanceResourceView!.toJson()) !=
            jsonEncode(inventoryConvergence.resourceView.toJson())) {
          return 'Prompt append is disabled because the client resource observation does not converge with inventory.';
        }
      }
      final sessionOwner = widget.clientInstanceSessionViewOwner;
      final sessionReader = widget.clientInstanceSessionViewReader;
      if (sessionOwner != null && sessionReader != null) {
        if (_fetchedClientInstanceSessionView == null ||
            _loadingClientInstanceSessionView ||
            _clientInstanceSessionViewError != null ||
            _clientInstanceSessionViewStale) {
          return 'Prompt append is waiting for a fresh validated session observation.';
        }
        final sessionView = _fetchedClientInstanceSessionView!;
        final sessionInstances = sessionView.instances
            .map((instance) => instance.toJson())
            .toList(growable: false);
        final resourceInstances = inventoryConvergence.resourceView.instances
            .map((instance) => instance.toJson())
            .toList(growable: false);
        if (sessionView.owner != inventoryConvergence.owner ||
            jsonEncode(sessionInstances) != jsonEncode(resourceInstances)) {
          return 'Prompt append is disabled because session and inventory observations do not converge.';
        }
      }
    }
    final selectedInstanceID = _selectedClientInstanceID;
    if (selectedInstanceID != null &&
        !inventoryConvergence.resourceView.instances.any(
          (instance) => instance.instanceID == selectedInstanceID,
        )) {
      return 'Prompt append is disabled because the selected client instance is absent from the validated resource observation.';
    }
    return null;
  }

  bool get _separateInventoryResourceObservationsConfigured {
    final inventoryConfigured =
        widget.deviceInventoryOwner != null &&
        widget.deviceInventoryV2Reader != null;
    final resourceConfigured =
        (widget.clientInstanceSessionResourceConvergenceOwner != null &&
            widget.clientInstanceSessionResourceConvergenceReader != null) ||
        (widget.clientInstanceResourceViewOwner != null &&
            widget.clientInstanceResourceViewReader != null);
    return inventoryConfigured && resourceConfigured;
  }

  String? _inventoryResourceObservationErrorFor(String operation) {
    if (!_separateInventoryResourceObservationsConfigured) return null;
    final inventory = _fetchedDeviceInventoryV2;
    final resource = _fetchedClientInstanceResourceView;
    if (inventory == null ||
        resource == null ||
        _loadingDeviceInventoryV2 ||
        _loadingClientInstanceResourceView ||
        _loadingClientInstanceSessionResourceConvergence ||
        _deviceInventoryV2Error != null ||
        _clientInstanceResourceViewError != null ||
        _clientInstanceSessionResourceConvergenceError != null ||
        _deviceInventoryV2Stale ||
        _clientInstanceResourceViewStale ||
        _clientInstanceSessionResourceConvergenceStale) {
      return '$operation is waiting for a fresh validated inventory/resource observation.';
    }
    if (!forgeDeviceInventoryAndResourceObservationsConverged(
      inventory,
      resource,
    )) {
      return '$operation blocked by inventory/resource observation drift. No request was sent.';
    }
    return null;
  }

  Future<String?> _refreshInventoryResourceObservationsBeforeOperation(
    String operation, {
    bool force = false,
  }) async {
    final combinedConfigured =
        widget.deviceInventoryResourceConvergenceOwner != null &&
        widget.deviceInventoryResourceConvergenceReader != null;
    if (!_separateInventoryResourceObservationsConfigured &&
        !combinedConfigured) {
      return null;
    }
    if (combinedConfigured) {
      final current = _fetchedDeviceInventoryResourceConvergence;
      if (force ||
          current == null ||
          _loadingDeviceInventoryResourceConvergence ||
          _deviceInventoryResourceConvergenceError != null ||
          _deviceInventoryResourceConvergenceStale) {
        await _loadDeviceInventoryResourceConvergenceIfRequested(force: true);
      }
      if (!mounted || _authorizationInvalidated) {
        return '$operation was cancelled.';
      }
      final refreshed = _fetchedDeviceInventoryResourceConvergence;
      if (refreshed == null ||
          _loadingDeviceInventoryResourceConvergence ||
          _deviceInventoryResourceConvergenceError != null ||
          _deviceInventoryResourceConvergenceStale) {
        return '$operation is waiting for a fresh validated inventory/resource observation.';
      }

      // A composed inventory/resource response proves that its own device
      // rows converge, but it does not prove that a separately read
      // client-instance pair still describes the same resource image. Keep
      // the selected Sessions surface and the scheduling boundary on one
      // owner-bound snapshot before any candidate POST is allowed.
      final sessionPairConfigured =
          widget.clientInstanceSessionResourceConvergenceOwner != null &&
          widget.clientInstanceSessionResourceConvergenceReader != null;
      if (sessionPairConfigured) {
        final sessionPair = _fetchedClientInstanceSessionResourceConvergence;
        if (sessionPair == null ||
            _loadingClientInstanceSessionResourceConvergence ||
            _clientInstanceSessionResourceConvergenceError != null ||
            _clientInstanceSessionResourceConvergenceStale) {
          return '$operation is waiting for a fresh validated session/resource observation.';
        }
        if (sessionPair.owner != refreshed.owner ||
            jsonEncode(sessionPair.resourceView.toJson()) !=
                jsonEncode(refreshed.resourceView.toJson())) {
          return '$operation blocked by inventory/resource observation drift. No request was sent.';
        }
      } else {
        final resourceConfigured =
            widget.clientInstanceResourceViewOwner != null &&
            widget.clientInstanceResourceViewReader != null;
        if (resourceConfigured) {
          final resource = _fetchedClientInstanceResourceView;
          if (resource == null ||
              _loadingClientInstanceResourceView ||
              _clientInstanceResourceViewError != null ||
              _clientInstanceResourceViewStale) {
            return '$operation is waiting for a fresh validated session/resource observation.';
          }
          if (resource.owner != refreshed.owner ||
              jsonEncode(resource.toJson()) !=
                  jsonEncode(refreshed.resourceView.toJson())) {
            return '$operation blocked by inventory/resource observation drift. No request was sent.';
          }
        }
        final sessionConfigured =
            widget.clientInstanceSessionViewOwner != null &&
            widget.clientInstanceSessionViewReader != null;
        if (sessionConfigured) {
          final session = _fetchedClientInstanceSessionView;
          if (session == null ||
              _loadingClientInstanceSessionView ||
              _clientInstanceSessionViewError != null ||
              _clientInstanceSessionViewStale) {
            return '$operation is waiting for a fresh validated session/resource observation.';
          }
          final sessionInstances = session.instances
              .map((instance) => instance.toJson())
              .toList(growable: false);
          final resourceInstances = refreshed.resourceView.instances
              .map((instance) => instance.toJson())
              .toList(growable: false);
          if (session.owner != refreshed.owner ||
              jsonEncode(sessionInstances) != jsonEncode(resourceInstances)) {
            return '$operation blocked by inventory/resource observation drift. No request was sent.';
          }
        }
      }
      return null;
    }
    // A successful owner-scoped refresh already establishes the proof used by
    // this write boundary. Reusing that current, converged image avoids
    // starting a second pair of real HTTP reads in the same frame (which can
    // race the scheduled poll on Web/App/Mobile), while any missing, stale,
    // failed, or drifted image still takes the forced refresh path below.
    final currentError = _inventoryResourceObservationErrorFor(operation);
    if (!force && currentError == null) return null;
    await _loadDeviceInventoryV2IfRequested(force: true);
    if (widget.clientInstanceSessionResourceConvergenceOwner != null &&
        widget.clientInstanceSessionResourceConvergenceReader != null) {
      await _loadClientInstanceSessionResourceConvergenceIfRequested(
        force: true,
      );
    } else {
      await _loadClientInstanceResourceViewIfRequested(force: true);
    }
    if (!mounted || _authorizationInvalidated) {
      return '$operation was cancelled.';
    }
    final refreshedError = _inventoryResourceObservationErrorFor(operation);
    return refreshedError;
  }

  void _clearRunAttemptLeaseDispatchPreflight() {
    _runAttemptLeaseDispatchPreflightGeneration++;
    _fetchedRunAttemptLeaseDispatchPreflight = null;
    _runAttemptLeaseDispatchPreflightError = null;
    _runAttemptLeaseDispatchPreflightStale = false;
    _loadingRunAttemptLeaseDispatchPreflight = false;
  }

  void _clearRunnerDispatchPlanPreview() {
    _runnerDispatchPlanPreviewGeneration++;
    _fetchedRunnerDispatchPlanPreview = null;
    _runnerDispatchPlanPreviewError = null;
    _runnerDispatchPlanPreviewStale = false;
    _loadingRunnerDispatchPlanPreview = false;
  }

  void _clearRunnerExecutionIntent() {
    _runnerExecutionIntentGeneration++;
    _fetchedRunnerExecutionIntent = null;
    _runnerExecutionIntentError = null;
    _runnerExecutionIntentStale = false;
    _loadingRunnerExecutionIntent = false;
  }

  void _clearRunnerDispatchAdmission() {
    _runnerDispatchAdmissionGeneration++;
    _fetchedRunnerDispatchAdmission = null;
    _runnerDispatchAdmissionError = null;
    _runnerDispatchAdmissionStale = false;
    _loadingRunnerDispatchAdmission = false;
  }

  void _clearRunnerTransportAdmission() {
    _runnerTransportAdmissionGeneration++;
    _fetchedRunnerTransportAdmission = null;
    _runnerTransportAdmissionError = null;
    _runnerTransportAdmissionStale = false;
    _loadingRunnerTransportAdmission = false;
  }

  void _clearRunnerExecutionBoundary() {
    _runnerExecutionBoundaryGeneration++;
    _fetchedRunnerExecutionBoundary = null;
    _runnerExecutionBoundaryError = null;
    _runnerExecutionBoundaryStale = false;
    _loadingRunnerExecutionBoundary = false;
  }

  void _clearRunnerAttemptBoundary() {
    _runnerAttemptBoundaryGeneration++;
    _fetchedRunnerAttemptBoundary = null;
    _runnerAttemptBoundaryError = null;
    _runnerAttemptBoundaryStale = false;
    _loadingRunnerAttemptBoundary = false;
  }

  void _clearRunnerAttemptBoundaryPreview() {
    _runnerAttemptBoundaryPreview = null;
    _runnerAttemptBoundaryPreviewError = null;
    _loadingRunnerAttemptBoundaryPreview = false;
  }

  void _clearLocalRunnerPreview() {
    _localRunnerPreviewGeneration++;
    _fetchedLocalRunnerPreview = null;
    _localRunnerPreviewError = null;
    _localRunnerPreviewStale = false;
    _loadingLocalRunnerPreview = false;
  }

  ForgeLocalRunnerPreviewObservation? _strictLocalRunnerPreview(
    ForgeLocalRunnerPreviewObservation? candidate,
  ) {
    final request = widget.localRunnerPreviewRequest;
    final conversationID = _selected?.conversation.id;
    final runID = _selectedRun?.runID;
    if (candidate == null ||
        request == null ||
        conversationID == null ||
        runID == null) {
      return null;
    }
    if (request.intent.conversationID != conversationID ||
        request.intent.run.runID != runID) {
      return null;
    }
    try {
      final validated = ForgeLocalRunnerPreviewObservation.fromJson(
        candidate.toJson(),
        request: request,
        conversationID: conversationID,
        intentID: request.intent.prompt.intentID,
      );
      return validated.runnerExecutionIntent.runID == runID ? validated : null;
    } catch (_) {
      return null;
    }
  }

  void _clearExecutionReconciliation() {
    _executionReconciliationGeneration++;
    _fetchedExecutionReconciliationObservation = null;
    _executionReconciliationError = null;
    _executionReconciliationStale = false;
    _loadingExecutionReconciliation = false;
  }

  void _clearExecutionConsentPreview() {
    _executionConsentPreviewGeneration++;
    _fetchedExecutionConsentPreview = null;
    _executionConsentPreviewError = null;
    _executionConsentPreviewStale = false;
    _loadingExecutionConsentPreview = false;
  }

  void _clearRunObserved() {
    _runObservedGeneration++;
    _fetchedRunObserved = null;
    _fetchedSessionRunnerReceiptObservation = null;
    _runObservedError = null;
    _runObservedStale = false;
    _loadingRunObserved = false;
  }

  void _clearRunExecutionEvidence() {
    _runExecutionEvidenceGeneration++;
    _fetchedRunExecutionEvidence = null;
    _runExecutionEvidenceError = null;
    _runExecutionEvidenceStale = false;
    _loadingRunExecutionEvidence = false;
  }

  void _clearSessionRunnerReceiptHistory() {
    _sessionRunnerReceiptHistoryGeneration++;
    _fetchedSessionRunnerReceiptHistory = null;
    _sessionRunnerReceiptHistoryError = null;
    _sessionRunnerReceiptHistoryStale = false;
    _loadingSessionRunnerReceiptHistory = false;
  }

  void _clearSessionRunnerReconciliationProjection() {
    _sessionRunnerReconciliationProjectionGeneration++;
    _fetchedSessionRunnerReconciliationProjection = null;
    _sessionRunnerReconciliationProjectionError = null;
    _sessionRunnerReconciliationProjectionStale = false;
    _loadingSessionRunnerReconciliationProjection = false;
  }

  void _clearPendingRunIntents() {
    _pendingRunIntentGeneration++;
    _fetchedPendingRunIntents = null;
    _pendingRunIntentError = null;
    _loadingPendingRunIntents = false;
    _loadingMorePendingRunIntents = false;
    _clearPendingRunIntentTimelines();
  }

  void _clearPendingRunIntentTimelines() {
    _pendingRunIntentTimelineGeneration++;
    _fetchedPendingRunIntentTimelines.clear();
    _pendingRunIntentTimelineErrors.clear();
    _loadingPendingRunIntentTimelines.clear();
  }

  bool _sameDeviceObservationRequest(
    ForgeSessionPlacementRequest? left,
    ForgeSessionPlacementRequest? right,
  ) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return false;
    return jsonEncode(left.toJson()) == jsonEncode(right.toJson());
  }

  bool _sameDeviceCredentialCandidateRequest(
    ForgeDeviceCredentialLifecycleRequest? left,
    ForgeDeviceCredentialLifecycleRequest? right,
  ) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return false;
    return jsonEncode(left.toJson()) == jsonEncode(right.toJson());
  }

  /// Imported Runner observations are scoped to the currently selected Run.
  /// They stay process-local and must not reappear when navigation changes
  /// the Conversation or clears the selection.
  void _clearImportedRunObservations() {
    _importedRunnerExecutionIntentObservation = null;
    _importedSessionRunnerReceiptObservation = null;
  }

  Future<_ForgeChangeSyncOutcome> _syncChanges({bool stream = false}) async {
    if (_syncingChanges ||
        !mounted ||
        _sessionViewInvalidated ||
        _authorizationInvalidated) {
      return _ForgeChangeSyncOutcome.skipped;
    }
    _syncingChanges = true;
    try {
      // Refresh the selected client-instance projection before the owner
      // change feed can trigger Conversation, Prompt, or Run reads. A
      // changed session/resource declaration must revoke the old projection
      // before any private metadata is hydrated under it.
      if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
        return _ForgeChangeSyncOutcome.failed;
      }
      await _cursorReady;
      if (!mounted) return _ForgeChangeSyncOutcome.skipped;
      final changes = <ForgeConversationChange>[];
      var nextCursor = _changeCursor;
      if (stream) {
        final page = await _api.conversationChangesStream(
          afterCursor: nextCursor,
          limit: ForgeConversationsApi.maxPageSize,
          waitMS: widget.conversationChangesStreamWaitMS,
        );
        if (!mounted) return _ForgeChangeSyncOutcome.skipped;
        if (page == null) {
          // A bounded 204 timeout is a successful read with no cursor
          // progress. The caller reconnects the stream without touching the
          // persisted cursor.
          if (_changeError != null) setState(() => _changeError = null);
          await _syncRunObservation();
          return _ForgeChangeSyncOutcome.unchanged;
        }
        if (page.scannedThroughCursor < nextCursor) {
          throw const FormatException('Forge change cursor regressed.');
        }
        nextCursor = page.scannedThroughCursor;
        changes.addAll(page.changes);
      } else {
        for (var pageNumber = 0; pageNumber < 4; pageNumber++) {
          final page = await _api.conversationChanges(
            afterCursor: nextCursor,
            limit: ForgeConversationsApi.maxPageSize,
          );
          if (!mounted) return _ForgeChangeSyncOutcome.skipped;
          if (page.scannedThroughCursor < nextCursor) {
            throw const FormatException('Forge change cursor regressed.');
          }
          nextCursor = page.scannedThroughCursor;
          changes.addAll(page.changes);
          if (!page.hasMore) break;
        }
      }
      if (_changeError != null) setState(() => _changeError = null);
      // The transport is deliberately owner-scoped, so the cursor must
      // advance across every row returned by the owner feed.  An explicitly
      // selected client instance is a narrower local projection, however:
      // rows whose Conversation is not declared by that instance must not
      // update the visible aggregate or trigger Prompt/Run hydration.  Keep
      // the two sets separate so hidden rows are acknowledged without being
      // rendered as instance-local activity.
      final visibleChanges = _conversationChangesVisibleFromSelectedInstance(
        changes,
      );
      if (visibleChanges.isEmpty) {
        if (nextCursor != _changeCursor) {
          // Persist owner-feed progress even when this page contained only
          // rows outside the selected instance.  This prevents hidden rows
          // from being replayed forever while keeping their private metadata
          // out of the selected projection.
          if (!await _changeCursorStore.save(nextCursor)) {
            return _ForgeChangeSyncOutcome.failed;
          }
          if (!mounted) return _ForgeChangeSyncOutcome.skipped;
          _changeCursor = nextCursor;
          return _ForgeChangeSyncOutcome.advancedHidden;
        }
        final selectedID = _selected?.conversation.id;
        if (_promptError != null && selectedID != null) {
          if (!await _loadPrompts(selectedID)) {
            return _ForgeChangeSyncOutcome.failed;
          }
        }
        await _syncRunObservation();
        return _ForgeChangeSyncOutcome.unchanged;
      }

      final latestByConversation = <String, ForgeConversationChange>{};
      var createdConversation = false;
      for (final change in visibleChanges) {
        final prior = latestByConversation[change.conversationID];
        if (prior == null || change.aggregateVersion > prior.aggregateVersion) {
          latestByConversation[change.conversationID] = change;
        }
        createdConversation |= change.kind == 'conversation_created';
      }
      final updated = _conversations
          .map((entry) {
            final change = latestByConversation[entry.conversation.id];
            if (change == null ||
                change.aggregateVersion <= entry.aggregateVersion) {
              return entry;
            }
            return _withConversationChange(entry, change);
          })
          .toList(growable: false);
      final loadedConversationIDs = _conversations
          .map((entry) => entry.conversation.id)
          .toSet();
      final hasUnloadedConversationChange = latestByConversation.keys.any(
        (conversationID) => !loadedConversationIDs.contains(conversationID),
      );
      final selectedID = _selected?.conversation.id;
      final selectedChange = selectedID == null
          ? null
          : latestByConversation[selectedID];
      setState(() {
        _conversations = updated;
        if (selectedChange != null &&
            selectedChange.aggregateVersion >
                (_selected?.aggregateVersion ?? 0)) {
          _selected = _withConversationChange(_selected!, selectedChange);
          _conversations = _replaceConversation(_conversations, _selected!);
        }
      });
      if (createdConversation || hasUnloadedConversationChange) {
        // A dense feed can contain a prompt append for a conversation outside
        // the currently loaded page. Advance the cursor only after a fresh
        // owner snapshot succeeds, otherwise that change could be consumed
        // without ever making the session metadata visible locally.
        if (!await _refreshConversations(loadPendingRunIntents: false)) {
          await _syncRunObservation();
          return _ForgeChangeSyncOutcome.failed;
        }
      } else if (selectedChange?.kind == 'prompt_appended') {
        if (!await _loadPrompts(selectedID!)) {
          await _syncRunObservation();
          return _ForgeChangeSyncOutcome.failed;
        }
      }
      if (!mounted) return _ForgeChangeSyncOutcome.skipped;
      await _syncRunObservation();
      if (!mounted) return _ForgeChangeSyncOutcome.skipped;
      await _loadPendingRunIntentsIfRequested(force: true);
      if (!mounted) return _ForgeChangeSyncOutcome.skipped;
      // Persist the owner-local checkpoint before publishing it to the
      // in-process state. A storage failure must leave the old cursor in
      // memory so the next transport attempt replays the uncommitted page.
      if (!await _changeCursorStore.save(nextCursor)) {
        return _ForgeChangeSyncOutcome.failed;
      }
      if (!mounted) return _ForgeChangeSyncOutcome.skipped;
      _changeCursor = nextCursor;
      return _ForgeChangeSyncOutcome.changed;
    } catch (error) {
      await _clearSessionIfUnauthorized(error);
      if (mounted) {
        setState(() {
          _changeError = _friendlyError(
            error,
            'Could not sync Forge sessions.',
          );
        });
      }
      return _ForgeChangeSyncOutcome.failed;
    } finally {
      _syncingChanges = false;
    }
  }

  List<ForgeConversationChange> _conversationChangesVisibleFromSelectedInstance(
    Iterable<ForgeConversationChange> changes,
  ) {
    if (_selectedClientInstanceID == null) {
      return changes.toList(growable: false);
    }
    return changes
        .where(
          (change) => _conversationIDDeclaredBySelectedClientInstance(
            change.conversationID,
          ),
        )
        .toList(growable: false);
  }

  Future<bool>
  _refreshSelectedClientInstanceProjectionBeforeOwnerReads() async {
    if (_selectedClientInstanceID == null) return true;
    await _loadClientInstanceSessionResourceConvergenceIfRequested(force: true);
    await _loadClientInstanceSessionViewIfRequested(force: true);
    await _loadClientInstanceResourceViewIfRequested(force: true);
    return _selectedClientInstanceProjectionReadyForOwnerReads();
  }

  bool _selectedClientInstanceProjectionReadyForOwnerReads() {
    if (_selectedClientInstanceID == null) return true;

    final pairConfigured =
        widget.clientInstanceSessionResourceConvergenceOwner != null &&
        widget.clientInstanceSessionResourceConvergenceReader != null;
    if (pairConfigured &&
        (_fetchedClientInstanceSessionResourceConvergence == null ||
            _loadingClientInstanceSessionResourceConvergence ||
            _clientInstanceSessionResourceConvergenceError != null ||
            _clientInstanceSessionResourceConvergenceStale)) {
      return false;
    }

    final sessionConfigured =
        widget.clientInstanceSessionViewOwner != null &&
        widget.clientInstanceSessionViewReader != null;
    if (sessionConfigured &&
        (_fetchedClientInstanceSessionView == null ||
            _loadingClientInstanceSessionView ||
            _clientInstanceSessionViewError != null ||
            _clientInstanceSessionViewStale)) {
      return false;
    }

    final resourceConfigured =
        widget.clientInstanceResourceViewOwner != null &&
        widget.clientInstanceResourceViewReader != null;
    if (resourceConfigured &&
        (_fetchedClientInstanceResourceView == null ||
            _loadingClientInstanceResourceView ||
            _clientInstanceResourceViewError != null ||
            _clientInstanceResourceViewStale)) {
      return false;
    }

    if (_independentClientInstanceReadersConfigured) {
      final sessionView = _fetchedClientInstanceSessionView;
      final resourceView = _fetchedClientInstanceResourceView;
      if (sessionView == null ||
          resourceView == null ||
          !forgeClientInstanceSessionResourceObservationsConverged(
            sessionView,
            resourceView,
          )) {
        return false;
      }
    }

    // A selected instance still needs a validated local declaration when the
    // caller supplied only a process-local preview. Unknown or missing rows
    // fail closed and cannot widen the owner session surface. The latest
    // observation must still contain the selected instance; an empty row set
    // is a revocation and cannot authorize another owner-feed read.
    final rows = _declaredClientInstanceRows();
    if (rows == null) return false;
    return rows.any((row) => row.instanceID == _selectedClientInstanceID);
  }

  Future<void> _syncRunObservation() async {
    final conversationID = _selected?.conversation.id;
    if (conversationID == null || _loadingRuns || _loadingRunTimeline) return;
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      if (mounted) setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }

    final runGeneration = _runGeneration;
    var timelineGeneration = _runTimelineGeneration;
    final selectedRunID = _selectedRun?.runID;
    bool isCurrent() =>
        mounted &&
        _selected?.conversation.id == conversationID &&
        _runGeneration == runGeneration &&
        _runTimelineGeneration == timelineGeneration &&
        _conversationVisibleFromSelectedClientInstance(conversationID);

    void revokeIfHidden() {
      if (mounted &&
          _selected?.conversation.id == conversationID &&
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        setState(_clearRunDetailsForHiddenClientInstance);
      }
    }

    late final ForgeConversationRunPage runPage;
    try {
      runPage = await _api.listRuns(conversationID: conversationID);
    } catch (error) {
      if (!mounted ||
          _selected?.conversation.id != conversationID ||
          _runGeneration != runGeneration ||
          _runTimelineGeneration != timelineGeneration ||
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        revokeIfHidden();
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted || !isCurrent()) {
        revokeIfHidden();
        return;
      }
      if (_dropSelectedConversationAfterOwnerReadFailure(
        conversationID,
        error,
      )) {
        if (!mounted) return;
        setState(() {
          _runError = _friendlyError(error, 'Could not load runs.');
        });
        return;
      }
      setState(() {
        _runError = _friendlyError(error, 'Could not load runs.');
      });
      return;
    }
    if (!isCurrent()) {
      revokeIfHidden();
      return;
    }

    final mergedRuns = _uniqueRuns([..._runs, ...runPage.runs]);
    final selectedRun = selectedRunID == null
        ? (mergedRuns.isEmpty ? null : mergedRuns.first)
        : _findRun(mergedRuns, selectedRunID);
    final selectionChanged = selectedRun?.runID != selectedRunID;
    if (selectionChanged) {
      timelineGeneration = ++_runTimelineGeneration;
    }
    setState(() {
      _runs = mergedRuns;
      _selectedRun = selectedRun;
      _runCursor ??= runPage.nextCursor;
      _hasMoreRuns = _runCursor == null
          ? false
          : _hasMoreRuns || runPage.hasMore;
      _runError = null;
      if (selectionChanged) {
        _clearDeviceObservation();
        _clearRunObserved();
        _clearImportedRunObservations();
        _clearRunnerDispatchPlanPreview();
        _clearRunnerAttemptBoundaryPreview();
        _clearRunnerAttemptBoundary();
        _clearRunnerDispatchAdmission();
        _clearRunnerExecutionBoundary();
        _runEvents = const [];
        _runTimelineSequence = 0;
        _hasMoreRunEvents = false;
        _runTimelineError = null;
      }
    });
    if (selectedRun == null) return;

    var afterSequence = _runTimelineSequence;
    if (afterSequence == 0) {
      afterSequence = await _runTimelineCursor(
        conversationID,
        selectedRun.runID,
      ).load();
      if (!isCurrent() || _selectedRun?.runID != selectedRun.runID) {
        revokeIfHidden();
        return;
      }
    }
    try {
      final timelinePage = await _api.listRunTimeline(
        conversationID: conversationID,
        runID: selectedRun.runID,
        afterSequence: afterSequence,
      );
      if (!isCurrent() || _selectedRun?.runID != selectedRun.runID) {
        revokeIfHidden();
        return;
      }
      setState(() {
        _runEvents = _uniqueRunEvents([..._runEvents, ...timelinePage.events]);
        _runTimelineSequence = timelinePage.scannedThroughSequence;
        _hasMoreRunEvents = timelinePage.hasMore;
        _runTimelineError = null;
      });
      await _runTimelineCursor(
        conversationID,
        selectedRun.runID,
      ).save(timelinePage.scannedThroughSequence);
      await _loadDeviceObservationIfRequested(
        conversationID,
        selectedRun.runID,
      );
      await _loadRunObservedIfRequested(
        conversationID: conversationID,
        runID: selectedRun.runID,
        // A scheduled change-feed poll can call this path without the outer
        // manual/resume refresh. Force the explicit reader so a selected Run
        // observation cannot remain cached after its timeline advances.
        force: true,
      );
      await _loadRunnerDispatchPlanPreviewIfRequested(
        conversationID: conversationID,
        runID: selectedRun.runID,
        force: true,
      );
      await _loadRunnerExecutionIntentIfRequested(
        conversationID: conversationID,
        runID: selectedRun.runID,
        force: true,
      );
      await _loadRunnerDispatchAdmissionIfRequested(
        conversationID: conversationID,
        runID: selectedRun.runID,
        force: true,
      );
      await _loadLocalRunnerPreviewIfRequested(
        conversationID: conversationID,
        runID: selectedRun.runID,
        force: true,
      );
      await _loadSessionRunnerReceiptHistoryIfRequested(
        conversationID: conversationID,
        runID: selectedRun.runID,
        force: true,
      );
      await _loadSessionRunnerReconciliationProjectionIfRequested(
        conversationID: conversationID,
        runID: selectedRun.runID,
        force: true,
      );
    } catch (error) {
      if (!isCurrent() || _selectedRun?.runID != selectedRun.runID) {
        revokeIfHidden();
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted) return;
      if (_dropSelectedConversationAfterOwnerReadFailure(
        conversationID,
        error,
      )) {
        if (!mounted) return;
        setState(() {
          _runTimelineError = _friendlyError(
            error,
            'Could not load run timeline.',
          );
        });
        return;
      }
      setState(() {
        _runTimelineError = _friendlyError(
          error,
          'Could not load run timeline.',
        );
      });
    }
  }

  ForgeOwnedConversation _withConversationChange(
    ForgeOwnedConversation entry,
    ForgeConversationChange change,
  ) => ForgeOwnedConversation(
    conversation: ForgeConversation(
      id: entry.conversation.id,
      scope: entry.conversation.scope,
      title: entry.conversation.title,
      createdAtMS: entry.conversation.createdAtMS,
      updatedAtMS: change.createdAtMS > entry.conversation.updatedAtMS
          ? change.createdAtMS
          : entry.conversation.updatedAtMS,
    ),
    aggregateVersion: change.aggregateVersion,
  );

  Future<bool> _loadPrompts(
    String conversationID, {
    bool loadOlder = false,
  }) async {
    // The client-instance envelope is a local display projection. Once a
    // caller has selected an instance, every Prompt/history read must pass
    // through the same projection before reaching the owner API. This also
    // covers refresh/feed updates and the "load older" cursor path, which can
    // otherwise outlive the conversation tile that originally triggered it.
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      if (mounted) {
        setState(() {
          _prompts = const [];
          _promptCursor = null;
          _hasMorePrompts = false;
          _promptError = null;
          _loadingPrompts = false;
        });
      }
      return false;
    }
    final generation = ++_promptGeneration;
    setState(() {
      _loadingPrompts = true;
      _promptError = null;
    });
    try {
      final page = await _api.listPrompts(
        conversationID: conversationID,
        before: loadOlder ? _promptCursor : null,
      );
      if (!mounted ||
          generation != _promptGeneration ||
          _selected?.conversation.id != conversationID) {
        return false;
      }
      // A refresh caused by the owner change feed must not discard older
      // Prompt history that the user already loaded. Keep the deepest cursor
      // we have seen while merging the newest page by Prompt ID; the initial
      // load still takes its cursor directly from the service.
      final hadOlderHistory = !loadOlder && _promptCursor != null;
      final prompts = loadOlder
          ? [...page.prompts, ..._prompts]
          : [..._prompts, ...page.prompts];
      prompts.sort(_comparePrompts);
      final nextCursor = hadOlderHistory ? _promptCursor : page.nextCursor;
      final hasMore = hadOlderHistory ? _hasMorePrompts : page.hasMore;
      setState(() {
        _prompts = _uniquePrompts(prompts);
        _promptCursor = nextCursor;
        _hasMorePrompts = hasMore && nextCursor != null;
        _loadingPrompts = false;
        _clientInstanceFilterNeedsPrivateReload = false;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      final authorizationFailure = _isAuthorizationFailure(error);
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          (!authorizationFailure && generation != _promptGeneration)) {
        return false;
      }
      if (_dropSelectedConversationAfterOwnerReadFailure(
        conversationID,
        error,
      )) {
        if (!mounted) return false;
        setState(() {
          _promptError = _friendlyError(
            error,
            'Could not load prompt history.',
          );
          _loadingPrompts = false;
        });
        return false;
      }
      setState(() {
        _promptError = _friendlyError(error, 'Could not load prompt history.');
        _loadingPrompts = false;
      });
      return false;
    }
  }

  Future<void> _restoreChangeCursor() async {
    _changeCursor = await _changeCursorStore.load();
  }

  ForgeRunTimelineCursorStore _runTimelineCursor(
    String conversationID,
    String runID,
  ) => ForgeRunTimelineCursorStore(
    accessToken: widget.accessToken,
    apiOrigin: widget.apiOrigin,
    clientId: ForgeConversationsOAuth.clientId,
    resource: ForgeConversationsOAuth.resource,
    conversationID: conversationID,
    runID: runID,
  );

  Future<void> _createConversation() async {
    if (_creating || _appending || _pendingPrompt != null) return;
    final pending = _pendingCreate ?? _readCreateRequest();
    if (pending == null) return;
    setState(() {
      _pendingCreate = pending;
      _creating = true;
      _createError = null;
    });
    // A selected client instance is a local display projection. Refresh its
    // owner-bound observation before creating so a reader gap cannot turn the
    // owner-wide storage write into a private instance selection.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _createError =
            'Conversation create is blocked until the selected client instance is observed.';
      });
      return;
    }
    try {
      final created = await _api.createConversation(
        scope: pending.scope,
        title: pending.title,
        idempotencyKey: pending.idempotencyKey,
      );
      if (!mounted) return;
      final createdVisible = _conversationIDDeclaredBySelectedClientInstance(
        created.id,
      );
      final previousSelection = _selected;
      final retainedSelection =
          previousSelection != null &&
              _conversationIDDeclaredBySelectedClientInstance(
                previousSelection.conversation.id,
              )
          ? previousSelection
          : null;
      // A new conversation's creation event establishes aggregate version 1.
      final selected = ForgeOwnedConversation(
        conversation: created,
        aggregateVersion: 1,
      );
      setState(() {
        _runGeneration++;
        _runTimelineGeneration++;
        _clearDeviceObservation();
        _clearPendingRunIntents();
        _clearImportedRunObservations();
        _loadingRuns = false;
        _loadingRunTimeline = false;
        _pendingCreate = null;
        _pendingPrompt = null;
        _creating = false;
        _appendError = null;
        _titleController.clear();
        _scopeIDController.clear();
        _selected = createdVisible ? selected : retainedSelection;
        _createError = createdVisible
            ? null
            : 'Created conversation "${created.id}", but the selected client instance has not declared it yet.';
        _conversations = _mergeConversations(
          incoming: [selected, ..._conversations],
          existing: const [],
          append: false,
        );
        _prompts = const [];
        _promptCursor = null;
        _runs = const [];
        _runCursor = null;
        _hasMoreRuns = false;
        _selectedRun = null;
        _runEvents = const [];
        _runTimelineSequence = 0;
        _hasMoreRunEvents = false;
      });
      if (!createdVisible) {
        if (retainedSelection != null) {
          _updateConversationLocation(retainedSelection.conversation.id);
        }
        return;
      }
      _updateConversationLocation(created.id);
      await _loadPrompts(created.id);
      await _loadRuns(created.id);
      await _loadPendingRunIntentsIfRequested();
    } catch (error) {
      if (!mounted) return;
      await _clearSessionIfUnauthorized(error);
      final terminal = _isDefinitiveWriteFailure(error);
      setState(() {
        if (terminal) _pendingCreate = null;
        _createError = _friendlyError(
          error,
          'Forge did not confirm conversation creation.',
        );
        _creating = false;
      });
    }
  }

  _PendingCreate? _readCreateRequest() {
    final title = _titleController.text.trim();
    final scopeID = _scopeIDController.text.trim();
    if (title.isEmpty) {
      setState(() => _createError = 'Enter a conversation title.');
      return null;
    }
    if (_scopeKind != 'global' && scopeID.isEmpty) {
      setState(() => _createError = 'Enter a project or group ID.');
      return null;
    }
    return _PendingCreate(
      title: title,
      scope: ForgeConversationScope(
        kind: _scopeKind,
        id: _scopeKind == 'global' ? null : scopeID,
      ),
      idempotencyKey: newForgeIdempotencyKey(),
    );
  }

  Future<void> _selectConversation(
    ForgeOwnedConversation value, {
    bool updateLocation = true,
    int? locationGeneration,
  }) async {
    if (!_conversationVisibleFromSelectedClientInstance(
      value.conversation.id,
    )) {
      return;
    }
    if (_appending ||
        _pendingPrompt != null ||
        (!_clientInstanceFilterNeedsPrivateReload &&
            _selected?.conversation.id == value.conversation.id)) {
      return;
    }
    setState(() {
      _runGeneration++;
      _runTimelineGeneration++;
      _clearDeviceObservation();
      _clearRunAttemptLeaseDispatchPreflight();
      _clearRunnerDispatchPlanPreview();
      _clearRunnerAttemptBoundaryPreview();
      _clearRunnerAttemptBoundary();
      _clearRunnerDispatchAdmission();
      _clearExecutionReconciliation();
      _clearExecutionConsentPreview();
      _clearPendingRunIntents();
      _clearImportedRunObservations();
      _loadingRuns = false;
      _loadingRunTimeline = false;
      _selected = value;
      _prompts = const [];
      _promptCursor = null;
      _hasMorePrompts = false;
      _promptError = null;
      _appendError = null;
      _pendingPrompt = null;
      _pendingRunIntentSubmission = null;
      _pendingRunIntentRequest = null;
      _pendingRunIntentSubmitError = null;
      _submittingPendingRunIntent = false;
      _runs = const [];
      _runCursor = null;
      _hasMoreRuns = false;
      _selectedRun = null;
      _runEvents = const [];
      _runTimelineSequence = 0;
      _hasMoreRunEvents = false;
      _runError = null;
      _runTimelineError = null;
    });
    if (updateLocation) {
      _updateConversationLocation(value.conversation.id);
    }
    final promptsLoaded = await _loadPrompts(value.conversation.id);
    if (!mounted ||
        (locationGeneration != null &&
            locationGeneration != _locationSelectionGeneration) ||
        _selected?.conversation.id != value.conversation.id ||
        !promptsLoaded) {
      return;
    }
    await _loadRuns(value.conversation.id);
    await _loadExecutionConsentPreviewIfRequested(
      conversationID: value.conversation.id,
    );
    await _loadPendingRunIntentsIfRequested();
  }

  bool _conversationVisibleFromSelectedClientInstance(String conversationID) {
    final instanceID = _selectedClientInstanceID;
    if (instanceID == null) return true;
    final instances = _declaredClientInstanceRows();
    return instances != null &&
        conversationsForClientInstance(
          instances,
          instanceID,
        ).any((entry) => entry.conversation.id == conversationID);
  }

  /// Keeps scheduler candidates inside the same local instance projection as
  /// Conversations and Prompt writes. A selected instance with no validated
  /// rows fails closed, so a refresh gap cannot broaden a candidate POST.
  bool _schedulerSelectionRequestVisible(String conversationID) =>
      _conversationVisibleFromSelectedClientInstance(conversationID);

  bool _schedulerSelectionTargetMatchesResources(
    ForgeSchedulerSelectionPreview preview,
  ) {
    if (!preview.selectionAvailable) return true;
    final resourceView =
        _strictClientInstanceResourceView(
          widget.clientInstanceResourceViewPreview,
        ) ??
        _strictClientInstanceResourceView(_fetchedClientInstanceResourceView) ??
        _strictClientInstanceResourceView(_clientInstanceResourceViewPreview) ??
        _fetchedDeviceInventoryResourceConvergence?.resourceView;
    // A scheduler preview can be used without an opted-in resource reader.
    // Preserve that request-compatible path; once a resource image is
    // supplied, the selected target must be one of its owner-bound rows.
    if (resourceView == null || resourceView.devices.isEmpty) return true;
    final deviceID = preview.selectedDeviceID;
    final runnerInstanceID = preview.selectedInstanceID;
    if (deviceID == null ||
        runnerInstanceID == null ||
        preview.owner != resourceView.owner) {
      return false;
    }
    return resourceView.devices.any(
      (device) =>
          device.deviceID == deviceID &&
          device.runnerInstanceID == runnerInstanceID,
    );
  }

  bool _runnerDispatchPlanTargetsMatchResources(
    ForgeRunnerDispatchPlanPreview preview,
  ) {
    final resourceView =
        _strictClientInstanceResourceView(
          widget.clientInstanceResourceViewPreview,
        ) ??
        _strictClientInstanceResourceView(_fetchedClientInstanceResourceView) ??
        _strictClientInstanceResourceView(_clientInstanceResourceViewPreview) ??
        _fetchedDeviceInventoryResourceConvergence?.resourceView;
    // Preserve the request-compatible path when no resource reader is
    // configured or the observation has no device rows. Once a non-empty
    // owner-bound resource image is available, every plan candidate must be
    // one of its device or Runner instance IDs. The dispatch-plan contract
    // orders candidates by device ID, while some adapters expose the same
    // target through the Runner instance ID, so bind both declared identities
    // to the same owner-bound resource row.
    if (resourceView == null || resourceView.devices.isEmpty) return true;
    if (preview.owner != resourceView.owner) return false;
    final targetIDs = <String>{};
    for (final device in resourceView.devices) {
      targetIDs
        ..add(device.deviceID)
        ..add(device.runnerInstanceID);
    }
    return targetIDs.contains(preview.intentTargetID) &&
        preview.candidates.every(
          (candidate) => targetIDs.contains(candidate.targetID),
        );
  }

  /// Keeps admission candidates inside the current owner-bound resource
  /// image. A missing resource reader preserves the existing candidate-only
  /// compatibility path; once a non-empty image is supplied, either the
  /// device ID or its Runner instance ID is an acceptable target identity.
  bool _runnerAdmissionTargetMatchesResources(
    ForgeDeviceOwner owner,
    String targetID,
  ) {
    final resourceView =
        _strictClientInstanceResourceView(
          widget.clientInstanceResourceViewPreview,
        ) ??
        _strictClientInstanceResourceView(_fetchedClientInstanceResourceView) ??
        _strictClientInstanceResourceView(_clientInstanceResourceViewPreview) ??
        _fetchedClientInstanceSessionResourceConvergence?.resourceView ??
        _fetchedDeviceInventoryResourceConvergence?.resourceView;
    if (resourceView == null) return true;
    if (resourceView.devices.isEmpty &&
        !_runnerAdmissionResourceObservationConfigured) {
      return true;
    }
    if (resourceView.owner != owner) return false;
    return resourceView.devices.any(
      (device) =>
          device.deviceID == targetID || device.runnerInstanceID == targetID,
    );
  }

  bool _runnerAttemptBoundaryTargetMatchesResources(
    ForgeDeviceOwner owner,
    String targetID,
  ) {
    final resourceView =
        _strictClientInstanceResourceView(
          widget.clientInstanceResourceViewPreview,
        ) ??
        _strictClientInstanceResourceView(_fetchedClientInstanceResourceView) ??
        _strictClientInstanceResourceView(_clientInstanceResourceViewPreview) ??
        _fetchedClientInstanceSessionResourceConvergence?.resourceView ??
        _strictDeviceInventoryResourceConvergence(
          _fetchedDeviceInventoryResourceConvergence,
        )?.resourceView;
    if (resourceView == null) return true;
    if (resourceView.devices.isEmpty &&
        !_runnerAdmissionResourceObservationConfigured) {
      return true;
    }
    if (resourceView.owner != owner) return false;
    return resourceView.devices.any(
      (device) =>
          device.deviceID == targetID || device.runnerInstanceID == targetID,
    );
  }

  bool get _runnerAdmissionResourceObservationConfigured =>
      (widget.deviceInventoryResourceConvergenceOwner != null &&
          widget.deviceInventoryResourceConvergenceReader != null) ||
      (widget.clientInstanceSessionResourceConvergenceOwner != null &&
          widget.clientInstanceSessionResourceConvergenceReader != null) ||
      (widget.clientInstanceResourceViewOwner != null &&
          widget.clientInstanceResourceViewReader != null) ||
      (widget.deviceInventoryOwner != null &&
          widget.deviceInventoryV2Reader != null &&
          (widget.clientInstanceResourceViewOwner != null ||
              widget.clientInstanceSessionResourceConvergenceOwner != null));

  void _updateConversationLocation(String conversationID) {
    final route = Uri(
      pathSegments: <String>['forge', 'conversations', conversationID],
      queryParameters: _selectedClientInstanceID == null
          ? null
          : <String, String>{'instance_id': _selectedClientInstanceID!},
    );
    final routePath = '/${route.path}';
    final routeWithQuery = route.query.isEmpty
        ? routePath
        : '$routePath?${route.query}';
    final current = BrowserNavigation.currentUri;
    if (current.path == routePath && current.query == route.query) return;
    // Keep a same-document selection bookmarkable without rebuilding the
    // authenticated gate or issuing another navigation request. The URL is
    // only a selection hint; owner-scoped reads remain authoritative.
    BrowserNavigation.replaceState(routeWithQuery);
  }

  Future<bool> _loadRuns(
    String conversationID, {
    bool loadOlder = false,
  }) async {
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      if (mounted) setState(_clearRunDetailsForHiddenClientInstance);
      return false;
    }
    if (_loadingRuns && loadOlder) return false;
    final generation = loadOlder ? _runGeneration : ++_runGeneration;
    setState(() {
      _loadingRuns = true;
      _runError = null;
    });
    try {
      final page = await _api.listRuns(
        conversationID: conversationID,
        before: loadOlder ? _runCursor : null,
      );
      if (!mounted ||
          generation != _runGeneration ||
          _selected?.conversation.id != conversationID) {
        return false;
      }
      final incoming = loadOlder ? [..._runs, ...page.runs] : page.runs;
      final merged = _uniqueRuns(incoming);
      final wantedRunID = _selectedRun?.runID;
      final selectedRun =
          _findRun(merged, wantedRunID) ??
          (merged.isEmpty ? null : merged.first);
      final previousRunID = _selectedRun?.runID;
      setState(() {
        _runs = merged;
        _runCursor = page.nextCursor;
        _hasMoreRuns = page.hasMore && page.nextCursor != null;
        _selectedRun = selectedRun;
        if (selectedRun?.runID != previousRunID) {
          _clearDeviceObservation();
          _clearRunAttemptLeaseDispatchPreflight();
          _clearRunnerDispatchPlanPreview();
          _clearRunnerAttemptBoundaryPreview();
          _clearRunnerAttemptBoundary();
          _clearRunnerDispatchAdmission();
          _clearExecutionReconciliation();
          _clearRunObserved();
          _clearImportedRunObservations();
        }
        _loadingRuns = false;
      });
      if (!loadOlder && selectedRun != null) {
        final timelineLoaded = await _loadRunTimeline(
          conversationID,
          selectedRun.runID,
        );
        if (!mounted) return false;
        await _loadDeviceObservationIfRequested(
          conversationID,
          selectedRun.runID,
        );
        await _loadRunObservedIfRequested(
          conversationID: conversationID,
          runID: selectedRun.runID,
        );
        await _loadRunAttemptLeaseDispatchPreflightIfRequested(
          conversationID: conversationID,
          runID: selectedRun.runID,
        );
        await _loadRunnerDispatchPlanPreviewIfRequested(
          conversationID: conversationID,
          runID: selectedRun.runID,
        );
        await _loadRunnerExecutionIntentIfRequested(
          conversationID: conversationID,
          runID: selectedRun.runID,
        );
        await _loadRunnerDispatchAdmissionIfRequested(
          conversationID: conversationID,
          runID: selectedRun.runID,
        );
        await _loadRunnerAttemptBoundaryIfRequested(
          conversationID: conversationID,
          runID: selectedRun.runID,
        );
        await _loadExecutionReconciliationIfRequested(
          conversationID: conversationID,
          runID: selectedRun.runID,
        );
        return timelineLoaded;
      }
      if (selectedRun == null) {
        setState(_clearDeviceObservation);
        setState(_clearRunObserved);
        setState(_clearExecutionReconciliation);
        setState(() {
          _runTimelineGeneration++;
          _loadingRunTimeline = false;
          _runEvents = const [];
          _runTimelineSequence = 0;
          _hasMoreRunEvents = false;
          _runTimelineError = null;
        });
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      final authorizationFailure = _isAuthorizationFailure(error);
      await _clearSessionIfUnauthorized(error);
      if (!mounted || (!authorizationFailure && generation != _runGeneration)) {
        return false;
      }
      if (_dropSelectedConversationAfterOwnerReadFailure(
        conversationID,
        error,
      )) {
        if (!mounted) return false;
        setState(() {
          _runError = _friendlyError(error, 'Could not load runs.');
          _loadingRuns = false;
        });
        return false;
      }
      setState(() {
        _runError = _friendlyError(error, 'Could not load runs.');
        _loadingRuns = false;
      });
      return false;
    }
  }

  Future<bool> _loadRunTimeline(
    String conversationID,
    String runID, {
    bool loadMore = false,
  }) async {
    // A local client-instance projection is a read boundary for the complete
    // Run surface. Check it again here because a timeline load can outlive the
    // conversation tile that started it while the instance filter changes.
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      if (mounted) setState(_clearRunDetailsForHiddenClientInstance);
      return false;
    }
    if (_loadingRunTimeline && loadMore) return false;
    final generation = loadMore
        ? _runTimelineGeneration
        : ++_runTimelineGeneration;
    // A manual reload with rendered events must still request from sequence 0
    // so the panel can rebuild its complete visible timeline. Checkpoints are
    // used when entering a Run after cold start or selection recovery, while
    // the periodic sync path already has the in-memory sequence.
    final resumeFromCheckpoint = !loadMore && _runEvents.isEmpty;
    var afterSequence = loadMore ? _runTimelineSequence : 0;
    if (resumeFromCheckpoint) {
      afterSequence = await _runTimelineCursor(conversationID, runID).load();
      if (!mounted || generation != _runTimelineGeneration) return false;
    }
    setState(() {
      _loadingRunTimeline = true;
      _runTimelineError = null;
      if (!loadMore) {
        _runEvents = const [];
        _runTimelineSequence = 0;
        _hasMoreRunEvents = false;
      }
    });
    try {
      final page = await _api.listRunTimeline(
        conversationID: conversationID,
        runID: runID,
        afterSequence: afterSequence,
      );
      if (!mounted ||
          generation != _runTimelineGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        return false;
      }
      setState(() {
        _runEvents = _uniqueRunEvents(
          loadMore ? [..._runEvents, ...page.events] : page.events,
        );
        _runTimelineSequence = page.scannedThroughSequence;
        _hasMoreRunEvents = page.hasMore;
        _loadingRunTimeline = false;
      });
      await _runTimelineCursor(
        conversationID,
        runID,
      ).save(page.scannedThroughSequence);
      return true;
    } catch (error) {
      if (!mounted) return false;
      final authorizationFailure = _isAuthorizationFailure(error);
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          (!authorizationFailure && generation != _runTimelineGeneration)) {
        return false;
      }
      if (_dropSelectedConversationAfterOwnerReadFailure(
        conversationID,
        error,
      )) {
        if (!mounted) return false;
        setState(() {
          _runTimelineError = _friendlyError(
            error,
            'Could not load run timeline.',
          );
          _loadingRunTimeline = false;
        });
        return false;
      }
      if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
        if (mounted) setState(_clearRunDetailsForHiddenClientInstance);
        return false;
      }
      setState(() {
        _runTimelineError = _friendlyError(
          error,
          'Could not load run timeline.',
        );
        _loadingRunTimeline = false;
      });
      return false;
    }
  }

  Future<void> _loadDeviceObservationIfRequested(
    String conversationID,
    String runID,
  ) async {
    if (!mounted) return;
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final request = widget.deviceObservationRequest;
    final key = '$conversationID/$runID';
    if (request == null ||
        request.conversationID != conversationID ||
        request.runID != runID) {
      if (_fetchedDeviceObservation != null ||
          _deviceObservationError != null ||
          _deviceObservationKey != null ||
          _loadingDeviceObservation) {
        setState(_clearDeviceObservation);
      }
      return;
    }
    if (_deviceObservationKey == key &&
        (_fetchedDeviceObservation != null ||
            _deviceObservationError != null ||
            _loadingDeviceObservation)) {
      return;
    }
    final generation = ++_deviceObservationGeneration;
    setState(() {
      _deviceObservationKey = key;
      _loadingDeviceObservation = true;
      _deviceObservationError = null;
      _fetchedDeviceObservation = null;
    });
    try {
      final wire = await _api.previewSessionDeviceObservation(request: request);
      final observation = ForgeSessionDeviceObservation.fromWire(wire);
      if (!mounted ||
          generation != _deviceObservationGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        return;
      }
      setState(() {
        _fetchedDeviceObservation = observation;
        _deviceObservationError = null;
        _loadingDeviceObservation = false;
      });
    } catch (error) {
      if (!mounted || generation != _deviceObservationGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        return;
      }
      setState(() {
        _fetchedDeviceObservation = null;
        _deviceObservationError = _friendlyError(
          error,
          'Could not load device observation.',
        );
        _loadingDeviceObservation = false;
      });
    }
  }

  Future<void> _loadRunObservedIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final reader = widget.runObservedReader;
    final receiptReader = widget.sessionRunnerReceiptObservationReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (reader == null || conversationID == null || runID == null) {
      if (mounted &&
          (_fetchedRunObserved != null ||
              _runObservedError != null ||
              _loadingRunObserved ||
              _runObservedStale)) {
        setState(_clearRunObserved);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunObserved) return;
    if (!force && (_fetchedRunObserved != null || _runObservedError != null)) {
      return;
    }
    final previous = _fetchedRunObserved;
    final pairedRead = receiptReader != null;
    final selectedRun = _selectedRun;
    final generation = ++_runObservedGeneration;
    setState(() {
      _loadingRunObserved = true;
      _runObservedError = null;
      _runObservedStale = !pairedRead && previous != null;
      if (pairedRead) {
        // A paired refresh is fail-closed: never leave either half of the
        // previous independently read snapshot visible while refreshing.
        _fetchedRunObserved = null;
        _fetchedSessionRunnerReceiptObservation = null;
      }
    });
    try {
      // Re-decode the callback result through the strict wire boundary. This
      // prevents a caller-created model from bypassing the display-only
      // authority and content checks.
      final rawValues = await Future.wait<Object>([
        reader(conversationID, runID),
        if (receiptReader != null) receiptReader(conversationID, runID),
      ]);
      var observation = ForgeRunObserved.fromJson(
        (rawValues.first as ForgeRunObserved).toJson(),
      );
      ForgeSessionRunnerReceiptObservation? receiptObservation;
      if (receiptReader != null) {
        if (selectedRun == null || selectedRun.runID != runID) {
          throw const FormatException(
            'The selected Run changed before its observations converged.',
          );
        }
        final convergence =
            ForgeRunReceiptObservationConvergence.fromObservations(
              runObserved: observation,
              receiptObserved:
                  rawValues[1] as ForgeSessionRunnerReceiptObservation,
              conversationID: conversationID,
              runID: runID,
              promptID: selectedRun.promptID,
              runCreatedAtMS: selectedRun.createdAtMS,
              runLatestSequence: selectedRun.latestSequence,
              runStatus: selectedRun.status,
            );
        observation = convergence.runObserved;
        receiptObservation = convergence.receiptObserved;
      } else if (!observation.isFor(conversationID, runID) ||
          !observation.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid or differently bound Run observation.',
        );
      }
      if (!mounted ||
          generation != _runObservedGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunObserved = observation;
        _fetchedSessionRunnerReceiptObservation = receiptObservation;
        _runObservedError = null;
        _runObservedStale = false;
        _loadingRunObserved = false;
      });
      unawaited(
        _loadRunExecutionEvidenceIfRequested(
          conversationID: conversationID,
          runID: runID,
          force: true,
        ),
      );
    } catch (error) {
      if (!mounted || generation != _runObservedGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted) return;
      if (_dropSelectedConversationAfterOwnerReadFailure(
        conversationID,
        error,
      )) {
        if (!mounted) return;
        setState(() {
          _runObservedError = _friendlyError(
            error,
            'Could not load Run metadata observation.',
          );
        });
        return;
      }
      if (!mounted ||
          generation != _runObservedGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunObserved = pairedRead ? null : previous;
        if (pairedRead) _fetchedSessionRunnerReceiptObservation = null;
        _runObservedError = _friendlyError(
          error,
          pairedRead
              ? 'Could not converge Run and Runner receipt observations.'
              : 'Could not load Run metadata observation.',
        );
        _runObservedStale = !pairedRead && previous != null;
        _loadingRunObserved = false;
      });
    }
  }

  Future<void> _loadRunExecutionEvidenceIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final reader = widget.runExecutionEvidenceReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    final fetchedRun = _fetchedRunObserved;
    final pairedReaderEnabled =
        widget.sessionRunnerReceiptObservationReader != null;
    final sourceRun =
        fetchedRun?.isFor(conversationID ?? '', runID ?? '') == true
        ? fetchedRun
        : pairedReaderEnabled
        ? null
        : widget.runObserved;
    final sourceReceipt = pairedReaderEnabled
        ? _fetchedSessionRunnerReceiptObservation
        : _fetchedSessionRunnerReceiptObservation ??
              widget.sessionRunnerReceiptObservation;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (reader == null ||
        sourceRun == null ||
        sourceReceipt == null ||
        conversationID == null ||
        runID == null) {
      if (mounted &&
          (_fetchedRunExecutionEvidence != null ||
              _runExecutionEvidenceError != null ||
              _loadingRunExecutionEvidence ||
              _runExecutionEvidenceStale)) {
        setState(_clearRunExecutionEvidence);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunExecutionEvidence) return;
    if (!force &&
        (_fetchedRunExecutionEvidence != null ||
            _runExecutionEvidenceError != null)) {
      return;
    }
    final previous = _fetchedRunExecutionEvidence;
    final generation = ++_runExecutionEvidenceGeneration;
    setState(() {
      _loadingRunExecutionEvidence = true;
      _runExecutionEvidenceError = null;
      _runExecutionEvidenceStale = previous != null;
    });
    try {
      final validatedRun = ForgeRunObserved.fromJson(sourceRun.toJson());
      final validatedReceipt = ForgeSessionRunnerReceiptObservation.fromJson(
        sourceReceipt.toJson(),
      );
      if (!validatedRun.isFor(conversationID, runID) ||
          !validatedReceipt.isFor(conversationID, runID) ||
          validatedRun.promptID != validatedReceipt.promptID ||
          !validatedRun.isDisplayOnly ||
          !validatedReceipt.isDisplayOnly) {
        throw const FormatException(
          'Forge Run execution-evidence sources are not bound to the selected Run.',
        );
      }
      final evidence = ForgeRunExecutionEvidence.fromJson(
        (await reader(
          conversationID,
          runID,
          validatedRun,
          validatedReceipt,
        )).toJson(),
      );
      final receipt = validatedReceipt.receiptObservation;
      if (!evidence.isFor(conversationID, runID) ||
          evidence.ownerRef != validatedRun.ownerRef ||
          evidence.promptID != validatedRun.promptID ||
          evidence.runStatus != validatedRun.status ||
          evidence.attemptID != receipt.attemptID ||
          evidence.targetID != receipt.targetID ||
          evidence.commandID != receipt.commandID ||
          evidence.commandSHA256 != receipt.commandSHA256 ||
          evidence.dispositionKind != receipt.dispositionKind ||
          evidence.receiptObservedAtMS != receipt.observedAtMS ||
          evidence.uncertain != receipt.uncertain ||
          evidence.reconciliationRequired != receipt.reconciliationRequired ||
          !evidence.isDisplayOnly) {
        throw const FormatException(
          'Forge returned another or authority-bearing Run execution evidence.',
        );
      }
      if (!mounted ||
          generation != _runExecutionEvidenceGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunExecutionEvidence = evidence;
        _runExecutionEvidenceError = null;
        _runExecutionEvidenceStale = false;
        _loadingRunExecutionEvidence = false;
      });
    } catch (error) {
      if (!mounted || generation != _runExecutionEvidenceGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runExecutionEvidenceGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunExecutionEvidence = previous;
        _runExecutionEvidenceError = _friendlyError(
          error,
          'Could not load Run execution-evidence preview.',
        );
        _runExecutionEvidenceStale = previous != null;
        _loadingRunExecutionEvidence = false;
      });
    }
  }

  Future<void> _loadSessionRunnerReceiptHistoryIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final reader = widget.sessionRunnerReceiptHistoryReader;
    final request = widget.sessionRunnerReceiptHistoryRequest;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (reader == null ||
        request == null ||
        conversationID == null ||
        runID == null) {
      if (mounted &&
          (_fetchedSessionRunnerReceiptHistory != null ||
              _sessionRunnerReceiptHistoryError != null ||
              _loadingSessionRunnerReceiptHistory ||
              _sessionRunnerReceiptHistoryStale)) {
        setState(_clearSessionRunnerReceiptHistory);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingSessionRunnerReceiptHistory) return;
    if (!force &&
        (_fetchedSessionRunnerReceiptHistory != null ||
            _sessionRunnerReceiptHistoryError != null)) {
      return;
    }
    final previous = _fetchedSessionRunnerReceiptHistory;
    final generation = ++_sessionRunnerReceiptHistoryGeneration;
    setState(() {
      _loadingSessionRunnerReceiptHistory = true;
      _sessionRunnerReceiptHistoryError = null;
      _sessionRunnerReceiptHistoryStale = previous != null;
    });
    try {
      final validatedRequest = ForgeSessionRunnerReceiptHistory.fromJson(
        request.toJson(),
      );
      if (!validatedRequest.isDisplayOnly ||
          !validatedRequest.isFor(conversationID, runID)) {
        throw const FormatException(
          'Forge session Runner receipt-history request is not bound to the selected Run.',
        );
      }
      final history = ForgeSessionRunnerReceiptHistory.fromJson(
        (await reader(conversationID, runID, validatedRequest)).toJson(),
      );
      if (!history.isDisplayOnly ||
          !history.isFor(conversationID, runID) ||
          history.owner != validatedRequest.owner ||
          jsonEncode(history.toJson()) !=
              jsonEncode(validatedRequest.toJson())) {
        throw const FormatException(
          'Forge returned another or authority-bearing session Runner receipt history.',
        );
      }
      if (!mounted ||
          generation != _sessionRunnerReceiptHistoryGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedSessionRunnerReceiptHistory = history;
        _sessionRunnerReceiptHistoryError = null;
        _sessionRunnerReceiptHistoryStale = false;
        _loadingSessionRunnerReceiptHistory = false;
      });
    } catch (error) {
      if (!mounted || generation != _sessionRunnerReceiptHistoryGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _sessionRunnerReceiptHistoryGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedSessionRunnerReceiptHistory = previous;
        _sessionRunnerReceiptHistoryError = _friendlyError(
          error,
          'Could not load session Runner receipt-history preview.',
        );
        _sessionRunnerReceiptHistoryStale = previous != null;
        _loadingSessionRunnerReceiptHistory = false;
      });
    }
  }

  Future<void> _loadSessionRunnerReconciliationProjectionIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final reader = widget.sessionRunnerReconciliationProjectionReader;
    final request = widget.sessionRunnerReconciliationProjectionRequest;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (reader == null ||
        request == null ||
        conversationID == null ||
        runID == null) {
      if (mounted &&
          (_fetchedSessionRunnerReconciliationProjection != null ||
              _sessionRunnerReconciliationProjectionError != null ||
              _loadingSessionRunnerReconciliationProjection ||
              _sessionRunnerReconciliationProjectionStale)) {
        setState(_clearSessionRunnerReconciliationProjection);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingSessionRunnerReconciliationProjection) return;
    if (!force &&
        (_fetchedSessionRunnerReconciliationProjection != null ||
            _sessionRunnerReconciliationProjectionError != null)) {
      return;
    }
    final previous = _fetchedSessionRunnerReconciliationProjection;
    final generation = ++_sessionRunnerReconciliationProjectionGeneration;
    setState(() {
      _loadingSessionRunnerReconciliationProjection = true;
      _sessionRunnerReconciliationProjectionError = null;
      _sessionRunnerReconciliationProjectionStale = previous != null;
    });
    try {
      final validatedRequest = ForgeSessionRunnerReceiptHistory.fromJson(
        request.toJson(),
      );
      if (!validatedRequest.isDisplayOnly ||
          !validatedRequest.isFor(conversationID, runID) ||
          !validatedRequest.hasUncertainTerminal) {
        throw const FormatException(
          'Forge reconciliation request is not bound to an uncertain terminal Run.',
        );
      }
      final projection = ForgeSessionRunnerReconciliationProjection.fromJson(
        (await reader(conversationID, runID, validatedRequest)).toJson(),
      );
      final source = projection.source;
      if (!projection.isDisplayOnly ||
          !projection.isFor(conversationID, runID) ||
          projection.owner != validatedRequest.owner ||
          source.owner != validatedRequest.owner ||
          source.conversationID != validatedRequest.conversationID ||
          source.promptID != validatedRequest.promptID ||
          source.runID != validatedRequest.runID ||
          source.attemptCount != validatedRequest.attemptCount ||
          source.latestAttemptID != validatedRequest.latestAttemptID ||
          source.latestCommandID != validatedRequest.latestCommandID ||
          source.latestTargetID != validatedRequest.latestTargetID ||
          source.latestDispositionKind !=
              validatedRequest.latestDispositionKind ||
          source.latestObservedAtMS != validatedRequest.latestObservedAtMS) {
        throw const FormatException(
          'Forge returned another or authority-bearing reconciliation projection.',
        );
      }
      if (!mounted ||
          generation != _sessionRunnerReconciliationProjectionGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedSessionRunnerReconciliationProjection = projection;
        _sessionRunnerReconciliationProjectionError = null;
        _sessionRunnerReconciliationProjectionStale = false;
        _loadingSessionRunnerReconciliationProjection = false;
      });
    } catch (error) {
      if (!mounted ||
          generation != _sessionRunnerReconciliationProjectionGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _sessionRunnerReconciliationProjectionGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedSessionRunnerReconciliationProjection = previous;
        _sessionRunnerReconciliationProjectionError = _friendlyError(
          error,
          'Could not load session Runner reconciliation preview.',
        );
        _sessionRunnerReconciliationProjectionStale = previous != null;
        _loadingSessionRunnerReconciliationProjection = false;
      });
    }
  }

  Future<void> _loadDeviceInventoryIfRequested({bool force = false}) async {
    final owner = widget.deviceInventoryOwner;
    final reader = widget.deviceInventoryReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null) {
      if (mounted &&
          (_fetchedDeviceInventory != null ||
              _deviceInventoryError != null ||
              _loadingDeviceInventory)) {
        setState(_clearDeviceInventory);
      }
      return;
    }
    if (_loadingDeviceInventory) return;
    if (!force &&
        (_fetchedDeviceInventory != null || _deviceInventoryError != null)) {
      return;
    }
    final previousPage = _fetchedDeviceInventory;
    final generation = ++_deviceInventoryGeneration;
    setState(() {
      _loadingDeviceInventory = true;
      _deviceInventoryError = null;
      // Keep the last owner-validated snapshot visible while a foreground
      // refresh is in flight. A temporary network failure must not look like
      // an empty resource pool.
      _deviceInventoryStale = previousPage != null;
    });
    try {
      // Re-decode the callback result through the strict wire boundary. This
      // keeps a test or future adapter from constructing an authority-bearing
      // value through the public const model constructor.
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final page = ForgeDeviceInventoryPage.fromJson(
        (await reader(owner)).toJson(),
      );
      if (page.owner != expectedOwner) {
        throw const FormatException(
          'Forge returned device inventory for another owner.',
        );
      }
      if (!mounted ||
          generation != _deviceInventoryGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedDeviceInventory = page;
        _deviceInventoryError = null;
        _deviceInventoryStale = false;
        _loadingDeviceInventory = false;
      });
    } catch (error) {
      if (!mounted || generation != _deviceInventoryGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _deviceInventoryGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedDeviceInventory = previousPage;
        _deviceInventoryError = _friendlyError(
          error,
          'Could not load device inventory observation.',
        );
        _deviceInventoryStale = previousPage != null;
        _loadingDeviceInventory = false;
      });
    }
  }

  Future<void> _loadDeviceInventoryV2IfRequested({bool force = false}) async {
    final inFlight = _deviceInventoryV2Refresh;
    if (inFlight != null) {
      final inFlightWasForced = _deviceInventoryV2RefreshWasForced;
      await inFlight;
      if (!force ||
          (inFlightWasForced &&
              _deviceInventoryV2Error == null &&
              !_deviceInventoryV2Stale)) {
        return;
      }
    }
    final refresh = _loadDeviceInventoryV2Now(force: force);
    _deviceInventoryV2Refresh = refresh;
    _deviceInventoryV2RefreshWasForced = force;
    try {
      await refresh;
    } finally {
      if (identical(_deviceInventoryV2Refresh, refresh)) {
        _deviceInventoryV2Refresh = null;
        _deviceInventoryV2RefreshWasForced = false;
      }
    }
  }

  Future<void> _loadDeviceInventoryV2Now({bool force = false}) async {
    final owner = widget.deviceInventoryOwner;
    final reader = widget.deviceInventoryV2Reader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null) {
      if (mounted &&
          (_fetchedDeviceInventoryV2 != null ||
              _deviceInventoryV2Error != null ||
              _loadingDeviceInventoryV2)) {
        setState(_clearDeviceInventoryV2);
      }
      return;
    }
    if (_loadingDeviceInventoryV2) return;
    if (!force &&
        (_fetchedDeviceInventoryV2 != null ||
            _deviceInventoryV2Error != null)) {
      return;
    }
    final previousPage = _fetchedDeviceInventoryV2;
    final generation = ++_deviceInventoryV2Generation;
    setState(() {
      _loadingDeviceInventoryV2 = true;
      _deviceInventoryV2Error = null;
      // Preserve the last owner-validated v2 snapshot while a refresh is in
      // flight, matching the existing v1 inventory reader behavior.
      _deviceInventoryV2Stale = previousPage != null;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final page = ForgeDeviceInventoryPageV2.fromJson(
        (await reader(owner)).toJson(),
      );
      if (page.owner != expectedOwner) {
        throw const FormatException(
          'Forge returned v2 device inventory for another owner.',
        );
      }
      if (!mounted ||
          generation != _deviceInventoryV2Generation ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedDeviceInventoryV2 = page;
        _deviceInventoryV2Error = null;
        _deviceInventoryV2Stale = false;
        _loadingDeviceInventoryV2 = false;
      });
    } catch (error) {
      if (!mounted || generation != _deviceInventoryV2Generation) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _deviceInventoryV2Generation ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedDeviceInventoryV2 = previousPage;
        _deviceInventoryV2Error = _friendlyError(
          error,
          'Could not load v2 device inventory observation.',
        );
        _deviceInventoryV2Stale = previousPage != null;
        _loadingDeviceInventoryV2 = false;
      });
    }
  }

  Future<void> _loadDeviceInventoryResourceConvergenceIfRequested({
    bool force = false,
  }) async {
    final owner = widget.deviceInventoryResourceConvergenceOwner;
    final reader = widget.deviceInventoryResourceConvergenceReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null) {
      if (mounted &&
          (_fetchedDeviceInventoryResourceConvergence != null ||
              _deviceInventoryResourceConvergenceError != null ||
              _loadingDeviceInventoryResourceConvergence)) {
        setState(_clearDeviceInventoryResourceConvergence);
      }
      return;
    }
    if (_loadingDeviceInventoryResourceConvergence) return;
    if (!force &&
        (_fetchedDeviceInventoryResourceConvergence != null ||
            _deviceInventoryResourceConvergenceError != null)) {
      return;
    }
    final previous = _fetchedDeviceInventoryResourceConvergence;
    final generation = ++_deviceInventoryResourceConvergenceGeneration;
    setState(() {
      _loadingDeviceInventoryResourceConvergence = true;
      _deviceInventoryResourceConvergenceError = null;
      _deviceInventoryResourceConvergenceStale = previous != null;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final convergence = ForgeDeviceInventoryResourceConvergence.fromJson(
        (await reader(owner)).toJson(),
      );
      if (convergence.owner != expectedOwner || !convergence.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid inventory/resource convergence pair.',
        );
      }
      if (!mounted ||
          generation != _deviceInventoryResourceConvergenceGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedDeviceInventoryResourceConvergence = convergence;
        _deviceInventoryResourceConvergenceError = null;
        _deviceInventoryResourceConvergenceStale = false;
        _loadingDeviceInventoryResourceConvergence = false;
      });
      _reconcileSelectedClientInstanceProjection();
    } catch (error) {
      if (!mounted ||
          generation != _deviceInventoryResourceConvergenceGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _deviceInventoryResourceConvergenceGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedDeviceInventoryResourceConvergence = previous;
        _deviceInventoryResourceConvergenceError = _friendlyError(
          error,
          'Could not load converged device resources.',
        );
        _deviceInventoryResourceConvergenceStale = previous != null;
        _loadingDeviceInventoryResourceConvergence = false;
      });
    }
  }

  Future<void> _loadDeviceInventoryRegistryPlacementPreviewIfRequested({
    bool force = false,
  }) async {
    final owner = widget.deviceInventoryOwner;
    final requirements = widget.deviceInventoryRegistryPlacementRequirements;
    final reader = widget.deviceInventoryRegistryPlacementPreviewReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || requirements == null || reader == null) {
      if (mounted &&
          (_fetchedDeviceInventoryRegistryPlacementPreview != null ||
              _deviceInventoryRegistryPlacementPreviewError != null ||
              _loadingDeviceInventoryRegistryPlacementPreview)) {
        setState(_clearDeviceInventoryRegistryPlacementPreview);
      }
      return;
    }
    if (_loadingDeviceInventoryRegistryPlacementPreview) return;
    if (!force &&
        (_fetchedDeviceInventoryRegistryPlacementPreview != null ||
            _deviceInventoryRegistryPlacementPreviewError != null)) {
      return;
    }
    final previousPreview = _fetchedDeviceInventoryRegistryPlacementPreview;
    final generation = ++_deviceInventoryRegistryPlacementPreviewGeneration;
    setState(() {
      _loadingDeviceInventoryRegistryPlacementPreview = true;
      _deviceInventoryRegistryPlacementPreviewError = null;
      _deviceInventoryRegistryPlacementPreviewStale = previousPreview != null;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final expectedRequirements = ForgeDevicePlacementRequirements.fromJson(
        requirements.toJson(),
      );
      final preview = ForgeDeviceRegistryPlacementPreview.fromJson(
        (await reader(owner, expectedRequirements)).toJson(),
      );
      if (preview.evaluationOwner != expectedOwner ||
          preview.authority.anyGranted ||
          preview.selectedDeviceID != null ||
          preview.selectedInstanceID != null) {
        throw const FormatException(
          'Forge returned an invalid registry placement preview.',
        );
      }
      if (!mounted ||
          generation != _deviceInventoryRegistryPlacementPreviewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedDeviceInventoryRegistryPlacementPreview = preview;
        _deviceInventoryRegistryPlacementPreviewError = null;
        _deviceInventoryRegistryPlacementPreviewStale = false;
        _loadingDeviceInventoryRegistryPlacementPreview = false;
      });
    } catch (error) {
      if (!mounted ||
          generation != _deviceInventoryRegistryPlacementPreviewGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _deviceInventoryRegistryPlacementPreviewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedDeviceInventoryRegistryPlacementPreview = previousPreview;
        _deviceInventoryRegistryPlacementPreviewError = _friendlyError(
          error,
          'Could not load registry placement preview.',
        );
        _deviceInventoryRegistryPlacementPreviewStale = previousPreview != null;
        _loadingDeviceInventoryRegistryPlacementPreview = false;
      });
    }
  }

  Future<void> _loadSchedulerSelectionPreviewIfRequested({
    bool force = false,
  }) async {
    final request = widget.schedulerSelectionPreviewRequest;
    final reader = widget.schedulerSelectionPreviewReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null || reader == null) {
      if (mounted &&
          (_fetchedSchedulerSelectionPreview != null ||
              _schedulerSelectionPreviewError != null ||
              _loadingSchedulerSelectionPreview)) {
        setState(_clearSchedulerSelectionPreview);
      }
      return;
    }
    if (!_schedulerSelectionRequestVisible(request.conversationID)) {
      if (mounted &&
          (_fetchedSchedulerSelectionPreview != null ||
              _schedulerSelectionPreviewError != null ||
              _loadingSchedulerSelectionPreview)) {
        setState(_clearSchedulerSelectionPreview);
      }
      return;
    }
    // Keep an explicit scheduler preview scoped to the Run currently selected
    // by the Sessions surface. A request may be configured before the first
    // owner snapshot (so an empty/default Gate remains compatible), but once
    // the screen has a selected Conversation or Run, a different binding is
    // stale and must not reach the candidate route.
    final selectedConversationID = _selected?.conversation.id;
    final selectedRunID = _selectedRun?.runID;
    if ((selectedConversationID != null &&
            selectedConversationID != request.conversationID) ||
        (selectedRunID != null && selectedRunID != request.runID)) {
      if (mounted &&
          (_fetchedSchedulerSelectionPreview != null ||
              _schedulerSelectionPreviewError != null ||
              _loadingSchedulerSelectionPreview)) {
        setState(_clearSchedulerSelectionPreview);
      }
      return;
    }
    if (_loadingSchedulerSelectionPreview) return;
    if (!force &&
        (_fetchedSchedulerSelectionPreview != null ||
            _schedulerSelectionPreviewError != null)) {
      return;
    }
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        setState(() {
          _fetchedSchedulerSelectionPreview = null;
          _schedulerSelectionPreviewError =
              'Scheduler selection preview is waiting for a fresh validated client-instance session/resource observation.';
          _schedulerSelectionPreviewStale = false;
        });
      }
      return;
    }
    if (!_schedulerSelectionRequestVisible(request.conversationID)) {
      if (mounted) setState(_clearSchedulerSelectionPreview);
      return;
    }
    if (_selected?.conversation.id != null &&
        _selected?.conversation.id != request.conversationID) {
      if (mounted) setState(_clearSchedulerSelectionPreview);
      return;
    }
    if (_selectedRun?.runID != null && _selectedRun?.runID != request.runID) {
      if (mounted) setState(_clearSchedulerSelectionPreview);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Scheduler selection preview',
          force: true,
        );
    if (observationError != null) {
      if (mounted) {
        setState(() {
          _fetchedSchedulerSelectionPreview = null;
          _schedulerSelectionPreviewError = observationError;
          _schedulerSelectionPreviewStale = false;
        });
      }
      return;
    }
    final previousPreview = _fetchedSchedulerSelectionPreview;
    final generation = ++_schedulerSelectionPreviewGeneration;
    setState(() {
      _loadingSchedulerSelectionPreview = true;
      _schedulerSelectionPreviewError = null;
      _schedulerSelectionPreviewStale = previousPreview != null;
    });
    try {
      final expectedRequest = ForgeSchedulerSelectionPreviewRequest.fromJson(
        request.toJson(),
      );
      final preview = ForgeSchedulerSelectionPreview.fromJson(
        (await reader(expectedRequest)).toJson(),
      );
      if (!preview.isFor(
            expectedRequest.conversationID,
            expectedRequest.runID,
          ) ||
          preview.attemptID != expectedRequest.attemptID ||
          preview.authority.anyGranted ||
          !preview.previewOnly) {
        throw const FormatException(
          'Forge returned an invalid scheduler selection preview.',
        );
      }
      if (!_schedulerSelectionTargetMatchesResources(preview)) {
        throw const FormatException(
          'Forge returned a scheduler target absent from the current resource observation.',
        );
      }
      if (!mounted ||
          generation != _schedulerSelectionPreviewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedSchedulerSelectionPreview = preview;
        _schedulerSelectionPreviewError = null;
        _schedulerSelectionPreviewStale = false;
        _loadingSchedulerSelectionPreview = false;
      });
    } catch (error) {
      if (!mounted || generation != _schedulerSelectionPreviewGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _schedulerSelectionPreviewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedSchedulerSelectionPreview = previousPreview;
        _schedulerSelectionPreviewError = _friendlyError(
          error,
          'Could not load scheduler selection preview.',
        );
        _schedulerSelectionPreviewStale = previousPreview != null;
        _loadingSchedulerSelectionPreview = false;
      });
    }
  }

  Future<void> _loadSchedulerSelectionLeaseIfRequested() async {
    final claimRequest = widget.schedulerSelectionLeaseRequest;
    final claimReader = widget.schedulerSelectionLeaseReader;
    final claimIdempotencyKey = widget.schedulerSelectionLeaseIdempotencyKey;
    final renewalRequest = widget.schedulerSelectionLeaseRenewalRequest;
    final renewalReader = widget.schedulerSelectionLeaseRenewalReader;
    final renewalIdempotencyKey =
        widget.schedulerSelectionLeaseRenewalIdempotencyKey;
    // Renewal is a separate explicit candidate. If both candidates are
    // supplied, renewal wins so a caller cannot accidentally claim a second
    // reservation while trying to extend the proof it already holds.
    final isRenewal = renewalRequest != null || renewalReader != null;
    final request = isRenewal ? null : claimRequest;
    final reader = isRenewal ? null : claimReader;
    final idempotencyKey = isRenewal
        ? renewalIdempotencyKey
        : claimIdempotencyKey;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if ((isRenewal && (renewalRequest == null || renewalReader == null)) ||
        (!isRenewal && (request == null || reader == null)) ||
        idempotencyKey == null ||
        idempotencyKey.trim().isEmpty) {
      if (mounted &&
          (_fetchedSchedulerSelectionLease != null ||
              _schedulerSelectionLeaseError != null ||
              _loadingSchedulerSelectionLease)) {
        setState(_clearSchedulerSelectionLease);
      }
      return;
    }
    // Keep an explicit lease candidate scoped to the Conversation and Run
    // currently selected by the Sessions surface. A candidate may be
    // configured before the first owner snapshot (so an empty/default Gate
    // remains compatible), but once a selection exists a different binding
    // is stale and must not reach a claim or renewal route.
    final expectedConversationID = isRenewal
        ? renewalRequest!.conversationID
        : request!.conversationID;
    final expectedRunID = isRenewal ? renewalRequest!.runID : request!.runID;
    if (!_schedulerSelectionRequestVisible(expectedConversationID)) {
      if (mounted &&
          (_fetchedSchedulerSelectionLease != null ||
              _schedulerSelectionLeaseError != null ||
              _loadingSchedulerSelectionLease)) {
        setState(_clearSchedulerSelectionLease);
      }
      return;
    }
    final selectedConversationID = _selected?.conversation.id;
    final selectedRunID = _selectedRun?.runID;
    if ((selectedConversationID != null &&
            selectedConversationID != expectedConversationID) ||
        (selectedRunID != null && selectedRunID != expectedRunID)) {
      if (mounted &&
          (_fetchedSchedulerSelectionLease != null ||
              _schedulerSelectionLeaseError != null ||
              _loadingSchedulerSelectionLease)) {
        setState(_clearSchedulerSelectionLease);
      }
      return;
    }
    if (_loadingSchedulerSelectionLease ||
        _fetchedSchedulerSelectionLease != null ||
        _schedulerSelectionLeaseError != null) {
      return;
    }
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        setState(() {
          _fetchedSchedulerSelectionLease = null;
          _schedulerSelectionLeaseError =
              'Scheduler lease is waiting for a fresh validated client-instance session/resource observation.';
          _schedulerSelectionLeaseStale = false;
        });
      }
      return;
    }
    if (_selected?.conversation.id != null &&
        _selected?.conversation.id != expectedConversationID) {
      if (mounted) setState(_clearSchedulerSelectionLease);
      return;
    }
    if (_selectedRun?.runID != null && _selectedRun?.runID != expectedRunID) {
      if (mounted) setState(_clearSchedulerSelectionLease);
      return;
    }
    if (!_schedulerSelectionRequestVisible(expectedConversationID)) {
      if (mounted) setState(_clearSchedulerSelectionLease);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          isRenewal ? 'Scheduler lease renewal' : 'Scheduler lease',
        );
    if (observationError != null) {
      if (mounted) {
        setState(() {
          _fetchedSchedulerSelectionLease = null;
          _schedulerSelectionLeaseError = observationError;
          _schedulerSelectionLeaseStale = false;
        });
      }
      return;
    }
    final generation = ++_schedulerSelectionLeaseGeneration;
    setState(() {
      _loadingSchedulerSelectionLease = true;
      _schedulerSelectionLeaseError = null;
      _schedulerSelectionLeaseStale = false;
    });
    try {
      final ForgeSchedulerSelectionLease lease;
      if (isRenewal) {
        final expectedRequest =
            ForgeSchedulerSelectionLeaseRenewalRequest.fromJson(
              renewalRequest!.toJson(),
            );
        lease = ForgeSchedulerSelectionLease.fromJson(
          (await renewalReader!(expectedRequest, idempotencyKey)).toJson(),
        );
        if (!lease.isFor(
              expectedRequest.conversationID,
              expectedRequest.runID,
              expectedRequest.attemptID,
            ) ||
            lease.instanceID != expectedRequest.targetID ||
            lease.grant.epoch <= expectedRequest.epoch ||
            !lease.authority.placementSelected ||
            !lease.authority.reservationCreated ||
            !lease.authority.leaseIssued ||
            lease.authority.executionAuthorized ||
            lease.authority.dispatchPerformed ||
            lease.authority.auditPublished) {
          throw const FormatException(
            'Forge returned an invalid scheduler lease renewal.',
          );
        }
      } else {
        final expectedRequest = ForgeSchedulerSelectionLeaseRequest.fromJson(
          request!.toJson(),
        );
        lease = ForgeSchedulerSelectionLease.fromJson(
          (await reader!(expectedRequest, idempotencyKey)).toJson(),
        );
        if (!lease.isFor(
              expectedRequest.conversationID,
              expectedRequest.runID,
              expectedRequest.attemptID,
            ) ||
            !lease.authority.placementSelected ||
            !lease.authority.reservationCreated ||
            !lease.authority.leaseIssued ||
            lease.authority.executionAuthorized ||
            lease.authority.dispatchPerformed ||
            lease.authority.auditPublished) {
          throw const FormatException(
            'Forge returned an invalid scheduler lease.',
          );
        }
      }
      if (lease.authority.executionAuthorized ||
          lease.authority.dispatchPerformed ||
          lease.authority.auditPublished) {
        throw const FormatException(
          'Forge returned an invalid scheduler lease.',
        );
      }
      if (!mounted ||
          generation != _schedulerSelectionLeaseGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedSchedulerSelectionLease = lease;
        _schedulerSelectionLeaseError = null;
        _schedulerSelectionLeaseStale = false;
        _loadingSchedulerSelectionLease = false;
      });
    } catch (error) {
      if (!mounted || generation != _schedulerSelectionLeaseGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _schedulerSelectionLeaseGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedSchedulerSelectionLease = null;
        _schedulerSelectionLeaseError = _friendlyError(
          error,
          isRenewal
              ? 'Could not renew scheduler lease.'
              : 'Could not claim scheduler lease.',
        );
        _schedulerSelectionLeaseStale = false;
        _loadingSchedulerSelectionLease = false;
      });
    }
  }

  Future<void> _loadSchedulerSelectionLeaseReleaseIfRequested() async {
    final request = widget.schedulerSelectionLeaseReleaseRequest;
    final reader = widget.schedulerSelectionLeaseReleaseReader;
    final idempotencyKey = widget.schedulerSelectionLeaseReleaseIdempotencyKey;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null ||
        reader == null ||
        idempotencyKey == null ||
        idempotencyKey.trim().isEmpty) {
      if (mounted &&
          (_fetchedSchedulerSelectionLeaseRelease != null ||
              _schedulerSelectionLeaseReleaseError != null ||
              _loadingSchedulerSelectionLeaseRelease)) {
        setState(_clearSchedulerSelectionLeaseRelease);
      }
      return;
    }
    if (!_schedulerSelectionRequestVisible(request.conversationID)) {
      if (mounted &&
          (_fetchedSchedulerSelectionLeaseRelease != null ||
              _schedulerSelectionLeaseReleaseError != null ||
              _loadingSchedulerSelectionLeaseRelease)) {
        setState(_clearSchedulerSelectionLeaseRelease);
      }
      return;
    }
    // Release is also a selected-session display/action candidate. Do not
    // release a proof for a different Conversation or Run after the Sessions
    // selection has moved; the empty/default Gate remains request-compatible.
    final selectedConversationID = _selected?.conversation.id;
    final selectedRunID = _selectedRun?.runID;
    if ((selectedConversationID != null &&
            selectedConversationID != request.conversationID) ||
        (selectedRunID != null && selectedRunID != request.runID)) {
      if (mounted &&
          (_fetchedSchedulerSelectionLeaseRelease != null ||
              _schedulerSelectionLeaseReleaseError != null ||
              _loadingSchedulerSelectionLeaseRelease)) {
        setState(_clearSchedulerSelectionLeaseRelease);
      }
      return;
    }
    if (_loadingSchedulerSelectionLeaseRelease ||
        _fetchedSchedulerSelectionLeaseRelease != null ||
        _schedulerSelectionLeaseReleaseError != null) {
      return;
    }
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) setState(_clearSchedulerSelectionLeaseRelease);
      return;
    }
    if (_selected?.conversation.id != null &&
        _selected?.conversation.id != request.conversationID) {
      if (mounted) setState(_clearSchedulerSelectionLeaseRelease);
      return;
    }
    if (_selectedRun?.runID != null && _selectedRun?.runID != request.runID) {
      if (mounted) setState(_clearSchedulerSelectionLeaseRelease);
      return;
    }
    if (!_schedulerSelectionRequestVisible(request.conversationID)) {
      if (mounted) setState(_clearSchedulerSelectionLeaseRelease);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Scheduler lease release',
        );
    if (observationError != null) {
      if (mounted) {
        setState(() {
          _fetchedSchedulerSelectionLeaseRelease = null;
          _schedulerSelectionLeaseReleaseError = observationError;
          _schedulerSelectionLeaseReleaseStale = false;
        });
      }
      return;
    }
    final generation = ++_schedulerSelectionLeaseReleaseGeneration;
    setState(() {
      _loadingSchedulerSelectionLeaseRelease = true;
      _schedulerSelectionLeaseReleaseError = null;
      _schedulerSelectionLeaseReleaseStale = false;
    });
    try {
      final expectedRequest =
          ForgeSchedulerSelectionLeaseReleaseRequest.fromJson(request.toJson());
      final release = ForgeSchedulerSelectionLeaseRelease.fromJson(
        (await reader(expectedRequest, idempotencyKey)).toJson(),
      );
      if (!release.isFor(
            expectedRequest.conversationID,
            expectedRequest.runID,
            expectedRequest.attemptID,
          ) ||
          release.instanceID != expectedRequest.targetID ||
          release.epoch != expectedRequest.epoch ||
          release.authority.placementSelected ||
          release.authority.reservationCreated ||
          release.authority.leaseIssued ||
          release.authority.executionAuthorized ||
          release.authority.dispatchPerformed ||
          release.authority.auditPublished) {
        throw const FormatException(
          'Forge returned an invalid scheduler lease release.',
        );
      }
      if (!mounted ||
          generation != _schedulerSelectionLeaseReleaseGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedSchedulerSelectionLeaseRelease = release;
        _schedulerSelectionLeaseReleaseError = null;
        _schedulerSelectionLeaseReleaseStale = false;
        _loadingSchedulerSelectionLeaseRelease = false;
      });
    } catch (error) {
      if (!mounted || generation != _schedulerSelectionLeaseReleaseGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _schedulerSelectionLeaseReleaseGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedSchedulerSelectionLeaseRelease = null;
        _schedulerSelectionLeaseReleaseError = _friendlyError(
          error,
          'Could not release scheduler lease.',
        );
        _schedulerSelectionLeaseReleaseStale = false;
        _loadingSchedulerSelectionLeaseRelease = false;
      });
    }
  }

  Future<void> _loadClientInstanceSessionResourceConvergenceIfRequested({
    bool force = false,
  }) async {
    final owner = widget.clientInstanceSessionResourceConvergenceOwner;
    final reader = widget.clientInstanceSessionResourceConvergenceReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null) {
      if (mounted &&
          (_fetchedClientInstanceSessionResourceConvergence != null ||
              _clientInstanceSessionResourceConvergenceError != null ||
              _loadingClientInstanceSessionResourceConvergence)) {
        setState(_clearClientInstanceSessionResourceConvergence);
      }
      return;
    }
    if (_loadingClientInstanceSessionResourceConvergence) return;
    if (!force &&
        (_fetchedClientInstanceSessionResourceConvergence != null ||
            _clientInstanceSessionResourceConvergenceError != null)) {
      return;
    }
    final previous = _fetchedClientInstanceSessionResourceConvergence;
    final generation = ++_clientInstanceSessionResourceConvergenceGeneration;
    setState(() {
      _loadingClientInstanceSessionResourceConvergence = true;
      _clientInstanceSessionResourceConvergenceError = null;
      _clientInstanceSessionResourceConvergenceStale = previous != null;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final convergence =
          ForgeClientInstanceSessionResourceConvergence.fromJson(
            (await reader(owner)).toJson(),
          );
      if (convergence.owner != expectedOwner || !convergence.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid client-instance session/resource pair.',
        );
      }
      if (!mounted ||
          generation != _clientInstanceSessionResourceConvergenceGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedClientInstanceSessionResourceConvergence = convergence;
        _clientInstanceSessionResourceConvergenceError = null;
        _clientInstanceSessionResourceConvergenceStale = false;
        _loadingClientInstanceSessionResourceConvergence = false;
        _fetchedClientInstanceSessionView = convergence.sessionView;
        _clientInstanceSessionViewError = null;
        _clientInstanceSessionViewStale = false;
        _loadingClientInstanceSessionView = false;
        _fetchedClientInstanceResourceView = convergence.resourceView;
        _clientInstanceResourceViewError = null;
        _clientInstanceResourceViewStale = false;
        _loadingClientInstanceResourceView = false;
      });
      _reconcileSelectedClientInstanceProjection();
    } catch (error) {
      if (!mounted ||
          generation != _clientInstanceSessionResourceConvergenceGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _clientInstanceSessionResourceConvergenceGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedClientInstanceSessionResourceConvergence = previous;
        _clientInstanceSessionResourceConvergenceError = _friendlyError(
          error,
          'Could not load client-instance session/resource observations.',
        );
        _clientInstanceSessionResourceConvergenceStale = previous != null;
        _loadingClientInstanceSessionResourceConvergence = false;
      });
    }
  }

  Future<void> _loadClientInstanceSessionViewIfRequested({
    bool force = false,
  }) async {
    // A configured pair owns both projections. Do not fall back to two
    // independent reads during a forced refresh, otherwise the screen could
    // immediately replace a converged image with a mixed one.
    if (widget.clientInstanceSessionResourceConvergenceOwner != null &&
        widget.clientInstanceSessionResourceConvergenceReader != null) {
      return;
    }
    final owner = widget.clientInstanceSessionViewOwner;
    final reader = widget.clientInstanceSessionViewReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null) {
      if (mounted &&
          (_fetchedClientInstanceSessionView != null ||
              _clientInstanceSessionViewError != null ||
              _loadingClientInstanceSessionView)) {
        setState(_clearClientInstanceSessionView);
      }
      return;
    }
    if (_loadingClientInstanceSessionView) return;
    if (!force &&
        (_fetchedClientInstanceSessionView != null ||
            _clientInstanceSessionViewError != null)) {
      return;
    }
    final previousView = _fetchedClientInstanceSessionView;
    final generation = ++_clientInstanceSessionViewGeneration;
    setState(() {
      _loadingClientInstanceSessionView = true;
      _clientInstanceSessionViewError = null;
      _clientInstanceSessionViewStale = previousView != null;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final view = ForgeClientInstanceSessionView.fromJson(
        (await reader(owner)).toJson(),
      );
      if (view.owner != expectedOwner || !view.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid client-instance session view.',
        );
      }
      if (!mounted ||
          generation != _clientInstanceSessionViewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedClientInstanceSessionView = view;
        _clientInstanceSessionViewError = null;
        _clientInstanceSessionViewStale = false;
        _loadingClientInstanceSessionView = false;
      });
      _reconcileSelectedClientInstanceProjection();
    } catch (error) {
      if (!mounted || generation != _clientInstanceSessionViewGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _clientInstanceSessionViewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedClientInstanceSessionView = previousView;
        _clientInstanceSessionViewError = _friendlyError(
          error,
          'Could not load client-instance session view.',
        );
        _clientInstanceSessionViewStale = previousView != null;
        _loadingClientInstanceSessionView = false;
      });
    }
  }

  Future<void> _loadClientInstanceResourceViewIfRequested({
    bool force = false,
  }) async {
    if (widget.clientInstanceSessionResourceConvergenceOwner != null &&
        widget.clientInstanceSessionResourceConvergenceReader != null) {
      return;
    }
    final inFlight = _clientInstanceResourceViewRefresh;
    if (inFlight != null) {
      final inFlightWasForced = _clientInstanceResourceViewRefreshWasForced;
      await inFlight;
      if (!force ||
          (inFlightWasForced &&
              _clientInstanceResourceViewError == null &&
              !_clientInstanceResourceViewStale)) {
        return;
      }
    }
    final refresh = _loadClientInstanceResourceViewNow(force: force);
    _clientInstanceResourceViewRefresh = refresh;
    _clientInstanceResourceViewRefreshWasForced = force;
    try {
      await refresh;
    } finally {
      if (identical(_clientInstanceResourceViewRefresh, refresh)) {
        _clientInstanceResourceViewRefresh = null;
        _clientInstanceResourceViewRefreshWasForced = false;
      }
    }
  }

  Future<void> _loadClientInstanceResourceViewNow({bool force = false}) async {
    final owner = widget.clientInstanceResourceViewOwner;
    final reader = widget.clientInstanceResourceViewReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null) {
      if (mounted &&
          (_fetchedClientInstanceResourceView != null ||
              _clientInstanceResourceViewError != null ||
              _loadingClientInstanceResourceView)) {
        setState(_clearClientInstanceResourceView);
      }
      return;
    }
    if (_loadingClientInstanceResourceView) return;
    if (!force &&
        (_fetchedClientInstanceResourceView != null ||
            _clientInstanceResourceViewError != null)) {
      return;
    }
    final previousView = _fetchedClientInstanceResourceView;
    final generation = ++_clientInstanceResourceViewGeneration;
    setState(() {
      _loadingClientInstanceResourceView = true;
      _clientInstanceResourceViewError = null;
      _clientInstanceResourceViewStale = previousView != null;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final view = ForgeClientInstanceResourceView.fromJson(
        (await reader(owner)).toJson(),
      );
      if (view.owner != expectedOwner || !view.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid client-instance resource view.',
        );
      }
      if (!mounted ||
          generation != _clientInstanceResourceViewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedClientInstanceResourceView = view;
        _clientInstanceResourceViewError = null;
        _clientInstanceResourceViewStale = false;
        _loadingClientInstanceResourceView = false;
      });
      _reconcileSelectedClientInstanceProjection();
    } catch (error) {
      if (!mounted || generation != _clientInstanceResourceViewGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _clientInstanceResourceViewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedClientInstanceResourceView = previousView;
        _clientInstanceResourceViewError = _friendlyError(
          error,
          'Could not load client-instance resource view.',
        );
        _clientInstanceResourceViewStale = previousView != null;
        _loadingClientInstanceResourceView = false;
      });
    }
  }

  Future<void> _loadLifecycleRegistryIfRequested({bool force = false}) async {
    final owner = widget.lifecycleRegistryOwner;
    final reader = widget.lifecycleRegistryReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null) {
      if (mounted &&
          (_fetchedLifecycleRegistry != null ||
              _lifecycleRegistryError != null ||
              _loadingLifecycleRegistry)) {
        setState(_clearLifecycleRegistry);
      }
      return;
    }
    if (_loadingLifecycleRegistry) return;
    if (!force &&
        (_fetchedLifecycleRegistry != null ||
            _lifecycleRegistryError != null)) {
      return;
    }
    final previousRegistry = _fetchedLifecycleRegistry;
    final generation = ++_lifecycleRegistryGeneration;
    setState(() {
      _loadingLifecycleRegistry = true;
      _lifecycleRegistryError = null;
      _lifecycleRegistryStale = previousRegistry != null;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      // Re-decode the callback result through the strict wire boundary. This
      // keeps a candidate adapter from bypassing state joins, canonical
      // ordering, numeric bounds, or duplicate/unknown-key checks.
      final registry = ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
        (await reader(owner)).toJson(),
      );
      if (registry.owner != expectedOwner || !registry.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid or differently bound lifecycle registry.',
        );
      }
      if (!mounted ||
          generation != _lifecycleRegistryGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedLifecycleRegistry = registry;
        _lifecycleRegistryError = null;
        _lifecycleRegistryStale = false;
        _loadingLifecycleRegistry = false;
      });
    } catch (error) {
      if (!mounted || generation != _lifecycleRegistryGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _lifecycleRegistryGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedLifecycleRegistry = previousRegistry;
        _lifecycleRegistryError = _friendlyError(
          error,
          'Could not load lifecycle registry observation.',
        );
        _lifecycleRegistryStale = previousRegistry != null;
        _loadingLifecycleRegistry = false;
      });
    }
  }

  /// Loads one explicitly configured credential lifecycle candidate. This is
  /// deliberately not part of change-feed, resume, or manual refresh polling:
  /// the route is a one-shot metadata POST and callers must deliberately
  /// rebuild the candidate request before asking for another preview.
  Future<void> _loadDeviceCredentialCandidateIfRequested() async {
    final owner = widget.deviceCredentialCandidateOwner;
    final request = widget.deviceCredentialCandidateRequest;
    final reader = widget.deviceCredentialCandidateReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || request == null || reader == null) {
      if (mounted &&
          (_fetchedDeviceCredentialCandidate != null ||
              _deviceCredentialCandidateError != null ||
              _loadingDeviceCredentialCandidate)) {
        setState(_clearDeviceCredentialCandidate);
      }
      return;
    }
    if (_loadingDeviceCredentialCandidate ||
        _fetchedDeviceCredentialCandidate != null ||
        _deviceCredentialCandidateError != null) {
      return;
    }
    final generation = ++_deviceCredentialCandidateGeneration;
    setState(() {
      _loadingDeviceCredentialCandidate = true;
      _deviceCredentialCandidateError = null;
      _deviceCredentialCandidateStale = false;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final expectedRequest = ForgeDeviceCredentialLifecycleRequest.fromJson(
        request.toJson(),
      );
      final candidate = ForgeDeviceCredentialLifecycleCandidate.fromJson(
        (await reader(owner: owner, request: expectedRequest)).toJson(),
      );
      if (candidate.owner != expectedOwner ||
          candidate.deviceID != expectedRequest.deviceID ||
          candidate.action != expectedRequest.action ||
          candidate.revision != expectedRequest.expectedDeviceRevision ||
          !candidate.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid credential lifecycle candidate.',
        );
      }
      if (!mounted ||
          generation != _deviceCredentialCandidateGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedDeviceCredentialCandidate = candidate;
        _deviceCredentialCandidateError = null;
        _deviceCredentialCandidateStale = false;
        _loadingDeviceCredentialCandidate = false;
      });
    } catch (error) {
      if (!mounted || generation != _deviceCredentialCandidateGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _deviceCredentialCandidateGeneration ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedDeviceCredentialCandidate = null;
        _deviceCredentialCandidateError = _friendlyError(
          error,
          'Could not load credential lifecycle candidate.',
        );
        _deviceCredentialCandidateStale = false;
        _loadingDeviceCredentialCandidate = false;
      });
    }
  }

  Future<void> _loadRunAttemptLeaseDispatchPreflightIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.runAttemptLeaseDispatchPreflightRequest;
    final reader = widget.runAttemptLeaseDispatchPreflightReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null ||
        reader == null ||
        conversationID == null ||
        runID == null ||
        !request.isFor(conversationID, runID)) {
      if (mounted &&
          (_fetchedRunAttemptLeaseDispatchPreflight != null ||
              _runAttemptLeaseDispatchPreflightError != null ||
              _loadingRunAttemptLeaseDispatchPreflight ||
              _runAttemptLeaseDispatchPreflightStale)) {
        setState(_clearRunAttemptLeaseDispatchPreflight);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunAttemptLeaseDispatchPreflight) return;
    if (!force &&
        (_fetchedRunAttemptLeaseDispatchPreflight != null ||
            _runAttemptLeaseDispatchPreflightError != null)) {
      return;
    }
    // A preflight is still a selected-session candidate. Refresh the
    // owner-bound client-instance projection immediately before invoking the
    // candidate reader so a revoked or drifted instance cannot keep a stale
    // Run/Attempt binding alive. A configured inventory/resource pair is
    // checked at the same boundary because the preflight carries placement
    // and lease metadata that must not outlive its observation.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        setState(() {
          _fetchedRunAttemptLeaseDispatchPreflight = null;
          _runAttemptLeaseDispatchPreflightError =
              'Forge preflight is waiting for a fresh validated client-instance session/resource observation.';
          _runAttemptLeaseDispatchPreflightStale = false;
        });
      }
      return;
    }
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Forge preflight',
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      setState(() {
        _fetchedRunAttemptLeaseDispatchPreflight = null;
        _runAttemptLeaseDispatchPreflightError = observationError;
        _runAttemptLeaseDispatchPreflightStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final previous = _fetchedRunAttemptLeaseDispatchPreflight;
    final generation = ++_runAttemptLeaseDispatchPreflightGeneration;
    setState(() {
      _loadingRunAttemptLeaseDispatchPreflight = true;
      _runAttemptLeaseDispatchPreflightError = null;
      _runAttemptLeaseDispatchPreflightStale = previous != null;
    });
    try {
      final validatedRequest =
          ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(
            request.toJson(),
          );
      if (!validatedRequest.isFor(conversationID, runID)) {
        throw const FormatException(
          'Forge preflight request is bound to another selected Run.',
        );
      }
      final fixture = ForgePreflightFixture.fromJson(
        (await reader(validatedRequest)).toJson(),
      );
      if (!fixture.isFor(conversationID, runID) ||
          fixture.issuer != validatedRequest.owner.issuer ||
          fixture.subject != validatedRequest.owner.subject ||
          fixture.tenantId != validatedRequest.owner.tenantID ||
          !fixture.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid or differently bound preflight.',
        );
      }
      if (!mounted ||
          generation != _runAttemptLeaseDispatchPreflightGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunAttemptLeaseDispatchPreflight = fixture;
        _runAttemptLeaseDispatchPreflightError = null;
        _runAttemptLeaseDispatchPreflightStale = false;
        _loadingRunAttemptLeaseDispatchPreflight = false;
      });
    } catch (error) {
      if (!mounted ||
          generation != _runAttemptLeaseDispatchPreflightGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runAttemptLeaseDispatchPreflightGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunAttemptLeaseDispatchPreflight = previous;
        _runAttemptLeaseDispatchPreflightError = _friendlyError(
          error,
          'Could not load Run-Attempt lease preflight.',
        );
        _runAttemptLeaseDispatchPreflightStale = previous != null;
        _loadingRunAttemptLeaseDispatchPreflight = false;
      });
    }
  }

  Future<void> _loadRunnerDispatchPlanPreviewIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.runnerDispatchPlanPreviewRequest;
    final reader = widget.runnerDispatchPlanPreviewReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null ||
        reader == null ||
        conversationID == null ||
        runID == null ||
        !request.isFor(conversationID, runID)) {
      if (mounted &&
          (_fetchedRunnerDispatchPlanPreview != null ||
              _runnerDispatchPlanPreviewError != null ||
              _loadingRunnerDispatchPlanPreview ||
              _runnerDispatchPlanPreviewStale)) {
        setState(_clearRunnerDispatchPlanPreview);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunnerDispatchPlanPreview) return;
    if (!force &&
        (_fetchedRunnerDispatchPlanPreview != null ||
            _runnerDispatchPlanPreviewError != null)) {
      return;
    }
    // The dispatch-plan preview is still a candidate owner read. Re-read the
    // selected client-instance session/resource projection immediately before
    // invoking its reader so a revoked or drifted instance cannot keep a
    // stale Conversation binding alive. A configured inventory/resource pair
    // is refreshed at the same boundary because the plan contains placement
    // candidates whose metadata must not outlive that observation.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        setState(() {
          _fetchedRunnerDispatchPlanPreview = null;
          _runnerDispatchPlanPreviewError =
              'Runner dispatch-plan preview is waiting for a fresh validated client-instance session/resource observation.';
          _runnerDispatchPlanPreviewStale = false;
        });
      }
      return;
    }
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Runner dispatch-plan preview',
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      setState(() {
        _fetchedRunnerDispatchPlanPreview = null;
        _runnerDispatchPlanPreviewError = observationError;
        _runnerDispatchPlanPreviewStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final previous = _fetchedRunnerDispatchPlanPreview;
    final generation = ++_runnerDispatchPlanPreviewGeneration;
    setState(() {
      _loadingRunnerDispatchPlanPreview = true;
      _runnerDispatchPlanPreviewError = null;
      _runnerDispatchPlanPreviewStale = previous != null;
    });
    try {
      final validatedRequest =
          ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(
            request.toJson(),
          );
      if (!validatedRequest.isFor(conversationID, runID)) {
        throw const FormatException(
          'Forge Runner dispatch-plan request is bound to another selected Run.',
        );
      }
      final preview = ForgeRunnerDispatchPlanPreview.fromJson(
        (await reader(validatedRequest)).toJson(),
      );
      final plan = validatedRequest.dispatchPlan;
      final intent = plan.runnerExecutionIntent;
      if (!preview.isFor(conversationID, runID) ||
          !preview.isDisplayOnly ||
          preview.owner != validatedRequest.owner ||
          preview.attemptID != intent.attemptID ||
          preview.attemptState != plan.attemptState ||
          preview.commandID != intent.commandID ||
          preview.commandSHA256 != intent.commandSHA256 ||
          preview.intentTargetID != intent.targetID ||
          preview.leaseEpoch != plan.lease.epoch.toInt() ||
          preview.evaluatedAtMS != plan.placement.evaluatedAtMS ||
          preview.candidateCount != plan.placement.devices.length) {
        throw const FormatException(
          'Forge returned an invalid or differently bound Runner dispatch-plan preview.',
        );
      }
      if (!_runnerDispatchPlanTargetsMatchResources(preview)) {
        throw const FormatException(
          'Forge returned Runner dispatch-plan candidates outside the current resource observation.',
        );
      }
      if (!mounted ||
          generation != _runnerDispatchPlanPreviewGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunnerDispatchPlanPreview = preview;
        _runnerDispatchPlanPreviewError = null;
        _runnerDispatchPlanPreviewStale = false;
        _loadingRunnerDispatchPlanPreview = false;
      });
    } catch (error) {
      if (!mounted || generation != _runnerDispatchPlanPreviewGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runnerDispatchPlanPreviewGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunnerDispatchPlanPreview = previous;
        _runnerDispatchPlanPreviewError = _friendlyError(
          error,
          'Could not load Runner dispatch-plan preview.',
        );
        _runnerDispatchPlanPreviewStale = previous != null;
        _loadingRunnerDispatchPlanPreview = false;
      });
    }
  }

  Future<void> _loadRunnerDispatchAdmissionIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.runnerDispatchAdmissionRequest;
    final reader = widget.runnerDispatchAdmissionReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null ||
        reader == null ||
        conversationID == null ||
        runID == null ||
        request.conversationID != conversationID ||
        request.runID != runID) {
      if (mounted &&
          (_fetchedRunnerDispatchAdmission != null ||
              _runnerDispatchAdmissionError != null ||
              _loadingRunnerDispatchAdmission ||
              _runnerDispatchAdmissionStale)) {
        setState(_clearRunnerDispatchAdmission);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunnerDispatchAdmission) return;
    if (!force &&
        (_fetchedRunnerDispatchAdmission != null ||
            _runnerDispatchAdmissionError != null)) {
      return;
    }
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        setState(() {
          _fetchedRunnerDispatchAdmission = null;
          _runnerDispatchAdmissionError =
              'Runner dispatch admission is waiting for a fresh validated client-instance session/resource observation.';
          _runnerDispatchAdmissionStale = false;
        });
      }
      return;
    }
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Runner dispatch admission',
          force: true,
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      setState(() {
        _fetchedRunnerDispatchAdmission = null;
        _runnerDispatchAdmissionError = observationError;
        _runnerDispatchAdmissionStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final previous = _fetchedRunnerDispatchAdmission;
    final generation = ++_runnerDispatchAdmissionGeneration;
    setState(() {
      _loadingRunnerDispatchAdmission = true;
      _runnerDispatchAdmissionError = null;
      _runnerDispatchAdmissionStale = previous != null;
    });
    try {
      final validatedRequest = ForgeRunnerDispatchAdmissionRequest.fromJson(
        request.toJson(),
      );
      if (validatedRequest.conversationID != conversationID ||
          validatedRequest.runID != runID ||
          validatedRequest.command.leaseProof.attemptID !=
              validatedRequest.attemptID) {
        throw const FormatException(
          'Forge Runner dispatch admission request is bound to another Run.',
        );
      }
      if (!_runnerAdmissionTargetMatchesResources(
        validatedRequest.owner,
        validatedRequest.command.leaseProof.targetID,
      )) {
        throw const FormatException(
          'Forge Runner dispatch admission target is outside the current resource observation.',
        );
      }
      final admission = ForgeRunnerDispatchAdmission.fromJson(
        (await reader(validatedRequest)).toJson(),
      );
      if (!admission.isFor(conversationID, runID, validatedRequest.attemptID) ||
          admission.owner != validatedRequest.owner ||
          admission.commandID != validatedRequest.command.commandID ||
          admission.commandSHA256 != validatedRequest.command.commandSHA256() ||
          admission.targetID != validatedRequest.command.leaseProof.targetID ||
          admission.leaseEpoch != validatedRequest.command.leaseProof.epoch ||
          !_runnerAdmissionTargetMatchesResources(
            admission.owner,
            admission.targetID,
          ) ||
          !admission.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid or differently bound Runner dispatch admission.',
        );
      }
      if (!mounted ||
          generation != _runnerDispatchAdmissionGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunnerDispatchAdmission = admission;
        _runnerDispatchAdmissionError = null;
        _runnerDispatchAdmissionStale = false;
        _loadingRunnerDispatchAdmission = false;
      });
    } catch (error) {
      if (!mounted || generation != _runnerDispatchAdmissionGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runnerDispatchAdmissionGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunnerDispatchAdmission = previous;
        _runnerDispatchAdmissionError = _friendlyError(
          error,
          'Could not load Runner dispatch admission preview.',
        );
        _runnerDispatchAdmissionStale = previous != null;
        _loadingRunnerDispatchAdmission = false;
      });
    }
  }

  Future<void> _loadRunnerExecutionIntentIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.runnerExecutionIntentRequest;
    final reader = widget.runnerExecutionIntentReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null ||
        reader == null ||
        conversationID == null ||
        runID == null ||
        request.conversationID != conversationID ||
        request.run.runID != runID) {
      if (mounted &&
          (_fetchedRunnerExecutionIntent != null ||
              _runnerExecutionIntentError != null ||
              _loadingRunnerExecutionIntent ||
              _runnerExecutionIntentStale)) {
        setState(_clearRunnerExecutionIntent);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunnerExecutionIntent) return;
    if (!force &&
        (_fetchedRunnerExecutionIntent != null ||
            _runnerExecutionIntentError != null)) {
      return;
    }
    // Runner execution-intent preview is the authenticated candidate edge
    // closest to executable work. Re-read the selected client-instance
    // projection and any configured inventory/resource observations at this
    // boundary so a revoked instance or drifted resource image cannot keep a
    // stale Conversation/Run binding alive. A refresh gap or drift remains
    // request-free.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        setState(() {
          _fetchedRunnerExecutionIntent = null;
          _runnerExecutionIntentError =
              'Runner execution-intent preview is waiting for a fresh validated client-instance session/resource observation.';
          _runnerExecutionIntentStale = false;
        });
      }
      return;
    }
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Runner execution-intent preview',
          force: true,
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      setState(() {
        _fetchedRunnerExecutionIntent = null;
        _runnerExecutionIntentError = observationError;
        _runnerExecutionIntentStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final previous = _fetchedRunnerExecutionIntent;
    final generation = ++_runnerExecutionIntentGeneration;
    setState(() {
      _loadingRunnerExecutionIntent = true;
      _runnerExecutionIntentError = null;
      _runnerExecutionIntentStale = previous != null;
    });
    try {
      final validatedRequest = ForgeRunnerExecutionIntentRequest(
        owner: ForgeDeviceOwner.fromJson(request.owner.toJson()),
        conversationID: request.conversationID,
        prompt: request.prompt,
        run: request.run,
        binding: request.binding,
        command: request.command,
      );
      final expected = observeForgeRunnerExecutionIntent(validatedRequest);
      final preview = ForgeRunnerExecutionIntentObservation.fromJson(
        (await reader(validatedRequest)).toJson(),
      );
      if (!preview.isFor(conversationID, runID) ||
          !preview.isDisplayOnly ||
          jsonEncode(preview.toJson()) != jsonEncode(expected.toJson())) {
        throw const FormatException(
          'Forge returned an invalid or differently bound Runner execution-intent preview.',
        );
      }
      if (!mounted ||
          generation != _runnerExecutionIntentGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunnerExecutionIntent = preview;
        _runnerExecutionIntentError = null;
        _runnerExecutionIntentStale = false;
        _loadingRunnerExecutionIntent = false;
      });
    } catch (error) {
      if (!mounted || generation != _runnerExecutionIntentGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runnerExecutionIntentGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunnerExecutionIntent = previous;
        _runnerExecutionIntentError = _friendlyError(
          error,
          'Could not load Runner execution-intent preview.',
        );
        _runnerExecutionIntentStale = previous != null;
        _loadingRunnerExecutionIntent = false;
      });
    }
  }

  Future<void> _loadRunnerTransportAdmissionIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.runnerTransportAdmissionRequest;
    final reader = widget.runnerTransportAdmissionReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null ||
        reader == null ||
        conversationID == null ||
        runID == null ||
        request.conversationID != conversationID ||
        request.runID != runID) {
      if (mounted &&
          (_fetchedRunnerTransportAdmission != null ||
              _runnerTransportAdmissionError != null ||
              _loadingRunnerTransportAdmission ||
              _runnerTransportAdmissionStale)) {
        setState(_clearRunnerTransportAdmission);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunnerTransportAdmission) return;
    if (!force &&
        (_fetchedRunnerTransportAdmission != null ||
            _runnerTransportAdmissionError != null)) {
      return;
    }
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        setState(() {
          _fetchedRunnerTransportAdmission = null;
          _runnerTransportAdmissionError =
              'Runner transport admission is waiting for a fresh validated client-instance session/resource observation.';
          _runnerTransportAdmissionStale = false;
        });
      }
      return;
    }
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Runner transport admission',
          force: true,
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      setState(() {
        _fetchedRunnerTransportAdmission = null;
        _runnerTransportAdmissionError = observationError;
        _runnerTransportAdmissionStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final previous = _fetchedRunnerTransportAdmission;
    final generation = ++_runnerTransportAdmissionGeneration;
    setState(() {
      _loadingRunnerTransportAdmission = true;
      _runnerTransportAdmissionError = null;
      _runnerTransportAdmissionStale = previous != null;
    });
    try {
      final validatedRequest = ForgeRunnerTransportAdmissionRequest.fromJson(
        request.toJson(),
      );
      if (validatedRequest.conversationID != conversationID ||
          validatedRequest.runID != runID ||
          validatedRequest.command.leaseProof.attemptID !=
              validatedRequest.attemptID) {
        throw const FormatException(
          'Forge Runner transport admission request is bound to another Run.',
        );
      }
      if (!_runnerAdmissionTargetMatchesResources(
        validatedRequest.owner,
        validatedRequest.command.leaseProof.targetID,
      )) {
        throw const FormatException(
          'Forge Runner transport admission target is outside the current resource observation.',
        );
      }
      final admission = ForgeRunnerTransportAdmission.fromJson(
        (await reader(validatedRequest)).toJson(),
      );
      final expectedPath =
          '/api/v1/runners/${validatedRequest.command.leaseProof.targetID}/dispatch';
      if (!admission.isFor(conversationID, runID, validatedRequest.attemptID) ||
          admission.owner != validatedRequest.owner ||
          admission.commandID != validatedRequest.command.commandID ||
          admission.commandSHA256 != validatedRequest.command.commandSHA256() ||
          admission.targetID != validatedRequest.command.leaseProof.targetID ||
          admission.leaseEpoch != validatedRequest.command.leaseProof.epoch ||
          admission.transportMethod != 'POST' ||
          admission.transportPath != expectedPath ||
          admission.transportPayloadSHA256 !=
              validatedRequest.transport.payloadSHA256 ||
          !_runnerAdmissionTargetMatchesResources(
            admission.owner,
            admission.targetID,
          ) ||
          !admission.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid or differently bound Runner transport admission.',
        );
      }
      if (!mounted ||
          generation != _runnerTransportAdmissionGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunnerTransportAdmission = admission;
        _runnerTransportAdmissionError = null;
        _runnerTransportAdmissionStale = false;
        _loadingRunnerTransportAdmission = false;
      });
    } catch (error) {
      if (!mounted || generation != _runnerTransportAdmissionGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runnerTransportAdmissionGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunnerTransportAdmission = previous;
        _runnerTransportAdmissionError = _friendlyError(
          error,
          'Could not load Runner transport admission preview.',
        );
        _runnerTransportAdmissionStale = previous != null;
        _loadingRunnerTransportAdmission = false;
      });
    }
  }

  Future<void> _loadRunnerExecutionBoundaryIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.runnerExecutionBoundaryRequest;
    final reader = widget.runnerExecutionBoundaryReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null ||
        reader == null ||
        conversationID == null ||
        runID == null ||
        request.conversationID != conversationID ||
        request.runID != runID) {
      if (mounted &&
          (_fetchedRunnerExecutionBoundary != null ||
              _runnerExecutionBoundaryError != null ||
              _loadingRunnerExecutionBoundary ||
              _runnerExecutionBoundaryStale)) {
        setState(_clearRunnerExecutionBoundary);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    // An execution-boundary preview is the last read before a possible
    // Runner handoff. Re-read the selected instance projection at this
    // boundary so a stale mobile/Web/App selection cannot reuse a private Run
    // after its session/resource declaration has been revoked. This remains
    // a read-only, candidate-only gate; the execution-boundary reader still
    // decides whether a preview is available.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        setState(() {
          _fetchedRunnerExecutionBoundary = null;
          _runnerExecutionBoundaryError =
              'Runner execution-boundary preview is waiting for a fresh validated client-instance session/resource observation.';
          _runnerExecutionBoundaryStale = false;
        });
      }
      return;
    }
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Runner execution-boundary preview',
          force: true,
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      setState(() {
        _fetchedRunnerExecutionBoundary = null;
        _runnerExecutionBoundaryError = observationError;
        _runnerExecutionBoundaryStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunnerExecutionBoundary) return;
    if (!force &&
        (_fetchedRunnerExecutionBoundary != null ||
            _runnerExecutionBoundaryError != null)) {
      return;
    }
    final previous = _fetchedRunnerExecutionBoundary;
    final generation = ++_runnerExecutionBoundaryGeneration;
    setState(() {
      _loadingRunnerExecutionBoundary = true;
      _runnerExecutionBoundaryError = null;
      _runnerExecutionBoundaryStale = previous != null;
    });
    try {
      final validatedRequest =
          ForgeRunnerExecutionBoundaryPreviewRequest.fromJson(request.toJson());
      if (validatedRequest.conversationID != conversationID ||
          validatedRequest.runID != runID ||
          validatedRequest.command.leaseProof.attemptID !=
              validatedRequest.attemptID) {
        throw const FormatException(
          'Forge Runner execution boundary request is bound to another Run.',
        );
      }
      if (!_runnerAdmissionTargetMatchesResources(
        validatedRequest.owner,
        validatedRequest.command.leaseProof.targetID,
      )) {
        throw const FormatException(
          'Forge Runner execution-boundary target is outside the current resource observation.',
        );
      }
      final observation = ForgeRunnerExecutionBoundaryObservation.fromJson(
        (await reader(validatedRequest)).toJson(),
      );
      if (!observation.isFor(
            conversationID,
            runID,
            validatedRequest.attemptID,
          ) ||
          observation.owner != validatedRequest.owner ||
          observation.commandID != validatedRequest.command.commandID ||
          observation.commandSHA256 !=
              validatedRequest.command.commandSHA256() ||
          observation.targetID !=
              validatedRequest.command.leaseProof.targetID ||
          observation.leaseEpoch != validatedRequest.command.leaseProof.epoch ||
          !_runnerAdmissionTargetMatchesResources(
            observation.owner,
            observation.targetID,
          ) ||
          !observation.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid or differently bound Runner execution boundary.',
        );
      }
      if (!mounted ||
          generation != _runnerExecutionBoundaryGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunnerExecutionBoundary = observation;
        _runnerExecutionBoundaryError = null;
        _runnerExecutionBoundaryStale = false;
        _loadingRunnerExecutionBoundary = false;
      });
    } catch (error) {
      if (!mounted || generation != _runnerExecutionBoundaryGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runnerExecutionBoundaryGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunnerExecutionBoundary = previous;
        _runnerExecutionBoundaryError = _friendlyError(
          error,
          'Could not load Runner execution-boundary preview.',
        );
        _runnerExecutionBoundaryStale = previous != null;
        _loadingRunnerExecutionBoundary = false;
      });
    }
  }

  Future<void> _loadRunnerAttemptBoundaryIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.runnerAttemptBoundaryRequest;
    final reader = widget.runnerAttemptBoundaryReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null ||
        reader == null ||
        conversationID == null ||
        runID == null ||
        request.conversationID != conversationID ||
        request.runID != runID) {
      if (mounted &&
          (_fetchedRunnerAttemptBoundary != null ||
              _runnerAttemptBoundaryError != null ||
              _loadingRunnerAttemptBoundary ||
              _runnerAttemptBoundaryStale)) {
        setState(_clearRunnerAttemptBoundary);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunnerAttemptBoundary) return;
    if (!force &&
        (_fetchedRunnerAttemptBoundary != null ||
            _runnerAttemptBoundaryError != null)) {
      return;
    }
    // Attempt-boundary output is display-only, but it is the last metadata
    // edge before a caller could mistake a transition for executable work.
    // Re-read the selected client-instance projection and any configured
    // inventory/resource image before the candidate POST. A reader gap or
    // drift therefore remains request-free.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        setState(() {
          _fetchedRunnerAttemptBoundary = null;
          _runnerAttemptBoundaryError =
              'Runner Attempt boundary is waiting for a fresh validated client-instance session/resource observation.';
          _runnerAttemptBoundaryStale = false;
        });
      }
      return;
    }
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Runner Attempt boundary',
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      setState(() {
        _fetchedRunnerAttemptBoundary = null;
        _runnerAttemptBoundaryError = observationError;
        _runnerAttemptBoundaryStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final previous = _fetchedRunnerAttemptBoundary;
    final generation = ++_runnerAttemptBoundaryGeneration;
    setState(() {
      _loadingRunnerAttemptBoundary = true;
      _runnerAttemptBoundaryError = null;
      _runnerAttemptBoundaryStale = previous != null;
    });
    try {
      final validatedRequest =
          ForgeRunnerAttemptBoundaryPreviewRequest.fromJson(request.toJson());
      if (validatedRequest.conversationID != conversationID ||
          validatedRequest.runID != runID ||
          validatedRequest.command.leaseProof.attemptID !=
              validatedRequest.attemptID) {
        throw const FormatException(
          'Forge Runner Attempt boundary request is bound to another Run.',
        );
      }
      if (!_runnerAttemptBoundaryTargetMatchesResources(
        validatedRequest.owner,
        validatedRequest.command.leaseProof.targetID,
      )) {
        throw const FormatException(
          'Forge Runner Attempt boundary target is outside the current resource observation.',
        );
      }
      final observation = ForgeRunnerAttemptBoundaryObservation.fromJson(
        (await reader(validatedRequest)).toJson(),
      );
      if (!observation.isDisplayOnly ||
          !observation.isFor(
            conversationID,
            runID,
            validatedRequest.attemptID,
          ) ||
          observation.owner != validatedRequest.owner ||
          observation.commandID != validatedRequest.command.commandID ||
          observation.targetID !=
              validatedRequest.command.leaseProof.targetID ||
          observation.leaseEpoch != validatedRequest.command.leaseProof.epoch ||
          observation.currentAttemptState != validatedRequest.attemptState ||
          observation.transition != validatedRequest.transition ||
          !_runnerAttemptBoundaryTargetMatchesResources(
            observation.owner,
            observation.targetID,
          )) {
        throw const FormatException(
          'Forge returned an invalid or differently bound Runner Attempt boundary.',
        );
      }
      if (!mounted ||
          generation != _runnerAttemptBoundaryGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunnerAttemptBoundary = observation;
        _runnerAttemptBoundaryError = null;
        _runnerAttemptBoundaryStale = false;
        _loadingRunnerAttemptBoundary = false;
      });
    } catch (error) {
      if (!mounted || generation != _runnerAttemptBoundaryGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runnerAttemptBoundaryGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedRunnerAttemptBoundary = previous;
        _runnerAttemptBoundaryError = _friendlyError(
          error,
          'Could not load Runner Attempt boundary preview.',
        );
        _runnerAttemptBoundaryStale = previous != null;
        _loadingRunnerAttemptBoundary = false;
      });
    }
  }

  Future<void> _loadLocalRunnerPreviewIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.localRunnerPreviewRequest;
    final reader = widget.localRunnerPreviewReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null ||
        reader == null ||
        conversationID == null ||
        runID == null ||
        request.intent.conversationID != conversationID ||
        request.intent.run.runID != runID) {
      if (mounted &&
          (_fetchedLocalRunnerPreview != null ||
              _localRunnerPreviewError != null ||
              _loadingLocalRunnerPreview ||
              _localRunnerPreviewStale)) {
        setState(_clearLocalRunnerPreview);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingLocalRunnerPreview) return;
    if (!force &&
        (_fetchedLocalRunnerPreview != null ||
            _localRunnerPreviewError != null)) {
      return;
    }
    // Execution-readiness is the last metadata boundary before a caller could
    // mistake a local Runner preview for an executable result. Re-read the
    // selected client-instance pair and any separately configured
    // inventory/resource observations immediately before invoking the
    // candidate reader. A refresh gap or drift must block the candidate POST
    // and cannot broaden the selected Conversation back to the owner view.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        setState(() {
          _fetchedLocalRunnerPreview = null;
          _localRunnerPreviewError =
              'Local Runner execution-readiness preview is waiting for a fresh validated client-instance session/resource observation.';
          _localRunnerPreviewStale = false;
        });
      }
      return;
    }
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Local Runner execution-readiness preview',
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      setState(() {
        _fetchedLocalRunnerPreview = null;
        _localRunnerPreviewError = observationError;
        _localRunnerPreviewStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final previous = _fetchedLocalRunnerPreview;
    final generation = ++_localRunnerPreviewGeneration;
    setState(() {
      _loadingLocalRunnerPreview = true;
      _localRunnerPreviewError = null;
      _localRunnerPreviewStale = previous != null;
    });
    try {
      request.validateForPath(conversationID, request.intent.prompt.intentID);
      final preview = ForgeLocalRunnerPreviewObservation.fromJson(
        (await reader(request)).toJson(),
        request: request,
        conversationID: conversationID,
        intentID: request.intent.prompt.intentID,
      );
      if (preview.runnerExecutionIntent.runID != runID) {
        throw const FormatException(
          'Forge returned a local Runner preview for another Run.',
        );
      }
      if (!mounted ||
          generation != _localRunnerPreviewGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedLocalRunnerPreview = preview;
        _localRunnerPreviewError = null;
        _localRunnerPreviewStale = false;
        _loadingLocalRunnerPreview = false;
      });
    } catch (error) {
      if (!mounted || generation != _localRunnerPreviewGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _localRunnerPreviewGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedLocalRunnerPreview = previous;
        _localRunnerPreviewError = _friendlyError(
          error,
          'Could not load local Runner execution-readiness preview.',
        );
        _localRunnerPreviewStale = previous != null;
        _loadingLocalRunnerPreview = false;
      });
    }
  }

  Future<void> _loadExecutionReconciliationIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final input = widget.executionReconciliationInput;
    final reader = widget.executionReconciliationReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (input == null ||
        reader == null ||
        conversationID == null ||
        runID == null ||
        !input.isFor(conversationID, runID)) {
      if (mounted &&
          (_fetchedExecutionReconciliationObservation != null ||
              _executionReconciliationError != null ||
              _loadingExecutionReconciliation ||
              _executionReconciliationStale)) {
        setState(_clearExecutionReconciliation);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingExecutionReconciliation) return;
    if (!force &&
        (_fetchedExecutionReconciliationObservation != null ||
            _executionReconciliationError != null)) {
      return;
    }
    final previous = _fetchedExecutionReconciliationObservation;
    final generation = ++_executionReconciliationGeneration;
    setState(() {
      _loadingExecutionReconciliation = true;
      _executionReconciliationError = null;
      _executionReconciliationStale = previous != null;
    });
    try {
      final validatedInput = ForgeExecutionReconciliationInput.fromJson(
        input.toJson(),
      );
      if (!validatedInput.isFor(conversationID, runID)) {
        throw const FormatException(
          'Forge execution reconciliation input is bound to another Run.',
        );
      }
      final observation = ForgeExecutionReconciliationObservation.fromJson(
        (await reader(validatedInput)).toJson(),
      );
      final expected = observeForgeExecutionReconciliation(validatedInput);
      if (!observation.isFor(conversationID, runID) ||
          observation.owner != validatedInput.owner ||
          jsonEncode(observation.toJson()) != jsonEncode(expected.toJson())) {
        throw const FormatException(
          'Forge returned an invalid or differently bound execution reconciliation observation.',
        );
      }
      if (!mounted ||
          generation != _executionReconciliationGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedExecutionReconciliationObservation = observation;
        _executionReconciliationError = null;
        _executionReconciliationStale = false;
        _loadingExecutionReconciliation = false;
      });
    } catch (error) {
      if (!mounted || generation != _executionReconciliationGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _executionReconciliationGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedExecutionReconciliationObservation = previous;
        _executionReconciliationError = _friendlyError(
          error,
          'Could not load execution reconciliation observation.',
        );
        _executionReconciliationStale = previous != null;
        _loadingExecutionReconciliation = false;
      });
    }
  }

  Future<void> _loadExecutionConsentPreviewIfRequested({
    String? conversationID,
    bool force = false,
  }) async {
    final owner = widget.executionConsentPreviewOwner;
    final reader = widget.executionConsentPreviewReader;
    conversationID ??= _selected?.conversation.id;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null || conversationID == null) {
      if (mounted &&
          (_fetchedExecutionConsentPreview != null ||
              _executionConsentPreviewError != null ||
              _loadingExecutionConsentPreview ||
              _executionConsentPreviewStale)) {
        setState(_clearExecutionConsentPreview);
      }
      return;
    }
    // Execution-consent preview is bound to the selected Conversation. Once
    // a caller selects a client instance, keep the candidate read behind the
    // same local projection used by Prompt, Run, and pending Run-intent
    // reads. The projection is display-only and never grants consent.
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      if (mounted) setState(_clearExecutionConsentPreview);
      return;
    }
    if (_loadingExecutionConsentPreview) return;
    if (!force &&
        (_fetchedExecutionConsentPreview != null ||
            _executionConsentPreviewError != null)) {
      return;
    }
    final previous = _fetchedExecutionConsentPreview;
    final generation = ++_executionConsentPreviewGeneration;
    setState(() {
      _loadingExecutionConsentPreview = true;
      _executionConsentPreviewError = null;
      _executionConsentPreviewStale = previous != null;
    });
    try {
      final validatedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final preview = ForgeExecutionConsentPreview.fromJson(
        (await reader(
          owner: validatedOwner,
          conversationID: conversationID,
        )).toJson(),
      );
      if (preview.conversationID != conversationID) {
        throw const FormatException(
          'Forge returned an execution consent preview for another conversation.',
        );
      }
      if (!mounted ||
          generation != _executionConsentPreviewGeneration ||
          _selected?.conversation.id != conversationID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedExecutionConsentPreview = preview;
        _executionConsentPreviewError = null;
        _executionConsentPreviewStale = false;
        _loadingExecutionConsentPreview = false;
      });
    } catch (error) {
      if (!mounted || generation != _executionConsentPreviewGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _executionConsentPreviewGeneration ||
          _selected?.conversation.id != conversationID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      setState(() {
        _fetchedExecutionConsentPreview = previous;
        _executionConsentPreviewError = _friendlyError(
          error,
          'Could not load execution consent preview.',
        );
        _executionConsentPreviewStale = previous != null;
        _loadingExecutionConsentPreview = false;
      });
    }
  }

  Future<void> _loadPendingRunIntentsIfRequested({bool force = false}) async {
    final reader = widget.pendingRunIntentReader;
    final pageReader = widget.pendingRunIntentPageReader;
    final conversationID = _selected?.conversation.id;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (conversationID != null &&
        !_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if ((reader == null && pageReader == null) || conversationID == null) {
      if (mounted &&
          (_fetchedPendingRunIntents != null ||
              _pendingRunIntentError != null ||
              _loadingPendingRunIntents)) {
        setState(_clearPendingRunIntents);
      }
      return;
    }
    if (_loadingPendingRunIntents || _loadingMorePendingRunIntents) return;
    if (!force &&
        (_fetchedPendingRunIntents != null || _pendingRunIntentError != null)) {
      return;
    }
    final previousPage = _fetchedPendingRunIntents;
    final preserveTimelines = previousPage != null;
    final generation = ++_pendingRunIntentGeneration;
    void revokeIfHidden() {
      if (mounted &&
          _selected?.conversation.id == conversationID &&
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        setState(_clearRunDetailsForHiddenClientInstance);
      }
    }

    setState(() {
      _loadingPendingRunIntents = true;
      _pendingRunIntentError = null;
      _fetchedPendingRunIntents = null;
    });
    try {
      // Re-decode the callback result through the strict list boundary. This
      // preserves conversation binding, cursor ordering, pending status, and
      // the bounded initial sequence even when a test adapter constructs the
      // public value directly.
      final response = pageReader != null
          ? await pageReader(conversationID, null)
          : await reader!(conversationID);
      final page = ForgePendingRunIntentListPage.fromJson(
        _pendingRunIntentPageWire(response),
        requestedConversationID: conversationID,
      );
      if (!mounted ||
          generation != _pendingRunIntentGeneration ||
          _selected?.conversation.id != conversationID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        revokeIfHidden();
        return;
      }
      final samePage =
          preserveTimelines && _samePendingRunIntentPage(previousPage, page);
      setState(() {
        if (!samePage) _clearPendingRunIntentTimelines();
        _fetchedPendingRunIntents = page;
        _pendingRunIntentError = null;
        _loadingPendingRunIntents = false;
      });
    } catch (error) {
      if (!mounted || generation != _pendingRunIntentGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _pendingRunIntentGeneration ||
          _selected?.conversation.id != conversationID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        revokeIfHidden();
        return;
      }
      setState(() {
        _clearPendingRunIntentTimelines();
        _fetchedPendingRunIntents = null;
        _pendingRunIntentError = _friendlyError(
          error,
          'Could not load pending Run-intent metadata.',
        );
        _loadingPendingRunIntents = false;
      });
    }
  }

  Future<void> _loadMorePendingRunIntents() async {
    final reader = widget.pendingRunIntentPageReader;
    final conversationID = _selected?.conversation.id;
    final current = _fetchedPendingRunIntents;
    final cursor = current?.nextCursor;
    if (!mounted ||
        _sessionViewInvalidated ||
        _authorizationInvalidated ||
        reader == null ||
        conversationID == null ||
        current == null ||
        !current.hasMore ||
        cursor == null ||
        _loadingPendingRunIntents ||
        _loadingMorePendingRunIntents) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final generation = _pendingRunIntentGeneration;
    void revokeIfHidden() {
      if (mounted &&
          _selected?.conversation.id == conversationID &&
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        setState(_clearRunDetailsForHiddenClientInstance);
      }
    }

    setState(() {
      _loadingMorePendingRunIntents = true;
      _pendingRunIntentError = null;
    });
    try {
      final response = await reader(conversationID, cursor);
      final page = ForgePendingRunIntentListPage.fromJson(
        _pendingRunIntentPageWire(response),
        requestedConversationID: conversationID,
        before: cursor,
      );
      if (!mounted ||
          generation != _pendingRunIntentGeneration ||
          _selected?.conversation.id != conversationID ||
          !identical(current, _fetchedPendingRunIntents) ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        revokeIfHidden();
        return;
      }
      final seen = current.intents.map((intent) => intent.intentID).toSet();
      if (page.intents.any((intent) => !seen.add(intent.intentID))) {
        throw const FormatException(
          'Forge returned a duplicate pending Run-intent page.',
        );
      }
      if (page.intents.isNotEmpty) {
        final previous = current.intents.last;
        final first = page.intents.first;
        final firstID = utf8.encode(first.intentID);
        final previousID = utf8.encode(previous.intentID);
        var idComparison = 0;
        final sharedLength = firstID.length < previousID.length
            ? firstID.length
            : previousID.length;
        for (var index = 0; index < sharedLength; index++) {
          idComparison = firstID[index].compareTo(previousID[index]);
          if (idComparison != 0) break;
        }
        if (idComparison == 0) {
          idComparison = firstID.length.compareTo(previousID.length);
        }
        final older =
            first.submittedAtMS < previous.submittedAtMS ||
            (first.submittedAtMS == previous.submittedAtMS && idComparison < 0);
        if (!older) {
          throw const FormatException(
            'Forge returned an out-of-order pending Run-intent page.',
          );
        }
      }
      final merged = <ForgePendingRunIntentRecord>[
        ...current.intents,
        ...page.intents,
      ];
      setState(() {
        _fetchedPendingRunIntents = ForgePendingRunIntentListPage(
          conversationID: conversationID,
          intents: List.unmodifiable(merged),
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        );
        _pendingRunIntentError = null;
        _loadingMorePendingRunIntents = false;
      });
    } catch (error) {
      if (!mounted || generation != _pendingRunIntentGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _pendingRunIntentGeneration ||
          _selected?.conversation.id != conversationID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        revokeIfHidden();
        return;
      }
      setState(() {
        _pendingRunIntentError = _friendlyError(
          error,
          'Could not load more pending Run-intent metadata.',
        );
        _loadingMorePendingRunIntents = false;
      });
    }
  }

  Map<String, dynamic> _pendingRunIntentPageWire(
    ForgePendingRunIntentListPage page,
  ) => {
    'conversation_id': page.conversationID,
    'intents': page.intents
        .map(
          (intent) => {
            'intent_id': intent.intentID,
            'conversation_id': intent.conversationID,
            'prompt_id': intent.promptID,
            'project_id': intent.projectID,
            'profile_id': intent.profileID,
            'submitted_at_ms': intent.submittedAtMS,
            'aggregate_version': intent.aggregateVersion,
            'latest_sequence': intent.latestSequence,
            'status': intent.status,
          },
        )
        .toList(growable: false),
    'has_more': page.hasMore,
    if (page.nextCursor != null) 'next_cursor': page.nextCursor!.toJson(),
  };

  bool _samePendingRunIntentPage(
    ForgePendingRunIntentListPage? left,
    ForgePendingRunIntentListPage right,
  ) {
    if (left == null ||
        left.conversationID != right.conversationID ||
        left.hasMore != right.hasMore ||
        left.nextCursor?.submittedAtMS != right.nextCursor?.submittedAtMS ||
        left.nextCursor?.intentID != right.nextCursor?.intentID ||
        left.intents.length != right.intents.length) {
      return false;
    }
    for (var index = 0; index < left.intents.length; index++) {
      if (!left.intents[index].sameValue(right.intents[index])) return false;
    }
    return true;
  }

  Future<void> _loadPendingRunIntentTimeline(String intentID) async {
    final reader = widget.pendingRunIntentTimelineReader;
    final conversationID = _selected?.conversation.id;
    final page = _fetchedPendingRunIntents;
    if (!mounted ||
        _sessionViewInvalidated ||
        _authorizationInvalidated ||
        reader == null ||
        conversationID == null ||
        page == null) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final intent = page.intents.where((entry) => entry.intentID == intentID);
    if (intent.length != 1 ||
        _fetchedPendingRunIntentTimelines.containsKey(intentID) ||
        _loadingPendingRunIntentTimelines.contains(intentID)) {
      return;
    }
    final generation = _pendingRunIntentTimelineGeneration;
    void revokeIfHidden() {
      if (mounted &&
          _selected?.conversation.id == conversationID &&
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        setState(_clearRunDetailsForHiddenClientInstance);
      }
    }

    setState(() {
      _loadingPendingRunIntentTimelines.add(intentID);
      _pendingRunIntentTimelineErrors.remove(intentID);
    });
    try {
      // Re-decode through the strict timeline boundary. This preserves the
      // Conversation/intent binding, initial sequence, event type, and
      // payload-free closed shape even when a test adapter constructs the
      // public value directly.
      final timeline = ForgePendingRunIntentTimelinePage.fromJson(
        _pendingRunIntentTimelineWire(await reader(conversationID, intentID)),
        requestedConversationID: conversationID,
        requestedIntentID: intentID,
        requestedAfterSequence: 0,
      );
      if (timeline.events.single.emittedAtMS != intent.single.submittedAtMS) {
        throw const FormatException(
          'Forge returned an unbound pending Run-intent timeline.',
        );
      }
      if (!mounted ||
          generation != _pendingRunIntentTimelineGeneration ||
          _selected?.conversation.id != conversationID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        revokeIfHidden();
        return;
      }
      setState(() {
        _fetchedPendingRunIntentTimelines[intentID] = timeline;
        _pendingRunIntentTimelineErrors.remove(intentID);
        _loadingPendingRunIntentTimelines.remove(intentID);
      });
    } catch (error) {
      if (!mounted || generation != _pendingRunIntentTimelineGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _pendingRunIntentTimelineGeneration ||
          _selected?.conversation.id != conversationID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        revokeIfHidden();
        return;
      }
      setState(() {
        _fetchedPendingRunIntentTimelines.remove(intentID);
        _pendingRunIntentTimelineErrors[intentID] = _friendlyError(
          error,
          'Could not load pending Run-intent timeline.',
        );
        _loadingPendingRunIntentTimelines.remove(intentID);
      });
    }
  }

  Map<String, dynamic> _pendingRunIntentTimelineWire(
    ForgePendingRunIntentTimelinePage page,
  ) => {
    'conversation_id': page.conversationID,
    'intent_id': page.intentID,
    'after_sequence': page.afterSequence,
    'scanned_through_sequence': page.scannedThroughSequence,
    'has_more': page.hasMore,
    'events': page.events
        .map(
          (event) => {
            'event_id': event.eventID,
            'seq': event.sequence,
            'emitted_at_ms': event.emittedAtMS,
            'type': event.type,
          },
        )
        .toList(growable: false),
  };

  Future<void> _selectRun(ForgeConversationRun run) async {
    final conversationID = _selected?.conversation.id;
    if (conversationID == null || _selectedRun?.runID == run.runID) return;
    setState(() {
      _runTimelineGeneration++;
      _loadingRunTimeline = false;
      _clearDeviceObservation();
      _clearRunObserved();
      _clearRunExecutionEvidence();
      _clearSessionRunnerReceiptHistory();
      _clearSessionRunnerReconciliationProjection();
      _clearRunnerAttemptBoundaryPreview();
      _importedRunnerExecutionIntentObservation = null;
      _importedSessionRunnerReceiptObservation = null;
      _selectedRun = run;
      _runEvents = const [];
      _runTimelineSequence = 0;
      _hasMoreRunEvents = false;
      _runTimelineError = null;
    });
    await _loadRunTimeline(conversationID, run.runID);
    if (!mounted) return;
    await _loadDeviceObservationIfRequested(conversationID, run.runID);
    await _loadRunObservedIfRequested(
      conversationID: conversationID,
      runID: run.runID,
    );
    await _loadRunExecutionEvidenceIfRequested(
      conversationID: conversationID,
      runID: run.runID,
      force: true,
    );
    await _loadSessionRunnerReceiptHistoryIfRequested(
      conversationID: conversationID,
      runID: run.runID,
      force: true,
    );
    await _loadSessionRunnerReconciliationProjectionIfRequested(
      conversationID: conversationID,
      runID: run.runID,
      force: true,
    );
    await _loadRunnerAttemptBoundaryIfRequested(
      conversationID: conversationID,
      runID: run.runID,
      force: true,
    );
  }

  Future<void> _importOfflineDeviceObservation() async {
    final conversationID = _selected?.conversation.id;
    final runID = _selectedRun?.runID;
    if (conversationID == null || runID == null) return;

    final controller = TextEditingController();
    try {
      final observation = await showDialog<ForgeSessionDeviceObservation>(
        context: context,
        builder: (dialogContext) {
          String? errorMessage;
          var importing = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submit() async {
                if (importing) return;
                setDialogState(() {
                  importing = true;
                  errorMessage = null;
                });
                try {
                  final raw = controller.text.trim();
                  if (raw.isEmpty || raw.length > 2 * 1024 * 1024) {
                    throw const FormatException('size');
                  }
                  final wire = ForgeSessionDeviceObservationWire.fromJson(
                    jsonDecode(raw),
                  );
                  final parsed = ForgeSessionDeviceObservation.fromWire(wire);
                  if (!parsed.isFor(conversationID, runID)) {
                    throw const ForgeSessionDeviceObservationError(
                      'run_binding',
                    );
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(parsed);
                  }
                } catch (error) {
                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    importing = false;
                    errorMessage =
                        error is ForgeSessionDeviceObservationError &&
                            error.code == 'run_binding'
                        ? 'The observation must match the selected Run.'
                        : 'Invalid offline device observation.';
                  });
                }
              }

              return AlertDialog(
                title: Text(context.tr('Import offline device observation')),
                content: SizedBox(
                  width: min(MediaQuery.sizeOf(context).width - 48, 720),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr(
                            'Paste the canonical offline observation JSON for this selected Run. It is not saved or used for execution.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey(
                            'forge-offline-device-observation-json',
                          ),
                          controller: controller,
                          autofocus: true,
                          minLines: 8,
                          maxLines: 16,
                          enabled: !importing,
                          decoration: InputDecoration(
                            labelText: context.tr('Canonical observation JSON'),
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            context.tr(errorMessage!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: importing
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text(context.tr('Cancel')),
                  ),
                  FilledButton(
                    key: const ValueKey('forge-import-offline-observation'),
                    onPressed: importing ? null : submit,
                    child: Text(context.tr('Import')),
                  ),
                ],
              );
            },
          );
        },
      );
      if (!mounted || observation == null) return;
      if (_selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID) {
        return;
      }
      setState(() {
        _importedDeviceObservation = observation;
        _deviceObservationError = null;
      });
    } finally {
      controller.dispose();
    }
  }

  Future<void> _importOfflineRunnerExecutionIntent() async {
    final conversationID = _selected?.conversation.id;
    final runID = _selectedRun?.runID;
    if (conversationID == null || runID == null) return;

    final controller = TextEditingController();
    try {
      final observation = await showDialog<ForgeRunnerExecutionIntentObservation>(
        context: context,
        builder: (dialogContext) {
          String? errorMessage;
          var importing = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submit() async {
                if (importing) return;
                setDialogState(() {
                  importing = true;
                  errorMessage = null;
                });
                try {
                  final raw = controller.text.trim();
                  if (raw.isEmpty || raw.length > 256 * 1024) {
                    throw const FormatException('size');
                  }
                  final parsed = ForgeRunnerExecutionIntentObservation.fromJson(
                    jsonDecode(raw),
                  );
                  if (!parsed.isFor(conversationID, runID)) {
                    throw const FormatException('run_binding');
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(parsed);
                  }
                } catch (_) {
                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    importing = false;
                    errorMessage =
                        'Invalid or foreign Runner execution observation.';
                  });
                }
              }

              return AlertDialog(
                title: Text(context.tr('Import Runner execution observation')),
                content: SizedBox(
                  width: min(MediaQuery.sizeOf(context).width - 48, 720),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr(
                            'Paste the canonical Runner execution observation JSON for this selected Run. It is not saved or used for execution.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey(
                            'forge-runner-execution-observation-json',
                          ),
                          controller: controller,
                          autofocus: true,
                          minLines: 8,
                          maxLines: 16,
                          enabled: !importing,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              'Canonical Runner execution observation JSON',
                            ),
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            context.tr(errorMessage!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: importing
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text(context.tr('Cancel')),
                  ),
                  FilledButton(
                    key: const ValueKey(
                      'forge-import-runner-execution-observation-submit',
                    ),
                    onPressed: importing ? null : submit,
                    child: Text(context.tr('Import')),
                  ),
                ],
              );
            },
          );
        },
      );
      if (!mounted || observation == null) return;
      if (_selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID) {
        return;
      }
      setState(() {
        _importedRunnerExecutionIntentObservation = observation;
      });
    } finally {
      controller.dispose();
    }
  }

  Future<void> _importOfflineSessionRunnerReceiptObservation() async {
    final conversationID = _selected?.conversation.id;
    final runID = _selectedRun?.runID;
    if (conversationID == null || runID == null) return;

    final controller = TextEditingController();
    try {
      final observation = await showDialog<ForgeSessionRunnerReceiptObservation>(
        context: context,
        builder: (dialogContext) {
          String? errorMessage;
          var importing = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submit() async {
                if (importing) return;
                setDialogState(() {
                  importing = true;
                  errorMessage = null;
                });
                try {
                  final raw = controller.text.trim();
                  if (raw.isEmpty || raw.length > 256 * 1024) {
                    throw const FormatException('size');
                  }
                  final parsed = ForgeSessionRunnerReceiptObservation.fromJson(
                    jsonDecode(raw),
                  );
                  if (!parsed.isFor(conversationID, runID)) {
                    throw const FormatException('run_binding');
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(parsed);
                  }
                } catch (_) {
                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    importing = false;
                    errorMessage =
                        'Invalid or foreign session Runner receipt observation.';
                  });
                }
              }

              return AlertDialog(
                title: Text(
                  context.tr('Import session Runner receipt observation'),
                ),
                content: SizedBox(
                  width: min(MediaQuery.sizeOf(context).width - 48, 720),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr(
                            'Paste the canonical session Runner receipt observation JSON for this selected Run. It is not saved or used for execution.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey(
                            'forge-session-runner-receipt-observation-json',
                          ),
                          controller: controller,
                          autofocus: true,
                          minLines: 8,
                          maxLines: 16,
                          enabled: !importing,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              'Canonical session Runner receipt observation JSON',
                            ),
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            context.tr(errorMessage!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: importing
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text(context.tr('Cancel')),
                  ),
                  FilledButton(
                    key: const ValueKey(
                      'forge-import-session-runner-receipt-observation-submit',
                    ),
                    onPressed: importing ? null : submit,
                    child: Text(context.tr('Import')),
                  ),
                ],
              );
            },
          );
        },
      );
      if (!mounted || observation == null) return;
      if (_selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID) {
        return;
      }
      setState(() {
        _importedSessionRunnerReceiptObservation = observation;
      });
    } finally {
      controller.dispose();
    }
  }

  Future<void> _appendPrompt() async {
    final selected = _selected;
    if (selected == null || _appending) return;
    if (!_conversationVisibleFromSelectedClientInstance(
      selected.conversation.id,
    )) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    // The local instance filter is only a display projection. Refresh it at
    // the write boundary so a revoked session cannot keep a Prompt POST alive
    // after the selected instance changed. The default surface remains
    // request-free because this helper is a no-op without an injected reader.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        setState(() {
          _appendError =
              'Prompt append is waiting for a fresh validated client-instance session/resource observation.';
        });
      }
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Prompt append',
          force: true,
        );
    if (!mounted || _selected?.conversation.id != selected.conversation.id) {
      return;
    }
    if (observationError != null) {
      setState(() => _appendError = observationError);
      return;
    }
    if (!mounted || _selected?.conversation.id != selected.conversation.id) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(
      selected.conversation.id,
    )) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final convergenceError = _promptAppendInventoryResourceConvergenceError;
    if (convergenceError != null) {
      setState(() {
        _appendError = convergenceError;
      });
      return;
    }
    final pending = _pendingPrompt ?? _readPromptRequest(selected);
    if (pending == null) return;
    setState(() {
      _pendingPrompt = pending;
      _appending = true;
      _appendError = null;
    });
    try {
      final receiptOwner = widget.promptAppendReceiptOwner;
      final receiptSubmitter = widget.promptAppendReceiptSubmitter;
      final receiptOptIn = receiptOwner != null || receiptSubmitter != null;
      if (receiptOptIn && (receiptOwner == null || receiptSubmitter == null)) {
        throw const FormatException(
          'Prompt append receipt consumer is not fully configured.',
        );
      }
      ForgePromptAppendReceiptObservation? receipt;
      ForgePromptAppendResult? result;
      if (receiptOptIn) {
        final owner = ForgeDeviceOwner.fromJson(receiptOwner!.toJson());
        receipt = ForgePromptAppendReceiptObservation.fromJson(
          (await receiptSubmitter!(
            owner: owner,
            conversationID: selected.conversation.id,
            content: pending.content,
            expectedVersion: pending.expectedVersion,
            idempotencyKey: pending.idempotencyKey,
          )).toJson(),
        );
        final expectedReceipt = ForgePromptAppendReceiptObservation.fromInput(
          owner: owner,
          conversationID: selected.conversation.id,
          expectedVersion: pending.expectedVersion,
          content: pending.content,
          idempotencyKey: pending.idempotencyKey,
          promptID: receipt.receipt.promptID,
          createdAtMS: receipt.receipt.createdAtMS,
          replayed: receipt.receipt.replayed,
        );
        if (jsonEncode(receipt.toJson()) !=
            jsonEncode(expectedReceipt.toJson())) {
          throw const FormatException(
            'Forge returned a Prompt append receipt with invalid binding.',
          );
        }
      } else {
        result = await _api.appendPrompt(
          conversationID: selected.conversation.id,
          content: pending.content,
          expectedVersion: pending.expectedVersion,
          idempotencyKey: pending.idempotencyKey,
        );
      }
      if (!mounted ||
          _selected?.conversation.id != selected.conversation.id ||
          !_conversationVisibleFromSelectedClientInstance(
            selected.conversation.id,
          )) {
        return;
      }
      if (receipt != null) {
        final updated = ForgeOwnedConversation(
          conversation: selected.conversation,
          aggregateVersion: receipt.receipt.aggregateVersion,
        );
        setState(() {
          _selected = updated;
          _conversations = _replaceConversation(_conversations, updated);
          _pendingPrompt = null;
          _promptController.clear();
          _appending = false;
        });
        // The receipt intentionally carries no Prompt body. Refresh the
        // already-authorized history after the write so the display obtains
        // the persisted row through the ordinary owner-scoped read.
        await _loadPrompts(selected.conversation.id);
        if (!mounted ||
            _selected?.conversation.id != selected.conversation.id ||
            !_conversationVisibleFromSelectedClientInstance(
              selected.conversation.id,
            )) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              receipt.receipt.replayed
                  ? context.tr(
                      'Prompt retry replayed the existing message. It has not started a task.',
                    )
                  : context.tr('Prompt stored. It has not started a task.'),
            ),
          ),
        );
        return;
      }
      final appended = result!;
      final updated = ForgeOwnedConversation(
        conversation: selected.conversation,
        aggregateVersion: appended.aggregateVersion,
      );
      setState(() {
        _selected = updated;
        _conversations = _replaceConversation(_conversations, updated);
        _prompts = _uniquePrompts(
          [..._prompts, appended.prompt]..sort(_comparePrompts),
        );
        _pendingPrompt = null;
        _promptController.clear();
        _appending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appended.replayed
                ? context.tr(
                    'Prompt retry replayed the existing message. It has not started a task.',
                  )
                : context.tr('Prompt stored. It has not started a task.'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          !_conversationVisibleFromSelectedClientInstance(
            selected.conversation.id,
          )) {
        return;
      }
      final status = error is ForgeConversationsApiException
          ? error.statusCode
          : 0;
      final terminal = _isDefinitiveWriteFailure(error);
      setState(() {
        if (terminal) _pendingPrompt = null;
        _appendError = _friendlyError(
          error,
          'Forge did not confirm the prompt write.',
        );
        _appending = false;
      });
      if (status == 409) {
        await _refreshConversations(selectID: selected.conversation.id);
      }
    }
  }

  Future<void> _submitPendingRunIntent() async {
    final selected = _selected;
    final owner = widget.pendingRunIntentOwner;
    final submitter = widget.pendingRunIntentSubmitter;
    if (selected == null || owner == null || submitter == null) return;
    if (!_conversationVisibleFromSelectedClientInstance(
      selected.conversation.id,
    )) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        setState(() {
          _pendingRunIntentSubmitError =
              'Scheduling review is waiting for a fresh validated client-instance session/resource observation.';
        });
      }
      return;
    }
    if (!mounted || _selected?.conversation.id != selected.conversation.id) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(
      selected.conversation.id,
    )) {
      setState(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Scheduling review',
        );
    if (!mounted || _selected?.conversation.id != selected.conversation.id) {
      return;
    }
    if (observationError != null) {
      setState(() => _pendingRunIntentSubmitError = observationError);
      return;
    }
    final pending =
        _pendingRunIntentRequest ?? _readPendingRunIntentRequest(selected);
    if (pending == null) return;
    setState(() {
      _pendingRunIntentRequest = pending;
      _submittingPendingRunIntent = true;
      _pendingRunIntentSubmitError = null;
    });
    try {
      final result = await submitter(
        owner: owner,
        conversationID: selected.conversation.id,
        content: pending.content,
        expectedVersion: pending.expectedVersion,
        idempotencyKey: pending.idempotencyKey,
      );
      if (result.prompt.conversationID != selected.conversation.id ||
          result.prompt.role != 'user' ||
          result.prompt.content != pending.content ||
          result.intent.conversationID != selected.conversation.id ||
          result.intent.promptID != result.prompt.id ||
          result.initialEvent.sequence != 1 ||
          result.initialEvent.type != 'submitted' ||
          result.intent.status != 'pending') {
        throw const FormatException(
          'Forge returned an invalid scheduling-review receipt.',
        );
      }
      if (!mounted ||
          _selected?.conversation.id != selected.conversation.id ||
          !_conversationVisibleFromSelectedClientInstance(
            selected.conversation.id,
          )) {
        return;
      }
      final updated = ForgeOwnedConversation(
        conversation: selected.conversation,
        aggregateVersion: result.intent.aggregateVersion,
      );
      setState(() {
        _selected = updated;
        _conversations = _replaceConversation(_conversations, updated);
        _prompts = _uniquePrompts(
          [
            ..._prompts,
            ForgeConversationPrompt(
              id: result.prompt.id,
              conversationID: result.prompt.conversationID,
              role: result.prompt.role,
              content: result.prompt.content,
              createdAtMS: result.prompt.createdAtMS,
            ),
          ].toList()..sort(_comparePrompts),
        );
        _pendingRunIntentSubmission = result;
        _pendingRunIntentRequest = null;
        _promptController.clear();
        _submittingPendingRunIntent = false;
      });
      // A successful scheduling-review write advances the Conversation
      // aggregate and creates one inert receipt. If the caller explicitly
      // supplied the metadata reader, refresh it now so the shared Gate shows
      // the server-owned receipt without requiring a second manual sync.
      await _loadPendingRunIntentsIfRequested(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheduling review requested. No task has started.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          !_conversationVisibleFromSelectedClientInstance(
            selected.conversation.id,
          )) {
        return;
      }
      final status = error is ForgeConversationsApiException
          ? error.statusCode
          : 0;
      final terminal = _isDefinitiveWriteFailure(error);
      setState(() {
        if (terminal) _pendingRunIntentRequest = null;
        _pendingRunIntentSubmitError = _friendlyError(
          error,
          'Forge did not confirm the scheduling-review request.',
        );
        _submittingPendingRunIntent = false;
      });
      if (status == 409) {
        await _refreshConversations(selectID: selected.conversation.id);
      }
    }
  }

  _PendingRunIntentRequest? _readPendingRunIntentRequest(
    ForgeOwnedConversation selected,
  ) {
    final content = _promptController.text;
    if (content.trim().isEmpty) {
      setState(
        () => _pendingRunIntentSubmitError = 'Enter a prompt to review.',
      );
      return null;
    }
    return _PendingRunIntentRequest(
      content: content,
      expectedVersion: selected.aggregateVersion,
      idempotencyKey: newForgeIdempotencyKey(),
    );
  }

  _PendingPrompt? _readPromptRequest(ForgeOwnedConversation selected) {
    // Preserve the exact bytes entered by the user so Flutter has the same
    // Prompt semantics as the CLI, TUI, and API clients. Trimming is only a
    // validation check for an all-whitespace value.
    final content = _promptController.text;
    if (content.trim().isEmpty) {
      setState(() => _appendError = 'Enter a prompt to send.');
      return null;
    }
    return _PendingPrompt(
      content: content,
      expectedVersion: selected.aggregateVersion,
      idempotencyKey: newForgeIdempotencyKey(),
    );
  }

  bool _isDefinitiveWriteFailure(Object error) {
    if (error is! ForgeConversationsApiException) return false;
    if (error.statusCode == 409) return true;
    if (error.statusCode == 408 ||
        error.statusCode == 425 ||
        error.statusCode == 429) {
      return false;
    }
    return error.statusCode >= 400 && error.statusCode < 500;
  }

  bool _isDefinitiveOwnerReadFailure(Object error) {
    if (error is FormatException) return true;
    if (error is! ForgeConversationsApiException) return false;
    if (error.statusCode == 408 ||
        error.statusCode == 425 ||
        error.statusCode == 429 ||
        error.statusCode >= 500) {
      return false;
    }
    return error.statusCode >= 400;
  }

  bool _dropSelectedConversationAfterOwnerReadFailure(
    String conversationID,
    Object error,
  ) {
    if (!mounted ||
        !_isDefinitiveOwnerReadFailure(error) ||
        _selected?.conversation.id != conversationID) {
      return false;
    }
    setState(() {
      _conversationGeneration++;
      _conversations = _conversations
          .where((entry) => entry.conversation.id != conversationID)
          .toList(growable: false);
      _selected = null;
      _clearConversationDetails();
    });
    return true;
  }

  Future<void> _clearSessionIfUnauthorized(Object error) async {
    if (!_isAuthorizationFailure(error)) return;
    _authorizationInvalidated = true;
    // Once the owner credential has been rejected, stop the foreground change
    // feed before clearing the view.  A timer tick that survives credential
    // cleanup would immediately issue another request with the same rejected
    // owner and could race an explicit reauthentication/navigation flow.
    _stopChangeSyncTimer();
    if (mounted) {
      setState(() {
        _conversationGeneration++;
        _loadingConversations = false;
        _conversations = const [];
        _selected = null;
        _nextAfterID = null;
        _hasMoreConversations = false;
        _conversationsStale = false;
        _clearConversationDetails();
      });
    }
    try {
      await _credentialStore.clear();
    } catch (_) {
      // Keep the route usable so the user can retry sign-out and vault clear.
    }
  }

  bool _isAuthorizationFailure(Object error) =>
      error is ForgeConversationsApiException &&
      (error.isUnauthorized || error.isForbidden);

  void _signOutThisDevice() {
    if (_signingOut) return;
    setState(() {
      _signingOut = true;
      _signOutError = null;
      _sessionViewInvalidated = true;
      _conversationGeneration++;
      _locationSelectionGeneration++;
      _loadingConversations = false;
      _conversations = const [];
      _selected = null;
      _nextAfterID = null;
      _hasMoreConversations = false;
      _conversationsStale = false;
      _clearConversationDetails();
    });
    _stopChangeSyncTimer();
    unawaited(_revokeAndReturnToForgeLogin());
  }

  Future<void> _revokeAndReturnToForgeLogin() async {
    try {
      await _tokenRefresh.revokeCurrentTokens();
    } catch (_) {
      // A failed revoke must not trap the user in the signed-in screen.
    }
    try {
      await _credentialStore.clear();
    } catch (_) {
      if (mounted) {
        setState(() {
          _signingOut = false;
          _signOutError =
              'Could not clear stored Forge credentials. Try signing out again.';
          // A failed secure-store delete leaves the route available for an
          // explicit retry, but never restores the owner-scoped view.
          _conversationGeneration++;
          _loadingConversations = false;
          _conversations = const [];
          _selected = null;
          _nextAfterID = null;
          _hasMoreConversations = false;
          _conversationsStale = false;
          _clearConversationDetails();
        });
      }
      return;
    }
    await _conversationMetadataCache.clear();
    BrowserNavigation.replaceLocation(ForgeConversationsOAuth.loginLocation());
  }

  String _friendlyError(Object error, String fallback) {
    if (error is ForgeConversationsApiException) {
      if (error.isUnauthorized || error.isForbidden) {
        return _forgeAuthRequiredMessage;
      }
      if (error.statusCode == 0 || error.statusCode >= 500) {
        return error.message;
      }
      if (error.code == 'conflict') {
        return 'This conversation changed elsewhere. Refresh before sending again.';
      }
      return error.message;
    }
    if (error is FormatException) return 'Forge returned an invalid response.';
    return fallback;
  }

  void _signIn() => BrowserNavigation.replaceLocation(
    ForgeConversationsOAuth.loginLocation(retryAfterAuthorizationFailure: true),
  );

  void _setScopeKind(String? value) =>
      setState(() => _scopeKind = value ?? 'global');

  @override
  Widget build(BuildContext context) => _ForgeSessionsView(state: this);
}
