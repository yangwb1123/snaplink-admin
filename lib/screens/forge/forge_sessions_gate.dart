import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/forge_conversations_api_origin.dart';
import '../../services/forge_conversations_oauth.dart';
import '../../services/forge_credential_store.dart';
import '../../services/browser_navigation.dart';
import '../../api/forge_conversations_api.dart';
import '../../api/forge_conversations_models.dart';
import '../../api/forge_prompt_append_receipt.dart';
import '../../api/forge_attempt_request_preview.dart';
import '../../api/forge_device_inventory_models.dart';
import '../../api/forge_scheduler_selection_preview.dart';
import '../../api/forge_scheduler_selection_lease.dart';
import '../../api/forge_pending_run_intent.dart';
import '../../api/forge_runner_lease_fencing.dart';
import '../../api/forge_execution_lease_checkpoint.dart';
import '../../api/forge_session_placement.dart';
import '../../api/forge_run_intent_observation.dart';
import '../../api/forge_runner_execution_intent.dart';
import '../../api/forge_local_runner_preview.dart';
import '../../api/forge_run_execution_evidence.dart';
import '../../api/forge_run_observed.dart';
import '../../api/forge_session_runner_receipt_observation.dart';
import '../../api/forge_session_runner_receipt_vectors.dart';
import '../../api/forge_session_runner_receipt_history.dart';
import '../../api/forge_session_runner_reconciliation_projection.dart';
import '../../api/forge_execution_reconciliation_observation.dart';
import '../../api/forge_device_enrollment_heartbeat_lifecycle_registry.dart';
import '../../api/forge_device_credential_candidate.dart';
import '../../api/forge_client_instance_session_view.dart';
import '../../api/forge_client_instance_resource_view.dart';
import '../../api/forge_client_instance_session_resource_convergence.dart';
import '../../api/forge_preflight_fixture.dart';
import '../../api/forge_run_attempt_lease_dispatch_preflight.dart';
import '../../api/forge_runner_dispatch_plan_preview.dart';
import '../../api/forge_runner_dispatch_admission.dart';
import '../../api/forge_runner_transport_admission.dart';
import '../../api/forge_runner_execution_boundary.dart';
import '../../api/forge_runner_attempt_boundary.dart';
import 'forge_sessions_screen.dart';
import 'forge_sessions_device_observation.dart';

class ForgeSessionsGate extends StatefulWidget {
  final ForgeCredentialStore? credentialStore;
  final String? initialConversationID;

  /// Optional local client-instance selection hint. The value only narrows
  /// the owner-scoped list after a caller-supplied instance observation has
  /// converged; it never authenticates an instance or changes API requests.
  final String? initialClientInstanceID;

  /// Enables the explicitly reviewed, owner-scoped Conversation SSE read for
  /// a candidate or integration harness. The default Gate keeps polling.
  @visibleForTesting
  final bool enableConversationChangesStream;

  /// Bounded wait for the optional Conversation SSE read. The screen keeps
  /// its own upper-bound validation; the Gate default remains 15 seconds.
  @visibleForTesting
  final int conversationChangesStreamWaitMS;

  @visibleForTesting
  final http.Client? httpClient;
  final ForgeSessionDeviceObservation? deviceObservation;
  final ForgeSessionPlacementRequest? deviceObservationRequest;
  final ForgeRunIntentObservation? runIntentObservation;
  final ForgeRunnerExecutionIntentObservation? runnerExecutionIntentObservation;

  /// Explicit request and reader for the authenticated Runner
  /// execution-intent preview candidate. The default Gate leaves these unset
  /// and therefore makes no candidate request.
  final ForgeRunnerExecutionIntentRequest? runnerExecutionIntentRequest;
  final ForgeRunnerExecutionIntentReader? runnerExecutionIntentReader;

  /// Enables the reviewed, read-only Runner execution-intent candidate for a
  /// test or candidate harness. Production construction keeps this disabled.
  @visibleForTesting
  final bool enableRunnerExecutionIntentCandidate;

  /// Candidate-only origin for the Runner execution-intent POST.
  @visibleForTesting
  final String? runnerExecutionIntentCandidateApiOrigin;

  /// Optional local Runner execution-readiness observation. It remains
  /// display-only and process-local; supplying it never executes a command.
  final ForgeLocalRunnerPreviewObservation? localRunnerPreview;

  /// Explicit request and reader for the private local Runner execution
  /// readiness candidate. Both are required before the Gate can reach the
  /// route; the default Gate remains request-free.
  final ForgeLocalRunnerPreviewRequest? localRunnerPreviewRequest;
  final ForgeLocalRunnerPreviewReader? localRunnerPreviewReader;

  /// Enables the explicitly reviewed, read-only local Runner execution
  /// readiness candidate for a test or candidate harness. Production
  /// construction keeps this disabled.
  @visibleForTesting
  final bool enableLocalRunnerPreviewCandidate;

  /// Candidate-only origin for the local Runner execution readiness POST.
  /// The origin must be explicit when the candidate is enabled.
  @visibleForTesting
  final String? localRunnerPreviewCandidateApiOrigin;
  final ForgeRunObserved? runObserved;
  final ForgeRunObservedReader? runObservedReader;

  /// Explicit independent reader for the selected Run's content-free Runner
  /// receipt. It is forwarded only as an injected callback; the default Gate
  /// leaves it unset and does not derive or mount a receipt API route.
  final ForgeSessionRunnerReceiptObservationReader?
  sessionRunnerReceiptObservationReader;

  /// Enables the explicitly reviewed, read-only Run observation candidate
  /// adapter for a test or candidate harness. The default Gate keeps this
  /// disabled, so the candidate `/observation` route remains unreachable from
  /// production Web/App/Mobile construction.
  @visibleForTesting
  final bool enableRunObservedCandidate;

  /// Optional origin used by [enableRunObservedCandidate]. Supplying this in
  /// a candidate harness keeps the route's environment explicit; when it is
  /// omitted, the normal Forge Conversations origin is used.
  @visibleForTesting
  final String? runObservedCandidateApiOrigin;

  /// Enables the explicitly reviewed, read-only v2 inventory observation
  /// candidate adapter for a test or candidate harness. The default Gate
  /// keeps this disabled, so the candidate device route remains unreachable
  /// from production Web/App/Mobile construction.
  @visibleForTesting
  final bool enableDeviceInventoryV2Candidate;

  /// Optional origin used by [enableDeviceInventoryV2Candidate]. An explicit
  /// owner declaration is still required through [deviceInventoryOwner].
  @visibleForTesting
  final String? deviceInventoryV2CandidateApiOrigin;
  final ForgeRunExecutionEvidence? runExecutionEvidence;
  final ForgeSessionRunnerReceiptObservation? sessionRunnerReceiptObservation;
  final ForgeSessionRunnerReceiptVectors? sessionRunnerReceiptVectorsPreview;
  final ForgeSessionRunnerReceiptVectorsFileReader?
  sessionRunnerReceiptVectorsFileReader;
  final ForgeSessionRunnerReceiptHistory? sessionRunnerReceiptHistoryPreview;
  final ForgeSessionRunnerReceiptHistoryFileReader?
  sessionRunnerReceiptHistoryFileReader;
  final ForgeSessionRunnerReconciliationProjection?
  sessionRunnerReconciliationProjectionPreview;
  final ForgeSessionRunnerReconciliationProjectionFileReader?
  sessionRunnerReconciliationProjectionFileReader;

  /// Explicit request and reader for the authenticated, read-only EXECUTE
  /// receipt-history reduction candidate. The default Gate leaves both unset
  /// so the shared Web/App/Mobile surface never requests history remotely.
  final ForgeSessionRunnerReceiptHistory? sessionRunnerReceiptHistoryRequest;
  final ForgeSessionRunnerReceiptHistoryReader?
  sessionRunnerReceiptHistoryReader;

  /// Explicit request and reader for the authenticated, read-only manual
  /// reconciliation projection candidate. The default Gate leaves both
  /// unset so the shared Web/App/Mobile surface never requests it remotely.
  final ForgeSessionRunnerReceiptHistory?
  sessionRunnerReconciliationProjectionRequest;
  final ForgeSessionRunnerReconciliationProjectionReader?
  sessionRunnerReconciliationProjectionReader;

  /// Enables the reviewed reconciliation projection reader for a test or
  /// candidate harness. Production construction keeps this false.
  @visibleForTesting
  final bool enableSessionRunnerReconciliationProjectionCandidate;

  /// Candidate-only origin for the reconciliation projection POST. It is
  /// required when the candidate is enabled.
  @visibleForTesting
  final String? sessionRunnerReconciliationProjectionCandidateApiOrigin;

  /// Enables the explicit two-step reconciliation candidate for a test or
  /// candidate harness. When enabled, the Gate first canonicalizes the
  /// supplied history through the history preview and then derives the
  /// projection from that returned value. Production construction keeps this
  /// false, so the default Gate remains request-free.
  @visibleForTesting
  final bool enableSessionRunnerReconciliationProjectionHistoryChainCandidate;

  /// Enables the reviewed remote history reader for a test or candidate
  /// harness. Production construction keeps this false.
  @visibleForTesting
  final bool enableSessionRunnerReceiptHistoryCandidate;

  /// Candidate-only origin for the history reduction POST. It is required
  /// when [enableSessionRunnerReceiptHistoryCandidate] is true.
  @visibleForTesting
  final String? sessionRunnerReceiptHistoryCandidateApiOrigin;

  /// Explicit reader for the authenticated Run/receipt evidence join. The
  /// default Gate leaves it unset, so the shared Web/App/Mobile surface makes
  /// no evidence request during startup or refresh.
  final ForgeRunExecutionEvidenceReader? runExecutionEvidenceReader;

  /// Enables the reviewed, read-only Run execution-evidence candidate for a
  /// test or candidate harness. Production construction keeps this false.
  @visibleForTesting
  final bool enableRunExecutionEvidenceCandidate;

  /// Candidate-only origin for the Run execution-evidence POST. It must be
  /// explicit when [enableRunExecutionEvidenceCandidate] is true.
  @visibleForTesting
  final String? runExecutionEvidenceCandidateApiOrigin;

  /// Optional caller-supplied restart-boundary reconciliation observation.
  /// The Gate never fetches it by default; when supplied it remains strictly
  /// display-only and candidate-bound.
  final ForgeExecutionReconciliationObservation?
  executionReconciliationObservation;

  /// Optional explicit restart image and reader for the authenticated
  /// execution-reconciliation candidate. The default Gate leaves both unset
  /// and therefore cannot make this candidate request.
  final ForgeExecutionReconciliationInput? executionReconciliationInput;
  final ForgeExecutionReconciliationReader? executionReconciliationReader;

  /// Enables the explicitly reviewed execution-reconciliation candidate for a
  /// test or candidate harness. Production construction keeps this false.
  @visibleForTesting
  final bool enableExecutionReconciliationCandidate;

  /// Optional origin used only by the explicitly enabled candidate adapter.
  @visibleForTesting
  final String? executionReconciliationCandidateApiOrigin;

  /// Explicit owner and reader for the private execution-consent preview
  /// candidate. The selected Conversation is supplied by the Sessions screen;
  /// the default Gate leaves this seam unset and request-free.
  final ForgeDeviceOwner? executionConsentPreviewOwner;
  final ForgeExecutionConsentPreviewReader? executionConsentPreviewReader;

  /// Enables the reviewed, read-only execution-consent preview candidate for
  /// a test or candidate harness. Production construction keeps this false.
  @visibleForTesting
  final bool enableExecutionConsentPreviewCandidate;

  /// Candidate-only origin for the execution-consent preview GET. It must be
  /// explicit when [enableExecutionConsentPreviewCandidate] is true.
  @visibleForTesting
  final String? executionConsentPreviewCandidateApiOrigin;

  /// Optional caller-supplied offline Attempt request contract. It remains a
  /// display-only value and never creates a Run or dispatches a task.
  final ForgeAttemptRequestPreviewFixture? attemptRequestPreview;

  /// Optional local Runner Attempt lifecycle boundary observation. It is
  /// accepted only through the explicit scope below and never opens a route.
  final ForgeRunnerAttemptBoundaryObservation? runnerAttemptBoundaryPreview;
  final ForgeRunnerAttemptBoundaryScope? runnerAttemptBoundaryScope;
  final ForgeRunnerAttemptBoundaryFileReader? runnerAttemptBoundaryFileReader;

  /// Explicit request and reader for the authenticated Attempt boundary
  /// preview candidate. The default Gate leaves both unset and request-free.
  final ForgeRunnerAttemptBoundaryPreviewRequest? runnerAttemptBoundaryRequest;
  final ForgeRunnerAttemptBoundaryReader? runnerAttemptBoundaryReader;

  /// Enables the reviewed, read-only Attempt boundary candidate for a test or
  /// candidate harness. Production construction keeps this disabled.
  @visibleForTesting
  final bool enableRunnerAttemptBoundaryCandidate;

  /// Candidate-only origin for the Attempt boundary POST. It must match the
  /// API origin exactly when the candidate is enabled.
  @visibleForTesting
  final String? runnerAttemptBoundaryCandidateApiOrigin;

  /// Enables the explicit local Attempt boundary projection/import seam. The
  /// default Gate keeps this disabled and request-free.
  @visibleForTesting
  final bool enableRunnerAttemptBoundaryProjection;

  /// Optional caller-supplied pending Run-intent receipt. It remains a
  /// metadata-only display value and never creates or dispatches a Run.
  final ForgePendingRunIntentFixture? pendingRunIntentPreview;

  /// Explicitly enables the candidate scheduling-review submit action. The
  /// default Gate leaves it disabled, so normal Web/App/Mobile construction
  /// cannot POST `/run-intents`.
  @visibleForTesting
  final bool enablePendingRunIntentCandidate;

  /// Owner and candidate origin are both required before the Gate creates the
  /// submitter. The authenticated server remains the owner authority.
  final ForgeDeviceOwner? pendingRunIntentOwner;
  @visibleForTesting
  final String? pendingRunIntentCandidateApiOrigin;

  /// Explicit owner and submitter for the authenticated, content-free Prompt
  /// append receipt path. Supplying these values is the only way for the
  /// Sessions Screen to consume the receipt projection; the default Gate
  /// leaves both unset and request-free.
  final ForgeDeviceOwner? promptAppendReceiptOwner;
  final ForgePromptAppendReceiptSubmitter? promptAppendReceiptSubmitter;

  /// Enables the reviewed Prompt append receipt adapter for a test or
  /// candidate harness. Production construction keeps this false.
  @visibleForTesting
  final bool enablePromptAppendReceiptCandidate;

  /// Candidate-only origin for the authenticated Prompt append receipt POST.
  /// It must be explicit when the candidate is enabled.
  @visibleForTesting
  final String? promptAppendReceiptCandidateApiOrigin;

  /// Requires an owner-bound inventory/resource convergence before an
  /// explicit Prompt append can be submitted. The default remains false so
  /// the ordinary storage-only Prompt journey is unchanged; candidate
  /// harnesses can enable this to keep the selected shared-session journey
  /// aligned with its resource observation.
  @visibleForTesting
  final bool requireDeviceInventoryResourceConvergenceForPromptAppend;

  /// Optional, explicitly injected owner-bound inventory candidate seam. The
  /// default Gate does not provide it, so production `/devices` remains
  /// unreachable until its separate governance gate is accepted.
  final ForgeDeviceOwner? deviceInventoryOwner;
  final ForgeDeviceInventoryCandidateReader? deviceInventoryReader;

  /// Enables the reviewed, read-only v1 inventory candidate adapter for a
  /// test or candidate harness. Normal Web/App/Mobile construction keeps it
  /// disabled and request-free.
  @visibleForTesting
  final bool enableDeviceInventoryCandidate;

  /// Candidate-only origin for the v1 inventory adapter. It must be explicit
  /// when the adapter is enabled so the production Coordinator cannot be
  /// reached accidentally.
  @visibleForTesting
  final String? deviceInventoryCandidateApiOrigin;

  /// Optional, explicitly injected owner-bound lossless v2 inventory reader.
  /// The default Gate leaves it unset, so no v2 device request is made.
  final ForgeDeviceInventoryV2Reader? deviceInventoryV2Reader;

  /// Optional, explicitly injected owner-bound paired inventory/resource
  /// reader. The default Gate leaves it unset, so the two candidate GETs are
  /// never issued as a pair.
  final ForgeDeviceOwner? deviceInventoryResourceConvergenceOwner;
  final ForgeDeviceInventoryResourceConvergenceReader?
  deviceInventoryResourceConvergenceReader;

  /// Enables the reviewed, read-only paired inventory/resource candidate for
  /// a test or candidate harness. Normal Web/App/Mobile construction keeps it
  /// disabled and request-free.
  @visibleForTesting
  final bool enableDeviceInventoryResourceConvergenceCandidate;

  /// Candidate-only origin for the paired inventory/resource GETs.
  @visibleForTesting
  final String? deviceInventoryResourceConvergenceCandidateApiOrigin;

  /// Optional requirements for the explicit registry-backed placement
  /// preview candidate. The default Gate leaves this unset, so no POST is
  /// issued and production scheduling remains unreachable.
  final ForgeDevicePlacementRequirements?
  deviceInventoryRegistryPlacementRequirements;
  final ForgeDeviceRegistryPlacementPreviewReader?
  deviceInventoryRegistryPlacementPreviewReader;

  /// Enables the reviewed, read-only registry placement preview candidate for
  /// a test or migration harness. Normal Web/App/Mobile construction keeps it
  /// disabled and request-free.
  @visibleForTesting
  final bool enableDeviceInventoryRegistryPlacementPreviewCandidate;

  /// Candidate-only origin for the registry placement preview adapter.
  @visibleForTesting
  final String? deviceInventoryRegistryPlacementPreviewCandidateApiOrigin;

  /// Explicit request and reader for the planning-only scheduler-selection
  /// preview. The default Gate leaves it disabled and request-free.
  final ForgeSchedulerSelectionPreviewRequest? schedulerSelectionPreviewRequest;
  final ForgeSchedulerSelectionPreviewReader? schedulerSelectionPreviewReader;

  /// Enables the reviewed, read-only scheduler-selection adapter for a test
  /// or candidate harness. Normal Web/App/Mobile construction keeps it off.
  @visibleForTesting
  final bool enableSchedulerSelectionPreviewCandidate;

  /// Candidate-only origin for the scheduler-selection adapter.
  @visibleForTesting
  final String? schedulerSelectionPreviewCandidateApiOrigin;

  /// Explicit request and reader for the accepted EXECUTE scheduler lease
  /// claim. The default Gate leaves this unset and request-free.
  final ForgeSchedulerSelectionLeaseRequest? schedulerSelectionLeaseRequest;
  final ForgeSchedulerSelectionLeaseReader? schedulerSelectionLeaseReader;

  /// Enables the reviewed scheduler-lease candidate for a test or candidate
  /// harness. Claiming is single-shot and bound to the supplied key.
  @visibleForTesting
  final bool enableSchedulerSelectionLeaseCandidate;

  /// Candidate-only origin for the scheduler-lease POST.
  @visibleForTesting
  final String? schedulerSelectionLeaseCandidateApiOrigin;

  /// Stable idempotency key retained across an explicit caller retry.
  @visibleForTesting
  final String? schedulerSelectionLeaseIdempotencyKey;

  /// Explicit request and reader for the accepted EXECUTE scheduler-lease
  /// renewal. The default Gate leaves this unset and request-free.
  final ForgeSchedulerSelectionLeaseRenewalRequest?
  schedulerSelectionLeaseRenewalRequest;
  final ForgeSchedulerSelectionLeaseRenewalReader?
  schedulerSelectionLeaseRenewalReader;

  /// Enables the reviewed scheduler-lease renewal candidate for a test or
  /// candidate harness. Renewal is one-shot and bound to the supplied proof
  /// and idempotency key.
  @visibleForTesting
  final bool enableSchedulerSelectionLeaseRenewalCandidate;

  /// Candidate-only origin for the scheduler-lease renewal POST.
  @visibleForTesting
  final String? schedulerSelectionLeaseRenewalCandidateApiOrigin;

  /// Stable idempotency key retained across an explicit renewal retry.
  @visibleForTesting
  final String? schedulerSelectionLeaseRenewalIdempotencyKey;

  /// Explicit request and reader for the accepted EXECUTE scheduler-lease
  /// release. The default Gate leaves this unset and request-free.
  final ForgeSchedulerSelectionLeaseReleaseRequest?
  schedulerSelectionLeaseReleaseRequest;
  final ForgeSchedulerSelectionLeaseReleaseReader?
  schedulerSelectionLeaseReleaseReader;

  /// Enables the reviewed scheduler-lease release candidate for a test or
  /// candidate harness. Release is one-shot and bound to the supplied proof
  /// and idempotency key.
  @visibleForTesting
  final bool enableSchedulerSelectionLeaseReleaseCandidate;

  /// Candidate-only origin for the scheduler-lease release POST.
  @visibleForTesting
  final String? schedulerSelectionLeaseReleaseCandidateApiOrigin;

  /// Stable idempotency key retained across an explicit release retry.
  @visibleForTesting
  final String? schedulerSelectionLeaseReleaseIdempotencyKey;

  /// Optional, explicitly injected v2 persisted inventory observation. The
  /// default Gate leaves it unset; when present it is display-only and local.
  final ForgeDeviceInventoryPageV2? deviceInventoryV2Preview;

  /// Optional bounded JSON reader for the local v2 inventory preview. The
  /// default Gate leaves it unset; the platform picker and injected readers
  /// remain request-free and do not enable inventory authority.
  final ForgeDeviceInventoryV2FileReader? deviceInventoryV2FileReader;

  /// Optional, explicitly injected v2 placement comparison. The default Gate
  /// leaves it unset; when present it is display-only and local.
  final ForgeDeviceInventoryPlacementEvaluationV2?
  deviceInventoryPlacementEvaluationV2Preview;

  /// Optional bounded JSON reader for the local v2 placement comparison. The
  /// default Gate leaves it unset; the preview never selects or reserves a
  /// target and never opens a placement route.
  final ForgeDeviceInventoryPlacementEvaluationV2FileReader?
  deviceInventoryPlacementEvaluationV2FileReader;

  /// Optional, explicitly injected persisted-inventory placement evaluation.
  /// The default Gate leaves it unset; when present it is display-only and
  /// local.
  final ForgeDeviceInventoryPlacementEvaluationFixture?
  deviceInventoryPlacementEvaluationPreview;

  /// Optional bounded JSON reader for the local placement evaluation preview.
  /// The preview never selects or reserves a target and never opens a route.
  final ForgeDeviceInventoryPlacementEvaluationFileReader?
  deviceInventoryPlacementEvaluationFileReader;

  /// Optional, explicitly injected persisted-inventory placement batch
  /// comparison. The default Gate leaves it unset; when present it remains a
  /// display-only value and never selects or reserves a target.
  final ForgeDeviceInventoryPlacementBatchEvaluationFixture?
  deviceInventoryPlacementBatchEvaluationPreview;

  /// Optional bounded JSON reader for the local placement batch preview. The
  /// default Gate leaves it unset; the preview never selects or reserves a
  /// target and never opens a scheduling route.
  final ForgeDeviceInventoryPlacementBatchEvaluationFileReader?
  deviceInventoryPlacementBatchEvaluationFileReader;

  /// Optional, explicitly injected owner-scoped pending Run-intent metadata
  /// seam. The default Gate leaves it unset; the opt-in pending Run-intent
  /// candidate supplies the same reader from its authenticated API adapter.
  final ForgePendingRunIntentReader? pendingRunIntentReader;

  /// Optional paged variant of [pendingRunIntentReader]. The first call uses
  /// a null cursor; subsequent calls receive the strictly validated cursor
  /// from the previous page. The default Gate leaves it unset.
  final ForgePendingRunIntentPageReader? pendingRunIntentPageReader;

  /// Optional, explicitly injected owner-scoped pending Run-intent timeline
  /// seam. The default Gate leaves it unset; the opt-in pending Run-intent
  /// candidate supplies the same reader from its authenticated API adapter.
  final ForgePendingRunIntentTimelineReader? pendingRunIntentTimelineReader;

  /// Optional local Runner lease/fencing fixture and bounded file reader.
  /// Neither value opens a production device or execution route.
  final ForgeRunnerLeaseFencingFixture? runnerLeaseFencingPreview;
  final ForgeRunnerLeaseFencingFileReader? runnerLeaseFencingFileReader;

  /// Optional local execution-lease restart image. It remains a strict,
  /// display-only value and never restores a lease or opens a Runner route.
  final ForgeExecutionLeaseCheckpointFixture? executionLeaseCheckpointPreview;

  /// Optional bounded JSON reader for the local execution-lease checkpoint
  /// preview. The default Gate leaves it unset and request-free.
  final ForgeExecutionLeaseCheckpointFileReader?
  executionLeaseCheckpointFileReader;

  /// Optional local client-instance/session metadata. The default Gate leaves
  /// it unset; when supplied it remains read-only and fixture-backed.
  final ForgeClientInstanceSessionView? clientInstanceSessionViewPreview;

  /// Optional local client-instance/resource metadata. The default Gate leaves
  /// it unset; when supplied it remains read-only and fixture-backed.
  final ForgeClientInstanceResourceView? clientInstanceResourceViewPreview;

  /// Explicit owner and reader for the private client-instance/resource-view
  /// candidate. Both values are required before the Gate permits a request;
  /// the default Gate leaves them unset.
  final ForgeDeviceOwner? clientInstanceResourceViewOwner;
  final ForgeClientInstanceResourceViewReader? clientInstanceResourceViewReader;

  /// Enables the explicitly reviewed, read-only client-instance/resource-view
  /// candidate adapter for a test or candidate harness. The default Gate
  /// keeps this disabled, so the candidate route remains unreachable from
  /// normal Web/App/Mobile construction.
  @visibleForTesting
  final bool enableClientInstanceResourceViewCandidate;

  /// Optional origin used by [enableClientInstanceResourceViewCandidate]. An
  /// explicit owner declaration is still required through
  /// [clientInstanceResourceViewOwner].
  @visibleForTesting
  final String? clientInstanceResourceViewCandidateApiOrigin;

  /// Optional local Run → Attempt → lease dispatch preflight. It is strictly
  /// display-only; the default Gate leaves it unset and never opens a route.
  final ForgePreflightFixture? runAttemptLeaseDispatchPreflightPreview;

  /// Explicit request and reader for the private Run → Attempt → lease
  /// dispatch preflight candidate. Both are required before the Gate can
  /// reach the route; the default Gate leaves them unset and request-free.
  final ForgeRunAttemptLeaseDispatchPreflightRequest?
  runAttemptLeaseDispatchPreflightRequest;
  final ForgeRunAttemptLeaseDispatchPreflightReader?
  runAttemptLeaseDispatchPreflightReader;

  /// Enables the explicitly reviewed, read-only Run → Attempt → lease
  /// dispatch preflight candidate adapter for a test or candidate harness.
  /// The default Gate keeps this disabled, so the candidate POST route is
  /// unreachable from normal Web/App/Mobile construction.
  @visibleForTesting
  final bool enableRunAttemptLeaseDispatchPreflightCandidate;

  /// Optional origin used by
  /// [enableRunAttemptLeaseDispatchPreflightCandidate]. An explicit typed
  /// request is still required through
  /// [runAttemptLeaseDispatchPreflightRequest].
  @visibleForTesting
  final String? runAttemptLeaseDispatchPreflightCandidateApiOrigin;

  /// Optional local Runner dispatch-plan comparison. It is strictly
  /// display-only; the default Gate leaves it unset and never opens a route.
  final ForgeRunnerDispatchPlanPreview? runnerDispatchPlanPreview;

  /// Explicit request and reader for the private Runner dispatch-plan
  /// comparison candidate. Both are required before the Gate can reach the
  /// route; normal Web/App/Mobile construction remains request-free.
  final ForgeRunAttemptLeaseDispatchPreflightRequest?
  runnerDispatchPlanPreviewRequest;
  final ForgeRunnerDispatchPlanPreviewReader? runnerDispatchPlanPreviewReader;

  /// Enables the explicitly reviewed, read-only Runner dispatch-plan
  /// comparison candidate for a test or candidate harness. Production
  /// construction keeps this disabled.
  @visibleForTesting
  final bool enableRunnerDispatchPlanPreviewCandidate;

  /// Optional origin used only by the explicitly enabled candidate adapter.
  /// An explicit typed request is still required through
  /// [runnerDispatchPlanPreviewRequest].
  @visibleForTesting
  final String? runnerDispatchPlanPreviewCandidateApiOrigin;

  /// Explicit request and reader for the accepted EXECUTE lease-to-Runner
  /// admission recheck. The default Gate leaves this unset and request-free.
  final ForgeRunnerDispatchAdmission? runnerDispatchAdmission;
  final ForgeRunnerDispatchAdmissionRequest? runnerDispatchAdmissionRequest;
  final ForgeRunnerDispatchAdmissionReader? runnerDispatchAdmissionReader;

  /// Enables the reviewed, read-only Runner dispatch admission candidate for a
  /// test or candidate harness. Production construction keeps it disabled.
  @visibleForTesting
  final bool enableRunnerDispatchAdmissionCandidate;

  /// Candidate-only origin for the Runner dispatch admission POST.
  @visibleForTesting
  final String? runnerDispatchAdmissionCandidateApiOrigin;

  /// Explicit request and reader for the accepted EXECUTE transport
  /// admission preview. The default Gate leaves this unset and request-free.
  final ForgeRunnerTransportAdmission? runnerTransportAdmission;
  final ForgeRunnerTransportAdmissionRequest? runnerTransportAdmissionRequest;
  final ForgeRunnerTransportAdmissionReader? runnerTransportAdmissionReader;

  /// Enables the reviewed, read-only Runner transport admission candidate for
  /// a test or candidate harness. Production construction keeps it disabled.
  @visibleForTesting
  final bool enableRunnerTransportAdmissionCandidate;

  /// Candidate-only origin for the Runner transport admission POST.
  @visibleForTesting
  final String? runnerTransportAdmissionCandidateApiOrigin;

  /// Explicit request and reader for the final server-owned Runner
  /// execution-boundary preview. The default Gate leaves this unset.
  final ForgeRunnerExecutionBoundaryObservation? runnerExecutionBoundary;
  final ForgeRunnerExecutionBoundaryPreviewRequest?
  runnerExecutionBoundaryRequest;
  final ForgeRunnerExecutionBoundaryReader? runnerExecutionBoundaryReader;

  /// Enables the reviewed, read-only execution-boundary candidate for a test
  /// or candidate harness. Production construction keeps it disabled.
  @visibleForTesting
  final bool enableRunnerExecutionBoundaryCandidate;

  /// Candidate-only origin for the execution-boundary POST.
  @visibleForTesting
  final String? runnerExecutionBoundaryCandidateApiOrigin;

  /// Explicit owner and reader for the private client-instance/session-view
  /// candidate. Both values are required before the Gate permits a request;
  /// the default Gate leaves them unset.
  final ForgeDeviceOwner? clientInstanceSessionViewOwner;
  final ForgeClientInstanceSessionViewReader? clientInstanceSessionViewReader;

  /// Enables the explicitly reviewed, read-only client-instance/session-view
  /// candidate adapter for a test or candidate harness. The default Gate
  /// keeps this disabled, so the candidate route remains unreachable from
  /// normal Web/App/Mobile construction.
  @visibleForTesting
  final bool enableClientInstanceSessionViewCandidate;

  /// Optional origin used by [enableClientInstanceSessionViewCandidate]. An
  /// explicit owner declaration is still required through
  /// [clientInstanceSessionViewOwner].
  @visibleForTesting
  final String? clientInstanceSessionViewCandidateApiOrigin;

  /// Explicit owner and reader for the private paired client-instance
  /// session/resource candidate. The default Gate leaves this unset, so the
  /// shared Sessions surface performs no candidate GETs unless a caller opts
  /// in with an owner and the reviewed flag.
  final ForgeDeviceOwner? clientInstanceSessionResourceConvergenceOwner;
  final ForgeClientInstanceSessionResourceConvergenceReader?
  clientInstanceSessionResourceConvergenceReader;

  /// Enables the reviewed, read-only client-instance session/resource pair
  /// adapter for a test or candidate harness. Production construction keeps
  /// this disabled.
  @visibleForTesting
  final bool enableClientInstanceSessionResourceConvergenceCandidate;

  /// Candidate-only origin used by the paired client-instance reader.
  @visibleForTesting
  final String? clientInstanceSessionResourceConvergenceCandidateApiOrigin;

  /// Explicit owner and origin for the private lifecycle-registry GET
  /// candidate. Both values stay unset in normal Web/App/Mobile construction;
  /// no lifecycle-registry request is made unless the reviewed candidate flag
  /// is enabled with an owner and candidate origin.
  final ForgeDeviceOwner? lifecycleRegistryOwner;
  final ForgeLifecycleRegistryReader? lifecycleRegistryReader;

  /// Enables the explicitly reviewed, read-only lifecycle-registry candidate
  /// adapter for a test or candidate harness. The default Gate keeps this
  /// disabled, so enrollment/heartbeat state remains request-free.
  @visibleForTesting
  final bool enableLifecycleRegistryCandidate;

  /// Candidate-only origin for the lifecycle-registry GET adapter. It must be
  /// explicit when [enableLifecycleRegistryCandidate] is true.
  @visibleForTesting
  final String? lifecycleRegistryCandidateApiOrigin;

  /// Explicit owner, metadata request, and reader for the private credential
  /// lifecycle candidate. These values stay unset in normal Web/App/Mobile
  /// construction; the candidate POST cannot be reached without all three
  /// declarations and the opt-in flag below.
  final ForgeDeviceOwner? deviceCredentialCandidateOwner;
  final ForgeDeviceCredentialLifecycleRequest? deviceCredentialCandidateRequest;
  final ForgeDeviceCredentialLifecycleCandidateReader?
  deviceCredentialCandidateReader;

  /// Enables the explicitly reviewed metadata-only credential candidate for
  /// a test or candidate harness. Production construction keeps this false.
  @visibleForTesting
  final bool enableDeviceCredentialCandidate;

  /// Candidate-only origin for the credential lifecycle POST. It must be
  /// explicit when [enableDeviceCredentialCandidate] is true.
  @visibleForTesting
  final String? deviceCredentialCandidateApiOrigin;
  @visibleForTesting
  final Widget Function(String accessToken)? testScreenBuilder;
  @visibleForTesting
  final Widget Function(String accessToken, String? initialConversationID)?
  testScreenBuilderWithRoute;

  const ForgeSessionsGate({
    super.key,
    this.credentialStore,
    this.initialConversationID,
    this.initialClientInstanceID,
    this.enableConversationChangesStream = false,
    this.conversationChangesStreamWaitMS = 15000,
    this.httpClient,
    this.deviceObservation,
    this.deviceObservationRequest,
    this.runIntentObservation,
    this.runnerExecutionIntentObservation,
    this.runnerExecutionIntentRequest,
    this.runnerExecutionIntentReader,
    this.enableRunnerExecutionIntentCandidate = false,
    this.runnerExecutionIntentCandidateApiOrigin,
    this.runObserved,
    this.runObservedReader,
    this.sessionRunnerReceiptObservationReader,
    this.enableRunObservedCandidate = false,
    this.runObservedCandidateApiOrigin,
    this.enableDeviceInventoryV2Candidate = false,
    this.deviceInventoryV2CandidateApiOrigin,
    this.runExecutionEvidence,
    this.sessionRunnerReceiptObservation,
    this.sessionRunnerReceiptVectorsPreview,
    this.sessionRunnerReceiptVectorsFileReader,
    this.sessionRunnerReceiptHistoryPreview,
    this.sessionRunnerReceiptHistoryFileReader,
    this.sessionRunnerReconciliationProjectionPreview,
    this.sessionRunnerReconciliationProjectionFileReader,
    this.sessionRunnerReceiptHistoryRequest,
    this.sessionRunnerReceiptHistoryReader,
    this.sessionRunnerReconciliationProjectionRequest,
    this.sessionRunnerReconciliationProjectionReader,
    this.enableSessionRunnerReconciliationProjectionCandidate = false,
    this.sessionRunnerReconciliationProjectionCandidateApiOrigin,
    this.enableSessionRunnerReconciliationProjectionHistoryChainCandidate =
        false,
    this.enableSessionRunnerReceiptHistoryCandidate = false,
    this.sessionRunnerReceiptHistoryCandidateApiOrigin,
    this.runExecutionEvidenceReader,
    this.enableRunExecutionEvidenceCandidate = false,
    this.runExecutionEvidenceCandidateApiOrigin,
    this.executionReconciliationObservation,
    this.executionReconciliationInput,
    this.executionReconciliationReader,
    this.enableExecutionReconciliationCandidate = false,
    this.executionReconciliationCandidateApiOrigin,
    this.executionConsentPreviewOwner,
    this.executionConsentPreviewReader,
    this.enableExecutionConsentPreviewCandidate = false,
    this.executionConsentPreviewCandidateApiOrigin,
    this.attemptRequestPreview,
    this.runnerAttemptBoundaryPreview,
    this.runnerAttemptBoundaryScope,
    this.runnerAttemptBoundaryFileReader,
    this.runnerAttemptBoundaryRequest,
    this.runnerAttemptBoundaryReader,
    this.enableRunnerAttemptBoundaryCandidate = false,
    this.runnerAttemptBoundaryCandidateApiOrigin,
    this.enableRunnerAttemptBoundaryProjection = false,
    this.pendingRunIntentPreview,
    this.enablePendingRunIntentCandidate = false,
    this.pendingRunIntentOwner,
    this.pendingRunIntentCandidateApiOrigin,
    this.promptAppendReceiptOwner,
    this.promptAppendReceiptSubmitter,
    this.enablePromptAppendReceiptCandidate = false,
    this.promptAppendReceiptCandidateApiOrigin,
    this.requireDeviceInventoryResourceConvergenceForPromptAppend = false,
    this.deviceInventoryOwner,
    this.deviceInventoryReader,
    this.enableDeviceInventoryCandidate = false,
    this.deviceInventoryCandidateApiOrigin,
    this.deviceInventoryV2Reader,
    this.deviceInventoryResourceConvergenceOwner,
    this.deviceInventoryResourceConvergenceReader,
    this.enableDeviceInventoryResourceConvergenceCandidate = false,
    this.deviceInventoryResourceConvergenceCandidateApiOrigin,
    this.deviceInventoryRegistryPlacementRequirements,
    this.deviceInventoryRegistryPlacementPreviewReader,
    this.enableDeviceInventoryRegistryPlacementPreviewCandidate = false,
    this.deviceInventoryRegistryPlacementPreviewCandidateApiOrigin,
    this.schedulerSelectionPreviewRequest,
    this.schedulerSelectionPreviewReader,
    this.enableSchedulerSelectionPreviewCandidate = false,
    this.schedulerSelectionPreviewCandidateApiOrigin,
    this.schedulerSelectionLeaseRequest,
    this.schedulerSelectionLeaseReader,
    this.enableSchedulerSelectionLeaseCandidate = false,
    this.schedulerSelectionLeaseCandidateApiOrigin,
    this.schedulerSelectionLeaseIdempotencyKey,
    this.schedulerSelectionLeaseRenewalRequest,
    this.schedulerSelectionLeaseRenewalReader,
    this.enableSchedulerSelectionLeaseRenewalCandidate = false,
    this.schedulerSelectionLeaseRenewalCandidateApiOrigin,
    this.schedulerSelectionLeaseRenewalIdempotencyKey,
    this.schedulerSelectionLeaseReleaseRequest,
    this.schedulerSelectionLeaseReleaseReader,
    this.enableSchedulerSelectionLeaseReleaseCandidate = false,
    this.schedulerSelectionLeaseReleaseCandidateApiOrigin,
    this.schedulerSelectionLeaseReleaseIdempotencyKey,
    this.deviceInventoryV2Preview,
    this.deviceInventoryV2FileReader,
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
    this.clientInstanceResourceViewPreview,
    this.clientInstanceResourceViewOwner,
    this.clientInstanceResourceViewReader,
    this.enableClientInstanceResourceViewCandidate = false,
    this.clientInstanceResourceViewCandidateApiOrigin,
    this.clientInstanceSessionViewOwner,
    this.clientInstanceSessionViewReader,
    this.enableClientInstanceSessionViewCandidate = false,
    this.clientInstanceSessionViewCandidateApiOrigin,
    this.clientInstanceSessionResourceConvergenceOwner,
    this.clientInstanceSessionResourceConvergenceReader,
    this.enableClientInstanceSessionResourceConvergenceCandidate = false,
    this.clientInstanceSessionResourceConvergenceCandidateApiOrigin,
    this.lifecycleRegistryOwner,
    this.lifecycleRegistryReader,
    this.enableLifecycleRegistryCandidate = false,
    this.lifecycleRegistryCandidateApiOrigin,
    this.deviceCredentialCandidateOwner,
    this.deviceCredentialCandidateRequest,
    this.deviceCredentialCandidateReader,
    this.enableDeviceCredentialCandidate = false,
    this.deviceCredentialCandidateApiOrigin,
    this.runAttemptLeaseDispatchPreflightPreview,
    this.runAttemptLeaseDispatchPreflightRequest,
    this.runAttemptLeaseDispatchPreflightReader,
    this.enableRunAttemptLeaseDispatchPreflightCandidate = false,
    this.runAttemptLeaseDispatchPreflightCandidateApiOrigin,
    this.runnerDispatchPlanPreview,
    this.runnerDispatchPlanPreviewRequest,
    this.runnerDispatchPlanPreviewReader,
    this.enableRunnerDispatchPlanPreviewCandidate = false,
    this.runnerDispatchPlanPreviewCandidateApiOrigin,
    this.runnerDispatchAdmissionRequest,
    this.runnerDispatchAdmissionReader,
    this.runnerDispatchAdmission,
    this.enableRunnerDispatchAdmissionCandidate = false,
    this.runnerDispatchAdmissionCandidateApiOrigin,
    this.runnerTransportAdmissionRequest,
    this.runnerTransportAdmissionReader,
    this.runnerTransportAdmission,
    this.runnerExecutionBoundaryRequest,
    this.runnerExecutionBoundaryReader,
    this.runnerExecutionBoundary,
    this.enableRunnerExecutionBoundaryCandidate = false,
    this.runnerExecutionBoundaryCandidateApiOrigin,
    this.enableRunnerTransportAdmissionCandidate = false,
    this.runnerTransportAdmissionCandidateApiOrigin,
    this.localRunnerPreview,
    this.localRunnerPreviewRequest,
    this.localRunnerPreviewReader,
    this.enableLocalRunnerPreviewCandidate = false,
    this.localRunnerPreviewCandidateApiOrigin,
    this.testScreenBuilder,
    this.testScreenBuilderWithRoute,
  });

  @override
  State<ForgeSessionsGate> createState() => _ForgeSessionsGateState();
}

class _ForgeSessionsGateState extends State<ForgeSessionsGate> {
  late final ForgeCredentialStore _credentialStore =
      widget.credentialStore ?? ForgeCredentialStore();
  String? _token;
  String? _resolvedInitialConversationID;
  ForgeConversationsApi? _runObservedCandidateApi;
  ForgeRunObservedReader? _runObservedCandidateReader;
  ForgeConversationsApi? _runExecutionEvidenceCandidateApi;
  ForgeRunExecutionEvidenceReader? _runExecutionEvidenceCandidateReader;
  ForgeConversationsApi? _sessionRunnerReceiptHistoryCandidateApi;
  ForgeSessionRunnerReceiptHistoryReader?
  _sessionRunnerReceiptHistoryCandidateReader;
  ForgeConversationsApi? _sessionRunnerReconciliationProjectionCandidateApi;
  ForgeSessionRunnerReconciliationProjectionReader?
  _sessionRunnerReconciliationProjectionCandidateReader;
  ForgeConversationsApi? _deviceInventoryCandidateApi;
  ForgeDeviceInventoryCandidateReader? _deviceInventoryCandidateReader;
  ForgeConversationsApi? _localRunnerPreviewCandidateApi;
  ForgeLocalRunnerPreviewReader? _localRunnerPreviewCandidateReader;
  ForgeConversationsApi? _deviceInventoryV2CandidateApi;
  ForgeDeviceInventoryV2Reader? _deviceInventoryV2CandidateReader;
  ForgeConversationsApi? _deviceInventoryResourceConvergenceCandidateApi;
  ForgeDeviceInventoryResourceConvergenceReader?
  _deviceInventoryResourceConvergenceCandidateReader;
  ForgeConversationsApi? _deviceInventoryRegistryPlacementPreviewCandidateApi;
  ForgeDeviceRegistryPlacementPreviewReader?
  _deviceInventoryRegistryPlacementPreviewCandidateReader;
  ForgeConversationsApi? _schedulerSelectionPreviewCandidateApi;
  ForgeSchedulerSelectionPreviewReader?
  _schedulerSelectionPreviewCandidateReader;
  ForgeConversationsApi? _schedulerSelectionLeaseCandidateApi;
  ForgeSchedulerSelectionLeaseReader? _schedulerSelectionLeaseCandidateReader;
  ForgeConversationsApi? _schedulerSelectionLeaseRenewalCandidateApi;
  ForgeSchedulerSelectionLeaseRenewalReader?
  _schedulerSelectionLeaseRenewalCandidateReader;
  ForgeConversationsApi? _schedulerSelectionLeaseReleaseCandidateApi;
  ForgeSchedulerSelectionLeaseReleaseReader?
  _schedulerSelectionLeaseReleaseCandidateReader;
  ForgeConversationsApi? _clientInstanceResourceViewCandidateApi;
  ForgeClientInstanceResourceViewReader?
  _clientInstanceResourceViewCandidateReader;
  ForgeConversationsApi? _clientInstanceSessionViewCandidateApi;
  ForgeClientInstanceSessionViewReader?
  _clientInstanceSessionViewCandidateReader;
  ForgeConversationsApi? _clientInstanceSessionResourceConvergenceCandidateApi;
  ForgeClientInstanceSessionResourceConvergenceReader?
  _clientInstanceSessionResourceConvergenceCandidateReader;
  ForgeConversationsApi? _runAttemptLeaseDispatchPreflightCandidateApi;
  ForgeRunAttemptLeaseDispatchPreflightReader?
  _runAttemptLeaseDispatchPreflightCandidateReader;
  ForgeConversationsApi? _runnerDispatchPlanPreviewCandidateApi;
  ForgeRunnerDispatchPlanPreviewReader?
  _runnerDispatchPlanPreviewCandidateReader;
  ForgeConversationsApi? _runnerExecutionIntentCandidateApi;
  ForgeRunnerExecutionIntentReader? _runnerExecutionIntentCandidateReader;
  ForgeConversationsApi? _runnerDispatchAdmissionCandidateApi;
  ForgeRunnerDispatchAdmissionReader? _runnerDispatchAdmissionCandidateReader;
  ForgeConversationsApi? _runnerTransportAdmissionCandidateApi;
  ForgeRunnerTransportAdmissionReader? _runnerTransportAdmissionCandidateReader;
  ForgeConversationsApi? _runnerExecutionBoundaryCandidateApi;
  ForgeRunnerExecutionBoundaryReader? _runnerExecutionBoundaryCandidateReader;
  ForgeConversationsApi? _runnerAttemptBoundaryCandidateApi;
  ForgeRunnerAttemptBoundaryReader? _runnerAttemptBoundaryCandidateReader;
  ForgeConversationsApi? _executionReconciliationCandidateApi;
  ForgeExecutionReconciliationReader? _executionReconciliationCandidateReader;
  ForgeConversationsApi? _executionConsentPreviewCandidateApi;
  ForgeExecutionConsentPreviewReader? _executionConsentPreviewCandidateReader;
  ForgeConversationsApi? _lifecycleRegistryCandidateApi;
  ForgeLifecycleRegistryReader? _lifecycleRegistryCandidateReader;
  ForgeConversationsApi? _deviceCredentialCandidateApi;
  ForgeDeviceCredentialLifecycleCandidateReader?
  _deviceCredentialCandidateReader;
  ForgeConversationsApi? _pendingRunIntentCandidateApi;
  ForgePendingRunIntentSubmitter? _pendingRunIntentCandidateSubmitter;
  ForgePendingRunIntentReader? _pendingRunIntentCandidateReader;
  ForgePendingRunIntentPageReader? _pendingRunIntentCandidatePageReader;
  ForgePendingRunIntentTimelineReader? _pendingRunIntentCandidateTimelineReader;
  ForgeConversationsApi? _promptAppendReceiptCandidateApi;
  ForgePromptAppendReceiptSubmitter? _promptAppendReceiptCandidateSubmitter;
  bool _loading = true;
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    String? token;
    try {
      token = await _credentialStore.restore();
    } catch (_) {
      token = null;
    }
    if (!mounted) return;
    final initialConversationID = _conversationSelectionAfterRestore();
    _configureRunObservedCandidate(token);
    _configureRunExecutionEvidenceCandidate(token);
    _configureSessionRunnerReceiptHistoryCandidate(token);
    _configureSessionRunnerReconciliationProjectionCandidate(token);
    _configureDeviceInventoryCandidate(token);
    _configureLocalRunnerPreviewCandidate(token);
    _configureDeviceInventoryV2Candidate(token);
    _configureDeviceInventoryResourceConvergenceCandidate(token);
    _configureDeviceInventoryRegistryPlacementPreviewCandidate(token);
    _configureSchedulerSelectionPreviewCandidate(token);
    _configureSchedulerSelectionLeaseCandidate(token);
    _configureSchedulerSelectionLeaseRenewalCandidate(token);
    _configureSchedulerSelectionLeaseReleaseCandidate(token);
    _configureClientInstanceResourceViewCandidate(token);
    _configureClientInstanceSessionViewCandidate(token);
    _configureClientInstanceSessionResourceConvergenceCandidate(token);
    _configureRunAttemptLeaseDispatchPreflightCandidate(token);
    _configureRunnerDispatchPlanPreviewCandidate(token);
    _configureRunnerExecutionIntentCandidate(token);
    _configureRunnerDispatchAdmissionCandidate(token);
    _configureRunnerTransportAdmissionCandidate(token);
    _configureRunnerExecutionBoundaryCandidate(token);
    _configureRunnerAttemptBoundaryCandidate(token);
    _configureExecutionReconciliationCandidate(token);
    _configureExecutionConsentPreviewCandidate(token);
    _configureLifecycleRegistryCandidate(token);
    _configureDeviceCredentialCandidate(token);
    _configurePendingRunIntentCandidate(token);
    _configurePromptAppendReceiptCandidate(token);
    setState(() {
      _token = token;
      _resolvedInitialConversationID = initialConversationID;
      _loading = false;
    });
    if (token == null) _redirectForSignIn();
  }

  void _redirectForSignIn() {
    if (_redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        BrowserNavigation.replaceLocation(
          ForgeConversationsOAuth.loginLocation(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final token = _token;
    if (token == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final testScreenBuilderWithRoute = widget.testScreenBuilderWithRoute;
    if (testScreenBuilderWithRoute != null) {
      return testScreenBuilderWithRoute(token, _resolvedInitialConversationID);
    }
    final testScreenBuilder = widget.testScreenBuilder;
    if (testScreenBuilder != null) return testScreenBuilder(token);
    final runObservedReader =
        widget.runObservedReader ?? _runObservedCandidateReader;
    final runExecutionEvidenceReader =
        widget.runExecutionEvidenceReader ??
        _runExecutionEvidenceCandidateReader;
    final sessionRunnerReceiptHistoryReader =
        widget.sessionRunnerReceiptHistoryReader ??
        _sessionRunnerReceiptHistoryCandidateReader;
    final sessionRunnerReconciliationProjectionReader =
        widget.sessionRunnerReconciliationProjectionReader ??
        _sessionRunnerReconciliationProjectionCandidateReader;
    final deviceInventoryReader =
        widget.deviceInventoryReader ?? _deviceInventoryCandidateReader;
    final deviceInventoryV2Reader =
        widget.deviceInventoryV2Reader ?? _deviceInventoryV2CandidateReader;
    final deviceInventoryResourceConvergenceReader =
        widget.deviceInventoryResourceConvergenceReader ??
        _deviceInventoryResourceConvergenceCandidateReader;
    final deviceInventoryRegistryPlacementPreviewReader =
        widget.deviceInventoryRegistryPlacementPreviewReader ??
        _deviceInventoryRegistryPlacementPreviewCandidateReader;
    final schedulerSelectionPreviewReader =
        widget.schedulerSelectionPreviewReader ??
        _schedulerSelectionPreviewCandidateReader;
    final schedulerSelectionLeaseReader =
        widget.schedulerSelectionLeaseReader ??
        _schedulerSelectionLeaseCandidateReader;
    final schedulerSelectionLeaseRenewalReader =
        widget.schedulerSelectionLeaseRenewalReader ??
        _schedulerSelectionLeaseRenewalCandidateReader;
    final schedulerSelectionLeaseReleaseReader =
        widget.schedulerSelectionLeaseReleaseReader ??
        _schedulerSelectionLeaseReleaseCandidateReader;
    final clientInstanceResourceViewReader =
        widget.clientInstanceResourceViewReader ??
        _clientInstanceResourceViewCandidateReader;
    final clientInstanceSessionViewReader =
        widget.clientInstanceSessionViewReader ??
        _clientInstanceSessionViewCandidateReader;
    final clientInstanceSessionResourceConvergenceReader =
        widget.clientInstanceSessionResourceConvergenceReader ??
        _clientInstanceSessionResourceConvergenceCandidateReader;
    final runAttemptLeaseDispatchPreflightReader =
        widget.runAttemptLeaseDispatchPreflightReader ??
        _runAttemptLeaseDispatchPreflightCandidateReader;
    final runnerDispatchPlanPreviewReader =
        widget.runnerDispatchPlanPreviewReader ??
        _runnerDispatchPlanPreviewCandidateReader;
    final runnerExecutionIntentReader =
        widget.runnerExecutionIntentReader ??
        _runnerExecutionIntentCandidateReader;
    final runnerDispatchAdmissionReader =
        widget.runnerDispatchAdmissionReader ??
        _runnerDispatchAdmissionCandidateReader;
    final runnerTransportAdmissionReader =
        widget.runnerTransportAdmissionReader ??
        _runnerTransportAdmissionCandidateReader;
    final runnerExecutionBoundaryReader =
        widget.runnerExecutionBoundaryReader ??
        _runnerExecutionBoundaryCandidateReader;
    final runnerAttemptBoundaryReader =
        widget.runnerAttemptBoundaryReader ??
        _runnerAttemptBoundaryCandidateReader;
    final localRunnerPreviewReader =
        widget.localRunnerPreviewReader ?? _localRunnerPreviewCandidateReader;
    final executionReconciliationReader =
        widget.executionReconciliationReader ??
        _executionReconciliationCandidateReader;
    final executionConsentPreviewReader =
        widget.executionConsentPreviewReader ??
        _executionConsentPreviewCandidateReader;
    final lifecycleRegistryReader =
        widget.lifecycleRegistryReader ?? _lifecycleRegistryCandidateReader;
    final deviceCredentialCandidateReader =
        widget.deviceCredentialCandidateReader ??
        _deviceCredentialCandidateReader;
    final pendingRunIntentReader =
        widget.pendingRunIntentReader ?? _pendingRunIntentCandidateReader;
    final pendingRunIntentPageReader =
        widget.pendingRunIntentPageReader ??
        _pendingRunIntentCandidatePageReader;
    final pendingRunIntentTimelineReader =
        widget.pendingRunIntentTimelineReader ??
        _pendingRunIntentCandidateTimelineReader;
    final pendingRunIntentSubmitter = _pendingRunIntentCandidateSubmitter;
    final promptAppendReceiptSubmitter =
        widget.promptAppendReceiptSubmitter ??
        _promptAppendReceiptCandidateSubmitter;
    return ForgeSessionsScreen(
      accessToken: token,
      apiOrigin: ForgeConversationsApiOrigin.baseUrl,
      enableConversationChangesStream: widget.enableConversationChangesStream,
      conversationChangesStreamWaitMS: widget.conversationChangesStreamWaitMS,
      initialConversationID: _resolvedInitialConversationID,
      initialClientInstanceID: widget.initialClientInstanceID,
      httpClient: widget.httpClient,
      deviceObservation: widget.deviceObservation,
      deviceObservationRequest: widget.deviceObservationRequest,
      runIntentObservation: widget.runIntentObservation,
      runnerExecutionIntentObservation: widget.runnerExecutionIntentObservation,
      runnerExecutionIntentRequest: widget.runnerExecutionIntentRequest,
      runnerExecutionIntentReader: runnerExecutionIntentReader,
      localRunnerPreview: widget.localRunnerPreview,
      localRunnerPreviewRequest: widget.localRunnerPreviewRequest,
      localRunnerPreviewReader: localRunnerPreviewReader,
      runObserved: widget.runObserved,
      runObservedReader: runObservedReader,
      sessionRunnerReceiptObservationReader:
          widget.sessionRunnerReceiptObservationReader,
      runExecutionEvidence: widget.runExecutionEvidence,
      sessionRunnerReceiptObservation: widget.sessionRunnerReceiptObservation,
      sessionRunnerReceiptVectorsPreview:
          widget.sessionRunnerReceiptVectorsPreview,
      sessionRunnerReceiptVectorsFileReader:
          widget.sessionRunnerReceiptVectorsFileReader,
      sessionRunnerReceiptHistoryPreview:
          widget.sessionRunnerReceiptHistoryPreview,
      sessionRunnerReceiptHistoryFileReader:
          widget.sessionRunnerReceiptHistoryFileReader,
      sessionRunnerReconciliationProjectionPreview:
          widget.sessionRunnerReconciliationProjectionPreview,
      sessionRunnerReconciliationProjectionFileReader:
          widget.sessionRunnerReconciliationProjectionFileReader,
      sessionRunnerReceiptHistoryRequest:
          widget.sessionRunnerReceiptHistoryRequest,
      sessionRunnerReceiptHistoryReader: sessionRunnerReceiptHistoryReader,
      sessionRunnerReconciliationProjectionRequest:
          widget.sessionRunnerReconciliationProjectionRequest,
      sessionRunnerReconciliationProjectionReader:
          sessionRunnerReconciliationProjectionReader,
      runExecutionEvidenceReader: runExecutionEvidenceReader,
      executionReconciliationObservation:
          widget.executionReconciliationObservation,
      executionReconciliationInput: widget.executionReconciliationInput,
      executionReconciliationReader: executionReconciliationReader,
      executionConsentPreviewOwner: widget.executionConsentPreviewOwner,
      executionConsentPreviewReader: executionConsentPreviewReader,
      lifecycleRegistryOwner: widget.lifecycleRegistryOwner,
      lifecycleRegistryReader: lifecycleRegistryReader,
      deviceCredentialCandidateOwner: widget.deviceCredentialCandidateOwner,
      deviceCredentialCandidateRequest: widget.deviceCredentialCandidateRequest,
      deviceCredentialCandidateReader: deviceCredentialCandidateReader,
      attemptRequestPreview: widget.attemptRequestPreview,
      runnerAttemptBoundaryPreview: widget.runnerAttemptBoundaryPreview,
      runnerAttemptBoundaryScope: widget.runnerAttemptBoundaryScope,
      runnerAttemptBoundaryFileReader: widget.runnerAttemptBoundaryFileReader,
      runnerAttemptBoundaryRequest: widget.runnerAttemptBoundaryRequest,
      runnerAttemptBoundaryReader: runnerAttemptBoundaryReader,
      enableRunnerAttemptBoundaryProjection:
          widget.enableRunnerAttemptBoundaryProjection,
      pendingRunIntentPreview: widget.pendingRunIntentPreview,
      pendingRunIntentOwner: widget.pendingRunIntentOwner,
      pendingRunIntentSubmitter: pendingRunIntentSubmitter,
      promptAppendReceiptOwner: widget.promptAppendReceiptOwner,
      promptAppendReceiptSubmitter: promptAppendReceiptSubmitter,
      requireDeviceInventoryResourceConvergenceForPromptAppend:
          widget.requireDeviceInventoryResourceConvergenceForPromptAppend,
      deviceInventoryOwner: widget.deviceInventoryOwner,
      deviceInventoryReader: deviceInventoryReader,
      deviceInventoryV2Reader: deviceInventoryV2Reader,
      deviceInventoryResourceConvergenceOwner:
          widget.deviceInventoryResourceConvergenceOwner,
      deviceInventoryResourceConvergenceReader:
          deviceInventoryResourceConvergenceReader,
      deviceInventoryRegistryPlacementRequirements:
          widget.deviceInventoryRegistryPlacementRequirements,
      deviceInventoryRegistryPlacementPreviewReader:
          deviceInventoryRegistryPlacementPreviewReader,
      schedulerSelectionPreviewRequest: widget.schedulerSelectionPreviewRequest,
      schedulerSelectionPreviewReader: schedulerSelectionPreviewReader,
      schedulerSelectionLeaseRequest: widget.schedulerSelectionLeaseRequest,
      schedulerSelectionLeaseReader: schedulerSelectionLeaseReader,
      schedulerSelectionLeaseIdempotencyKey:
          widget.schedulerSelectionLeaseIdempotencyKey,
      schedulerSelectionLeaseRenewalRequest:
          widget.schedulerSelectionLeaseRenewalRequest,
      schedulerSelectionLeaseRenewalReader:
          schedulerSelectionLeaseRenewalReader,
      schedulerSelectionLeaseRenewalIdempotencyKey:
          widget.schedulerSelectionLeaseRenewalIdempotencyKey,
      schedulerSelectionLeaseReleaseRequest:
          widget.schedulerSelectionLeaseReleaseRequest,
      schedulerSelectionLeaseReleaseReader:
          schedulerSelectionLeaseReleaseReader,
      schedulerSelectionLeaseReleaseIdempotencyKey:
          widget.schedulerSelectionLeaseReleaseIdempotencyKey,
      deviceInventoryV2Preview: widget.deviceInventoryV2Preview,
      deviceInventoryV2FileReader: widget.deviceInventoryV2FileReader,
      deviceInventoryPlacementEvaluationV2Preview:
          widget.deviceInventoryPlacementEvaluationV2Preview,
      deviceInventoryPlacementEvaluationV2FileReader:
          widget.deviceInventoryPlacementEvaluationV2FileReader,
      deviceInventoryPlacementEvaluationPreview:
          widget.deviceInventoryPlacementEvaluationPreview,
      deviceInventoryPlacementEvaluationFileReader:
          widget.deviceInventoryPlacementEvaluationFileReader,
      deviceInventoryPlacementBatchEvaluationPreview:
          widget.deviceInventoryPlacementBatchEvaluationPreview,
      deviceInventoryPlacementBatchEvaluationFileReader:
          widget.deviceInventoryPlacementBatchEvaluationFileReader,
      pendingRunIntentReader: pendingRunIntentReader,
      pendingRunIntentPageReader: pendingRunIntentPageReader,
      pendingRunIntentTimelineReader: pendingRunIntentTimelineReader,
      runnerLeaseFencingPreview: widget.runnerLeaseFencingPreview,
      runnerLeaseFencingFileReader: widget.runnerLeaseFencingFileReader,
      executionLeaseCheckpointPreview: widget.executionLeaseCheckpointPreview,
      executionLeaseCheckpointFileReader:
          widget.executionLeaseCheckpointFileReader,
      clientInstanceSessionViewPreview: widget.clientInstanceSessionViewPreview,
      clientInstanceResourceViewPreview:
          widget.clientInstanceResourceViewPreview,
      clientInstanceResourceViewOwner: widget.clientInstanceResourceViewOwner,
      clientInstanceResourceViewReader: clientInstanceResourceViewReader,
      clientInstanceSessionViewOwner: widget.clientInstanceSessionViewOwner,
      clientInstanceSessionViewReader: clientInstanceSessionViewReader,
      clientInstanceSessionResourceConvergenceOwner:
          widget.clientInstanceSessionResourceConvergenceOwner,
      clientInstanceSessionResourceConvergenceReader:
          clientInstanceSessionResourceConvergenceReader,
      runAttemptLeaseDispatchPreflightPreview:
          widget.runAttemptLeaseDispatchPreflightPreview,
      runAttemptLeaseDispatchPreflightRequest:
          widget.runAttemptLeaseDispatchPreflightRequest,
      runAttemptLeaseDispatchPreflightReader:
          runAttemptLeaseDispatchPreflightReader,
      runnerDispatchPlanPreview: widget.runnerDispatchPlanPreview,
      runnerDispatchPlanPreviewRequest: widget.runnerDispatchPlanPreviewRequest,
      runnerDispatchPlanPreviewReader: runnerDispatchPlanPreviewReader,
      runnerDispatchAdmissionRequest: widget.runnerDispatchAdmissionRequest,
      runnerDispatchAdmissionReader: runnerDispatchAdmissionReader,
      runnerDispatchAdmission: widget.runnerDispatchAdmission,
      runnerTransportAdmissionRequest: widget.runnerTransportAdmissionRequest,
      runnerTransportAdmissionReader: runnerTransportAdmissionReader,
      runnerTransportAdmission: widget.runnerTransportAdmission,
      runnerExecutionBoundaryRequest: widget.runnerExecutionBoundaryRequest,
      runnerExecutionBoundaryReader: runnerExecutionBoundaryReader,
      runnerExecutionBoundary: widget.runnerExecutionBoundary,
    );
  }

  void _configureRunObservedCandidate(String? token) {
    if (token == null ||
        !widget.enableRunObservedCandidate ||
        widget.runObservedReader != null) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl:
          widget.runObservedCandidateApiOrigin ??
          ForgeConversationsApiOrigin.baseUrl,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _runObservedCandidateApi = api;
    _runObservedCandidateReader = (conversationID, runID) => api
        .readRunObservedCandidate(conversationID: conversationID, runID: runID);
  }

  void _configureRunExecutionEvidenceCandidate(String? token) {
    final expectedRun = widget.runObserved;
    final expectedReceipt = widget.sessionRunnerReceiptObservation;
    final origin = widget.runExecutionEvidenceCandidateApiOrigin;
    if (token == null ||
        !widget.enableRunExecutionEvidenceCandidate ||
        widget.runExecutionEvidenceReader != null ||
        expectedRun == null ||
        expectedReceipt == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _runExecutionEvidenceCandidateApi = api;
    final validatedRun = ForgeRunObserved.fromJson(expectedRun.toJson());
    final validatedReceipt = ForgeSessionRunnerReceiptObservation.fromJson(
      expectedReceipt.toJson(),
    );
    final expectedRunJSON = jsonEncode(validatedRun.toJson());
    final expectedReceiptJSON = jsonEncode(validatedReceipt.toJson());
    _runExecutionEvidenceCandidateReader =
        (conversationID, runID, runObserved, sessionReceiptObserved) {
          final requestedRun = ForgeRunObserved.fromJson(runObserved.toJson());
          final requestedReceipt =
              ForgeSessionRunnerReceiptObservation.fromJson(
                sessionReceiptObserved.toJson(),
              );
          if (conversationID != validatedRun.conversationID ||
              runID != validatedRun.runID ||
              jsonEncode(requestedRun.toJson()) != expectedRunJSON ||
              jsonEncode(requestedReceipt.toJson()) != expectedReceiptJSON) {
            return Future<ForgeRunExecutionEvidence>.error(
              const FormatException(
                'Forge Run execution-evidence source binding changed.',
              ),
            );
          }
          return api.previewRunExecutionEvidence(
            conversationID: conversationID,
            runID: runID,
            runObserved: validatedRun,
            sessionReceiptObserved: validatedReceipt,
          );
        };
  }

  void _configureSessionRunnerReceiptHistoryCandidate(String? token) {
    final expectedHistory = widget.sessionRunnerReceiptHistoryRequest;
    final origin = widget.sessionRunnerReceiptHistoryCandidateApiOrigin;
    if (token == null ||
        !widget.enableSessionRunnerReceiptHistoryCandidate ||
        widget.sessionRunnerReceiptHistoryReader != null ||
        expectedHistory == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _sessionRunnerReceiptHistoryCandidateApi = api;
    final pinned = ForgeSessionRunnerReceiptHistory.fromJson(
      expectedHistory.toJson(),
    );
    final expectedJSON = jsonEncode(pinned.toJson());
    _sessionRunnerReceiptHistoryCandidateReader =
        (conversationID, runID, requested) {
          final validated = ForgeSessionRunnerReceiptHistory.fromJson(
            requested.toJson(),
          );
          if (jsonEncode(validated.toJson()) != expectedJSON ||
              !validated.isFor(conversationID, runID)) {
            return Future<ForgeSessionRunnerReceiptHistory>.error(
              const FormatException(
                'Forge session Runner receipt-history request binding changed.',
              ),
            );
          }
          return api.previewSessionRunnerReceiptHistory(
            conversationID: conversationID,
            runID: runID,
            history: pinned,
          );
        };
  }

  void _configureSessionRunnerReconciliationProjectionCandidate(String? token) {
    final expectedHistory = widget.sessionRunnerReconciliationProjectionRequest;
    final origin =
        widget.sessionRunnerReconciliationProjectionCandidateApiOrigin;
    if (token == null ||
        (!widget.enableSessionRunnerReconciliationProjectionCandidate &&
            !widget
                .enableSessionRunnerReconciliationProjectionHistoryChainCandidate) ||
        widget.sessionRunnerReconciliationProjectionReader != null ||
        expectedHistory == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _sessionRunnerReconciliationProjectionCandidateApi = api;
    final pinned = ForgeSessionRunnerReceiptHistory.fromJson(
      expectedHistory.toJson(),
    );
    final expectedJSON = jsonEncode(pinned.toJson());
    _sessionRunnerReconciliationProjectionCandidateReader =
        (conversationID, runID, requested) {
          final validated = ForgeSessionRunnerReceiptHistory.fromJson(
            requested.toJson(),
          );
          if (jsonEncode(validated.toJson()) != expectedJSON ||
              !validated.isFor(conversationID, runID) ||
              !validated.hasUncertainTerminal) {
            return Future<ForgeSessionRunnerReconciliationProjection>.error(
              const FormatException(
                'Forge reconciliation projection request binding changed.',
              ),
            );
          }
          if (widget
              .enableSessionRunnerReconciliationProjectionHistoryChainCandidate) {
            return api.previewSessionRunnerReconciliationFromHistory(
              conversationID: conversationID,
              runID: runID,
              history: pinned,
            );
          }
          return api.previewSessionRunnerReconciliationProjection(
            conversationID: conversationID,
            runID: runID,
            history: pinned,
          );
        };
  }

  void _configureDeviceInventoryCandidate(String? token) {
    final owner = widget.deviceInventoryOwner;
    final origin = widget.deviceInventoryCandidateApiOrigin;
    if (token == null ||
        !widget.enableDeviceInventoryCandidate ||
        widget.deviceInventoryReader != null ||
        owner == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
      useWallClockTimeout: true,
    );
    _deviceInventoryCandidateApi = api;
    _deviceInventoryCandidateReader = (requestedOwner) {
      if (requestedOwner != owner) {
        return Future<ForgeDeviceInventoryPage>.error(
          const FormatException(
            'Forge device inventory owner binding changed.',
          ),
        );
      }
      return api.readDeviceInventoryCandidate(owner: owner);
    };
  }

  void _configureDeviceInventoryV2Candidate(String? token) {
    if (token == null ||
        !widget.enableDeviceInventoryV2Candidate ||
        widget.deviceInventoryV2Reader != null ||
        widget.deviceInventoryOwner == null) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl:
          widget.deviceInventoryV2CandidateApiOrigin ??
          ForgeConversationsApiOrigin.baseUrl,
      accessToken: token,
      httpClient: widget.httpClient,
      useWallClockTimeout: true,
    );
    _deviceInventoryV2CandidateApi = api;
    _deviceInventoryV2CandidateReader = (owner) =>
        api.readDeviceInventoryCandidateV2(owner: owner);
  }

  void _configureDeviceInventoryResourceConvergenceCandidate(String? token) {
    final owner = widget.deviceInventoryResourceConvergenceOwner;
    if (token == null ||
        !widget.enableDeviceInventoryResourceConvergenceCandidate ||
        widget.deviceInventoryResourceConvergenceReader != null ||
        owner == null) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl:
          widget.deviceInventoryResourceConvergenceCandidateApiOrigin ??
          ForgeConversationsApiOrigin.baseUrl,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _deviceInventoryResourceConvergenceCandidateApi = api;
    _deviceInventoryResourceConvergenceCandidateReader = (requestedOwner) {
      if (requestedOwner != owner) {
        return Future<ForgeDeviceInventoryResourceConvergence>.error(
          const FormatException(
            'Forge inventory/resource convergence owner binding changed.',
          ),
        );
      }
      return api.readConvergedInventoryResourceView(owner: owner);
    };
  }

  void _configureDeviceInventoryRegistryPlacementPreviewCandidate(
    String? token,
  ) {
    final owner = widget.deviceInventoryOwner;
    final requirements = widget.deviceInventoryRegistryPlacementRequirements;
    final origin =
        widget.deviceInventoryRegistryPlacementPreviewCandidateApiOrigin;
    if (token == null ||
        !widget.enableDeviceInventoryRegistryPlacementPreviewCandidate ||
        widget.deviceInventoryRegistryPlacementPreviewReader != null ||
        owner == null ||
        requirements == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _deviceInventoryRegistryPlacementPreviewCandidateApi = api;
    _deviceInventoryRegistryPlacementPreviewCandidateReader =
        (requestedOwner, requestedRequirements) {
          if (requestedOwner != owner) {
            return Future<ForgeDeviceRegistryPlacementPreview>.error(
              const FormatException(
                'Forge registry placement owner binding changed.',
              ),
            );
          }
          final validatedRequirements =
              ForgeDevicePlacementRequirements.fromJson(
                requestedRequirements.toJson(),
              );
          final expectedRequirements =
              ForgeDevicePlacementRequirements.fromJson(requirements.toJson());
          if (jsonEncode(validatedRequirements.toJson()) !=
              jsonEncode(expectedRequirements.toJson())) {
            return Future<ForgeDeviceRegistryPlacementPreview>.error(
              const FormatException(
                'Forge registry placement requirements binding changed.',
              ),
            );
          }
          return api.previewDevicePlacementFromRegistry(
            owner: owner,
            requirements: expectedRequirements,
            candidateOrigin: origin,
          );
        };
  }

  void _configureSchedulerSelectionPreviewCandidate(String? token) {
    final request = widget.schedulerSelectionPreviewRequest;
    final origin = widget.schedulerSelectionPreviewCandidateApiOrigin;
    if (token == null ||
        !widget.enableSchedulerSelectionPreviewCandidate ||
        widget.schedulerSelectionPreviewReader != null ||
        request == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _schedulerSelectionPreviewCandidateApi = api;
    _schedulerSelectionPreviewCandidateReader = (requested) {
      final expectedRequest = ForgeSchedulerSelectionPreviewRequest.fromJson(
        request.toJson(),
      );
      final validatedRequest = ForgeSchedulerSelectionPreviewRequest.fromJson(
        requested.toJson(),
      );
      if (jsonEncode(validatedRequest.toJson()) !=
          jsonEncode(expectedRequest.toJson())) {
        return Future<ForgeSchedulerSelectionPreview>.error(
          const FormatException(
            'Forge scheduler selection request binding changed.',
          ),
        );
      }
      return api.previewSchedulerSelection(
        request: expectedRequest,
        candidateOrigin: origin,
      );
    };
  }

  void _configureSchedulerSelectionLeaseCandidate(String? token) {
    final request = widget.schedulerSelectionLeaseRequest;
    final origin = widget.schedulerSelectionLeaseCandidateApiOrigin;
    final idempotencyKey = widget.schedulerSelectionLeaseIdempotencyKey;
    if (token == null ||
        !widget.enableSchedulerSelectionLeaseCandidate ||
        widget.schedulerSelectionLeaseReader != null ||
        request == null ||
        origin == null ||
        origin.trim().isEmpty ||
        idempotencyKey == null ||
        idempotencyKey.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _schedulerSelectionLeaseCandidateApi = api;
    _schedulerSelectionLeaseCandidateReader = (requested, requestedKey) {
      final expectedRequest = ForgeSchedulerSelectionLeaseRequest.fromJson(
        request.toJson(),
      );
      final validatedRequest = ForgeSchedulerSelectionLeaseRequest.fromJson(
        requested.toJson(),
      );
      if (jsonEncode(validatedRequest.toJson()) !=
              jsonEncode(expectedRequest.toJson()) ||
          requestedKey != idempotencyKey) {
        return Future<ForgeSchedulerSelectionLease>.error(
          const FormatException(
            'Forge scheduler lease request or idempotency binding changed.',
          ),
        );
      }
      return api.claimSchedulerSelectionLease(
        request: expectedRequest,
        idempotencyKey: idempotencyKey,
        candidateOrigin: origin,
      );
    };
  }

  void _configureSchedulerSelectionLeaseRenewalCandidate(String? token) {
    final request = widget.schedulerSelectionLeaseRenewalRequest;
    final origin = widget.schedulerSelectionLeaseRenewalCandidateApiOrigin;
    final idempotencyKey = widget.schedulerSelectionLeaseRenewalIdempotencyKey;
    if (token == null ||
        !widget.enableSchedulerSelectionLeaseRenewalCandidate ||
        widget.schedulerSelectionLeaseRenewalReader != null ||
        request == null ||
        origin == null ||
        origin.trim().isEmpty ||
        idempotencyKey == null ||
        idempotencyKey.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _schedulerSelectionLeaseRenewalCandidateApi = api;
    _schedulerSelectionLeaseRenewalCandidateReader = (requested, requestedKey) {
      final expectedRequest =
          ForgeSchedulerSelectionLeaseRenewalRequest.fromJson(request.toJson());
      final validatedRequest =
          ForgeSchedulerSelectionLeaseRenewalRequest.fromJson(
            requested.toJson(),
          );
      if (jsonEncode(validatedRequest.toJson()) !=
              jsonEncode(expectedRequest.toJson()) ||
          requestedKey != idempotencyKey) {
        return Future<ForgeSchedulerSelectionLease>.error(
          const FormatException(
            'Forge scheduler lease renewal request or idempotency binding changed.',
          ),
        );
      }
      return api.renewSchedulerSelectionLease(
        request: expectedRequest,
        idempotencyKey: idempotencyKey,
        candidateOrigin: origin,
      );
    };
  }

  void _configureSchedulerSelectionLeaseReleaseCandidate(String? token) {
    final request = widget.schedulerSelectionLeaseReleaseRequest;
    final origin = widget.schedulerSelectionLeaseReleaseCandidateApiOrigin;
    final idempotencyKey = widget.schedulerSelectionLeaseReleaseIdempotencyKey;
    if (token == null ||
        !widget.enableSchedulerSelectionLeaseReleaseCandidate ||
        widget.schedulerSelectionLeaseReleaseReader != null ||
        request == null ||
        origin == null ||
        origin.trim().isEmpty ||
        idempotencyKey == null ||
        idempotencyKey.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _schedulerSelectionLeaseReleaseCandidateApi = api;
    _schedulerSelectionLeaseReleaseCandidateReader = (requested, requestedKey) {
      final expectedRequest =
          ForgeSchedulerSelectionLeaseReleaseRequest.fromJson(request.toJson());
      final validatedRequest =
          ForgeSchedulerSelectionLeaseReleaseRequest.fromJson(
            requested.toJson(),
          );
      if (jsonEncode(validatedRequest.toJson()) !=
              jsonEncode(expectedRequest.toJson()) ||
          requestedKey != idempotencyKey) {
        return Future<ForgeSchedulerSelectionLeaseRelease>.error(
          const FormatException(
            'Forge scheduler lease release request or idempotency binding changed.',
          ),
        );
      }
      return api.releaseSchedulerSelectionLease(
        request: expectedRequest,
        idempotencyKey: idempotencyKey,
        candidateOrigin: origin,
      );
    };
  }

  void _configureClientInstanceResourceViewCandidate(String? token) {
    final owner = widget.clientInstanceResourceViewOwner;
    if (token == null ||
        !widget.enableClientInstanceResourceViewCandidate ||
        widget.clientInstanceResourceViewReader != null ||
        owner == null) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl:
          widget.clientInstanceResourceViewCandidateApiOrigin ??
          ForgeConversationsApiOrigin.baseUrl,
      accessToken: token,
      httpClient: widget.httpClient,
      useWallClockTimeout: true,
    );
    _clientInstanceResourceViewCandidateApi = api;
    _clientInstanceResourceViewCandidateReader = (requestedOwner) {
      if (requestedOwner != owner) {
        return Future<ForgeClientInstanceResourceView>.error(
          const FormatException(
            'Forge client-instance/resource-view owner binding changed.',
          ),
        );
      }
      return api.readClientInstanceResourceViewCandidate(owner: owner);
    };
  }

  void _configureClientInstanceSessionViewCandidate(String? token) {
    final owner = widget.clientInstanceSessionViewOwner;
    if (token == null ||
        !widget.enableClientInstanceSessionViewCandidate ||
        widget.clientInstanceSessionViewReader != null ||
        owner == null) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl:
          widget.clientInstanceSessionViewCandidateApiOrigin ??
          ForgeConversationsApiOrigin.baseUrl,
      accessToken: token,
      httpClient: widget.httpClient,
      useWallClockTimeout: true,
    );
    _clientInstanceSessionViewCandidateApi = api;
    _clientInstanceSessionViewCandidateReader = (requestedOwner) {
      if (requestedOwner != owner) {
        return Future<ForgeClientInstanceSessionView>.error(
          const FormatException(
            'Forge client-instance/session-view owner binding changed.',
          ),
        );
      }
      return api.readClientInstanceSessionViewCandidate(owner: owner);
    };
  }

  void _configureClientInstanceSessionResourceConvergenceCandidate(
    String? token,
  ) {
    final owner = widget.clientInstanceSessionResourceConvergenceOwner;
    if (token == null ||
        !widget.enableClientInstanceSessionResourceConvergenceCandidate ||
        widget.clientInstanceSessionResourceConvergenceReader != null ||
        owner == null) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl:
          widget.clientInstanceSessionResourceConvergenceCandidateApiOrigin ??
          ForgeConversationsApiOrigin.baseUrl,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _clientInstanceSessionResourceConvergenceCandidateApi = api;
    _clientInstanceSessionResourceConvergenceCandidateReader =
        (requestedOwner) {
          if (requestedOwner != owner) {
            return Future<ForgeClientInstanceSessionResourceConvergence>.error(
              const FormatException(
                'Forge client-instance session/resource owner binding changed.',
              ),
            );
          }
          return api.readConvergedClientInstanceViews(owner: owner);
        };
  }

  void _configureRunAttemptLeaseDispatchPreflightCandidate(String? token) {
    final expectedRequest = widget.runAttemptLeaseDispatchPreflightRequest;
    if (token == null ||
        !widget.enableRunAttemptLeaseDispatchPreflightCandidate ||
        widget.runAttemptLeaseDispatchPreflightReader != null ||
        expectedRequest == null) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl:
          widget.runAttemptLeaseDispatchPreflightCandidateApiOrigin ??
          ForgeConversationsApiOrigin.baseUrl,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _runAttemptLeaseDispatchPreflightCandidateApi = api;
    _runAttemptLeaseDispatchPreflightCandidateReader = (requested) {
      final validated = ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(
        requested.toJson(),
      );
      // Keep the candidate bound to the explicit owner and selected Run that
      // the Gate was configured to preview. The request remains caller
      // supplied; nested placement/lease values are validated by the typed
      // API and candidate route.
      if (validated.owner != expectedRequest.owner ||
          validated.conversationID != expectedRequest.conversationID ||
          validated.runID != expectedRequest.runID) {
        return Future<ForgePreflightFixture>.error(
          const FormatException(
            'Forge Run-Attempt lease preflight owner or Run binding changed.',
          ),
        );
      }
      return api.previewRunAttemptLeaseDispatchPreflight(request: validated);
    };
  }

  void _configureRunnerDispatchPlanPreviewCandidate(String? token) {
    final expectedRequest = widget.runnerDispatchPlanPreviewRequest;
    final origin = widget.runnerDispatchPlanPreviewCandidateApiOrigin;
    if (token == null ||
        !widget.enableRunnerDispatchPlanPreviewCandidate ||
        widget.runnerDispatchPlanPreviewReader != null ||
        expectedRequest == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _runnerDispatchPlanPreviewCandidateApi = api;
    _runnerDispatchPlanPreviewCandidateReader = (requested) {
      final validated = ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(
        requested.toJson(),
      );
      final pinned = ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(
        expectedRequest.toJson(),
      );
      if (validated.owner != pinned.owner ||
          validated.conversationID != pinned.conversationID ||
          validated.runID != pinned.runID ||
          jsonEncode(validated.dispatchPlan.toJson()) !=
              jsonEncode(pinned.dispatchPlan.toJson())) {
        return Future<ForgeRunnerDispatchPlanPreview>.error(
          const FormatException(
            'Forge Runner dispatch-plan preview request binding changed.',
          ),
        );
      }
      return api.previewRunnerDispatchPlan(
        owner: pinned.owner,
        conversationID: pinned.conversationID,
        runID: pinned.runID,
        dispatchPlan: pinned.dispatchPlan,
        candidateOrigin: origin,
      );
    };
  }

  void _configureRunnerExecutionIntentCandidate(String? token) {
    final expectedRequest = widget.runnerExecutionIntentRequest;
    final origin = widget.runnerExecutionIntentCandidateApiOrigin;
    if (token == null ||
        !widget.enableRunnerExecutionIntentCandidate ||
        widget.runnerExecutionIntentReader != null ||
        expectedRequest == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _runnerExecutionIntentCandidateApi = api;
    _runnerExecutionIntentCandidateReader = (requested) {
      final validated = ForgeRunnerExecutionIntentRequest(
        owner: ForgeDeviceOwner.fromJson(requested.owner.toJson()),
        conversationID: requested.conversationID,
        prompt: requested.prompt,
        run: requested.run,
        binding: requested.binding,
        command: requested.command,
      );
      final pinned = expectedRequest;
      if (validated.owner != pinned.owner ||
          validated.conversationID != pinned.conversationID ||
          validated.run.runID != pinned.run.runID ||
          jsonEncode(observeForgeRunnerExecutionIntent(validated).toJson()) !=
              jsonEncode(observeForgeRunnerExecutionIntent(pinned).toJson())) {
        return Future<ForgeRunnerExecutionIntentObservation>.error(
          const FormatException(
            'Forge Runner execution-intent request binding changed.',
          ),
        );
      }
      return api.previewRunnerExecutionIntent(
        request: pinned,
        candidateOrigin: origin,
      );
    };
  }

  void _configureRunnerDispatchAdmissionCandidate(String? token) {
    final expectedRequest = widget.runnerDispatchAdmissionRequest;
    final origin = widget.runnerDispatchAdmissionCandidateApiOrigin;
    if (token == null ||
        !widget.enableRunnerDispatchAdmissionCandidate ||
        widget.runnerDispatchAdmissionReader != null ||
        expectedRequest == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _runnerDispatchAdmissionCandidateApi = api;
    final expectedJSON = jsonEncode(expectedRequest.toJson());
    _runnerDispatchAdmissionCandidateReader = (requested) {
      final validated = ForgeRunnerDispatchAdmissionRequest.fromJson(
        requested.toJson(),
      );
      if (jsonEncode(validated.toJson()) != expectedJSON) {
        return Future<ForgeRunnerDispatchAdmission>.error(
          const FormatException(
            'Forge Runner dispatch admission request binding changed.',
          ),
        );
      }
      return api.previewRunnerDispatchAdmission(
        request: validated,
        candidateOrigin: origin,
      );
    };
  }

  void _configureRunnerTransportAdmissionCandidate(String? token) {
    final expectedRequest = widget.runnerTransportAdmissionRequest;
    final origin = widget.runnerTransportAdmissionCandidateApiOrigin;
    if (token == null ||
        !widget.enableRunnerTransportAdmissionCandidate ||
        widget.runnerTransportAdmissionReader != null ||
        expectedRequest == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _runnerTransportAdmissionCandidateApi = api;
    final expectedJSON = jsonEncode(expectedRequest.toJson());
    _runnerTransportAdmissionCandidateReader = (requested) {
      final validated = ForgeRunnerTransportAdmissionRequest.fromJson(
        requested.toJson(),
      );
      if (jsonEncode(validated.toJson()) != expectedJSON) {
        return Future<ForgeRunnerTransportAdmission>.error(
          const FormatException(
            'Forge Runner transport admission request binding changed.',
          ),
        );
      }
      return api.previewRunnerTransportAdmission(
        request: validated,
        candidateOrigin: origin,
      );
    };
  }

  void _configureRunnerExecutionBoundaryCandidate(String? token) {
    final expectedRequest = widget.runnerExecutionBoundaryRequest;
    final origin = widget.runnerExecutionBoundaryCandidateApiOrigin;
    if (token == null ||
        !widget.enableRunnerExecutionBoundaryCandidate ||
        widget.runnerExecutionBoundaryReader != null ||
        expectedRequest == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _runnerExecutionBoundaryCandidateApi = api;
    final expectedJSON = jsonEncode(expectedRequest.toJson());
    _runnerExecutionBoundaryCandidateReader = (requested) {
      final validated = ForgeRunnerExecutionBoundaryPreviewRequest.fromJson(
        requested.toJson(),
      );
      if (jsonEncode(validated.toJson()) != expectedJSON) {
        return Future<ForgeRunnerExecutionBoundaryObservation>.error(
          const FormatException(
            'Forge Runner execution boundary request binding changed.',
          ),
        );
      }
      return api.previewRunnerExecutionBoundary(
        request: validated,
        candidateOrigin: origin,
      );
    };
  }

  void _configureRunnerAttemptBoundaryCandidate(String? token) {
    final expectedRequest = widget.runnerAttemptBoundaryRequest;
    final origin = widget.runnerAttemptBoundaryCandidateApiOrigin;
    if (token == null ||
        !widget.enableRunnerAttemptBoundaryCandidate ||
        widget.runnerAttemptBoundaryReader != null ||
        expectedRequest == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _runnerAttemptBoundaryCandidateApi = api;
    final expectedJSON = jsonEncode(expectedRequest.toJson());
    _runnerAttemptBoundaryCandidateReader = (requested) {
      final validated = ForgeRunnerAttemptBoundaryPreviewRequest.fromJson(
        requested.toJson(),
      );
      if (jsonEncode(validated.toJson()) != expectedJSON) {
        return Future<ForgeRunnerAttemptBoundaryObservation>.error(
          const FormatException(
            'Forge Runner Attempt boundary request binding changed.',
          ),
        );
      }
      return api.previewRunnerAttemptBoundary(
        request: validated,
        candidateOrigin: origin,
      );
    };
  }

  void _configureLocalRunnerPreviewCandidate(String? token) {
    final expectedRequest = widget.localRunnerPreviewRequest;
    final origin = widget.localRunnerPreviewCandidateApiOrigin;
    if (token == null ||
        !widget.enableLocalRunnerPreviewCandidate ||
        widget.localRunnerPreviewReader != null ||
        expectedRequest == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _localRunnerPreviewCandidateApi = api;
    final expectedJSON = jsonEncode(expectedRequest.toJson());
    _localRunnerPreviewCandidateReader = (requested) {
      final conversationID = requested.intent.conversationID;
      final intentID = requested.intent.prompt.intentID;
      requested.validateForPath(conversationID, intentID);
      if (jsonEncode(requested.toJson()) != expectedJSON) {
        return Future<ForgeLocalRunnerPreviewObservation>.error(
          const FormatException(
            'Forge local Runner preview request binding changed.',
          ),
        );
      }
      return api.previewLocalRunnerExecutionReadiness(
        conversationID: conversationID,
        intentID: intentID,
        request: requested,
      );
    };
  }

  void _configureExecutionReconciliationCandidate(String? token) {
    final expectedInput = widget.executionReconciliationInput;
    if (token == null ||
        !widget.enableExecutionReconciliationCandidate ||
        widget.executionReconciliationReader != null ||
        expectedInput == null) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl:
          widget.executionReconciliationCandidateApiOrigin ??
          ForgeConversationsApiOrigin.baseUrl,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _executionReconciliationCandidateApi = api;
    _executionReconciliationCandidateReader = (requested) {
      final validated = ForgeExecutionReconciliationInput.fromJson(
        requested.toJson(),
      );
      if (validated.owner != expectedInput.owner ||
          validated.conversationID != expectedInput.conversationID ||
          validated.runID != expectedInput.runID) {
        return Future<ForgeExecutionReconciliationObservation>.error(
          const FormatException(
            'Forge execution reconciliation owner or Run binding changed.',
          ),
        );
      }
      return api.previewExecutionReconciliation(
        conversationID: validated.conversationID,
        runID: validated.runID,
        input: validated,
      );
    };
  }

  void _configureExecutionConsentPreviewCandidate(String? token) {
    final expectedOwner = widget.executionConsentPreviewOwner;
    final origin = widget.executionConsentPreviewCandidateApiOrigin;
    if (token == null ||
        !widget.enableExecutionConsentPreviewCandidate ||
        widget.executionConsentPreviewReader != null ||
        expectedOwner == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _executionConsentPreviewCandidateApi = api;
    _executionConsentPreviewCandidateReader =
        ({required ForgeDeviceOwner owner, required String conversationID}) {
          if (owner != expectedOwner) {
            return Future<ForgeExecutionConsentPreview>.error(
              const FormatException(
                'Forge execution consent preview owner binding changed.',
              ),
            );
          }
          return api.getExecutionConsentPreview(
            conversationID: conversationID,
            retryUnauthorized: false,
          );
        };
  }

  void _configureLifecycleRegistryCandidate(String? token) {
    final owner = widget.lifecycleRegistryOwner;
    final origin = widget.lifecycleRegistryCandidateApiOrigin;
    if (token == null ||
        !widget.enableLifecycleRegistryCandidate ||
        widget.lifecycleRegistryReader != null ||
        owner == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _lifecycleRegistryCandidateApi = api;
    _lifecycleRegistryCandidateReader = (requestedOwner) {
      if (requestedOwner != owner) {
        return Future<ForgeDeviceEnrollmentHeartbeatLifecycleRegistry>.error(
          const FormatException(
            'Forge lifecycle registry owner binding changed.',
          ),
        );
      }
      return api.readLifecycleRegistryCandidate(
        owner: owner,
        candidateOrigin: origin,
      );
    };
  }

  void _configureDeviceCredentialCandidate(String? token) {
    final expectedOwner = widget.deviceCredentialCandidateOwner;
    final expectedRequest = widget.deviceCredentialCandidateRequest;
    final origin = widget.deviceCredentialCandidateApiOrigin;
    if (token == null ||
        !widget.enableDeviceCredentialCandidate ||
        widget.deviceCredentialCandidateReader != null ||
        expectedOwner == null ||
        expectedRequest == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _deviceCredentialCandidateApi = api;
    _deviceCredentialCandidateReader =
        ({
          required ForgeDeviceOwner owner,
          required ForgeDeviceCredentialLifecycleRequest request,
        }) {
          if (owner != expectedOwner) {
            return Future<ForgeDeviceCredentialLifecycleCandidate>.error(
              const FormatException(
                'Forge credential candidate owner binding changed.',
              ),
            );
          }
          final validatedRequest =
              ForgeDeviceCredentialLifecycleRequest.fromJson(request.toJson());
          final validatedPinnedRequest =
              ForgeDeviceCredentialLifecycleRequest.fromJson(
                expectedRequest.toJson(),
              );
          if (jsonEncode(validatedRequest.toJson()) !=
              jsonEncode(validatedPinnedRequest.toJson())) {
            return Future<ForgeDeviceCredentialLifecycleCandidate>.error(
              const FormatException(
                'Forge credential candidate request binding changed.',
              ),
            );
          }
          return api.previewDeviceCredentialCandidate(
            owner: expectedOwner,
            request: validatedPinnedRequest,
            candidateOrigin: origin,
          );
        };
  }

  void _configurePendingRunIntentCandidate(String? token) {
    final expectedOwner = widget.pendingRunIntentOwner;
    final origin = widget.pendingRunIntentCandidateApiOrigin;
    if (token == null ||
        !widget.enablePendingRunIntentCandidate ||
        expectedOwner == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _pendingRunIntentCandidateApi = api;
    _pendingRunIntentCandidateSubmitter =
        ({
          required ForgeDeviceOwner owner,
          required conversationID,
          required content,
          required expectedVersion,
          required idempotencyKey,
        }) {
          if (owner != expectedOwner) {
            return Future<ForgePendingRunIntentSubmission>.error(
              const FormatException(
                'Forge pending Run-intent owner binding changed.',
              ),
            );
          }
          return api.submitPendingRunIntent(
            conversationID: conversationID,
            content: content,
            expectedVersion: expectedVersion,
            idempotencyKey: idempotencyKey,
          );
        };
    _pendingRunIntentCandidateReader = (conversationID) =>
        api.listPendingRunIntents(conversationID: conversationID);
    _pendingRunIntentCandidatePageReader = (conversationID, before) => api
        .listPendingRunIntents(conversationID: conversationID, before: before);
    _pendingRunIntentCandidateTimelineReader = (conversationID, intentID) =>
        api.listPendingRunIntentTimeline(
          conversationID: conversationID,
          intentID: intentID,
        );
  }

  void _configurePromptAppendReceiptCandidate(String? token) {
    final expectedOwner = widget.promptAppendReceiptOwner;
    final origin = widget.promptAppendReceiptCandidateApiOrigin;
    if (token == null ||
        !widget.enablePromptAppendReceiptCandidate ||
        widget.promptAppendReceiptSubmitter != null ||
        expectedOwner == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _promptAppendReceiptCandidateApi = api;
    _promptAppendReceiptCandidateSubmitter =
        ({
          required ForgeDeviceOwner owner,
          required conversationID,
          required content,
          required expectedVersion,
          required idempotencyKey,
        }) {
          if (owner != expectedOwner) {
            return Future<ForgePromptAppendReceiptObservation>.error(
              const FormatException(
                'Forge Prompt append receipt owner binding changed.',
              ),
            );
          }
          return api.appendPromptReceipt(
            owner: expectedOwner,
            conversationID: conversationID,
            content: content,
            expectedVersion: expectedVersion,
            idempotencyKey: idempotencyKey,
          );
        };
  }

  @override
  void dispose() {
    // ForgeSessionsScreen owns an injected test client when one is supplied;
    // closing the candidate API here would otherwise close that shared client
    // before the child screen finishes disposing.
    if (widget.httpClient == null) {
      _runObservedCandidateApi?.close();
      _runExecutionEvidenceCandidateApi?.close();
      _sessionRunnerReceiptHistoryCandidateApi?.close();
      _sessionRunnerReconciliationProjectionCandidateApi?.close();
      _deviceInventoryCandidateApi?.close();
      _localRunnerPreviewCandidateApi?.close();
      _deviceInventoryV2CandidateApi?.close();
      _deviceInventoryResourceConvergenceCandidateApi?.close();
      _deviceInventoryRegistryPlacementPreviewCandidateApi?.close();
      _schedulerSelectionPreviewCandidateApi?.close();
      _schedulerSelectionLeaseCandidateApi?.close();
      _schedulerSelectionLeaseRenewalCandidateApi?.close();
      _schedulerSelectionLeaseReleaseCandidateApi?.close();
      _clientInstanceResourceViewCandidateApi?.close();
      _clientInstanceSessionViewCandidateApi?.close();
      _clientInstanceSessionResourceConvergenceCandidateApi?.close();
      _runAttemptLeaseDispatchPreflightCandidateApi?.close();
      _runnerDispatchPlanPreviewCandidateApi?.close();
      _runnerExecutionIntentCandidateApi?.close();
      _runnerDispatchAdmissionCandidateApi?.close();
      _runnerTransportAdmissionCandidateApi?.close();
      _runnerExecutionBoundaryCandidateApi?.close();
      _runnerAttemptBoundaryCandidateApi?.close();
      _executionReconciliationCandidateApi?.close();
      _executionConsentPreviewCandidateApi?.close();
      _lifecycleRegistryCandidateApi?.close();
      _deviceCredentialCandidateApi?.close();
      _pendingRunIntentCandidateApi?.close();
      _promptAppendReceiptCandidateApi?.close();
    }
    super.dispose();
  }

  /// Reconcile same-document navigation that happened while secure storage
  /// was restoring. The Gate may outlive the location that created it, so the
  /// route passed into the widget is only a bootstrap hint. A real Forge
  /// location is authoritative for that hint; a non-product native base URI
  /// keeps the route value supplied by the native Navigator.
  String? _conversationSelectionAfterRestore() {
    final location = BrowserNavigation.currentUri;
    if (_isForgeSessionsLocation(location)) {
      return _conversationIDFromLocation(location);
    }
    return widget.initialConversationID;
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
}
