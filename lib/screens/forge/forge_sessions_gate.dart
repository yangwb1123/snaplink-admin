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
import '../../api/forge_attempt_request_preview.dart';
import '../../api/forge_device_inventory_models.dart';
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
import '../../api/forge_execution_reconciliation_observation.dart';
import '../../api/forge_device_enrollment_heartbeat_lifecycle_registry.dart';
import '../../api/forge_device_credential_candidate.dart';
import '../../api/forge_client_instance_session_view.dart';
import '../../api/forge_client_instance_resource_view.dart';
import '../../api/forge_preflight_fixture.dart';
import '../../api/forge_run_attempt_lease_dispatch_preflight.dart';
import '../../api/forge_runner_dispatch_plan_preview.dart';
import 'forge_sessions_screen.dart';
import 'forge_sessions_device_observation.dart';

class ForgeSessionsGate extends StatefulWidget {
  final ForgeCredentialStore? credentialStore;
  final String? initialConversationID;
  @visibleForTesting
  final http.Client? httpClient;
  final ForgeSessionDeviceObservation? deviceObservation;
  final ForgeSessionPlacementRequest? deviceObservationRequest;
  final ForgeRunIntentObservation? runIntentObservation;
  final ForgeRunnerExecutionIntentObservation? runnerExecutionIntentObservation;

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
  /// seam. The default Gate leaves it unset, so production `/run-intents`
  /// remains unreachable until its separate governance decision is accepted.
  final ForgePendingRunIntentReader? pendingRunIntentReader;

  /// Optional paged variant of [pendingRunIntentReader]. The first call uses
  /// a null cursor; subsequent calls receive the strictly validated cursor
  /// from the previous page. The default Gate leaves it unset.
  final ForgePendingRunIntentPageReader? pendingRunIntentPageReader;

  /// Optional, explicitly injected owner-scoped pending Run-intent timeline
  /// seam. The default Gate leaves it unset, so the timeline endpoint remains
  /// unreachable until its separate governance decision is accepted.
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
    this.httpClient,
    this.deviceObservation,
    this.deviceObservationRequest,
    this.runIntentObservation,
    this.runnerExecutionIntentObservation,
    this.runObserved,
    this.runObservedReader,
    this.enableRunObservedCandidate = false,
    this.runObservedCandidateApiOrigin,
    this.enableDeviceInventoryV2Candidate = false,
    this.deviceInventoryV2CandidateApiOrigin,
    this.runExecutionEvidence,
    this.sessionRunnerReceiptObservation,
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
    this.pendingRunIntentPreview,
    this.enablePendingRunIntentCandidate = false,
    this.pendingRunIntentOwner,
    this.pendingRunIntentCandidateApiOrigin,
    this.deviceInventoryOwner,
    this.deviceInventoryReader,
    this.enableDeviceInventoryCandidate = false,
    this.deviceInventoryCandidateApiOrigin,
    this.deviceInventoryV2Reader,
    this.deviceInventoryRegistryPlacementRequirements,
    this.deviceInventoryRegistryPlacementPreviewReader,
    this.enableDeviceInventoryRegistryPlacementPreviewCandidate = false,
    this.deviceInventoryRegistryPlacementPreviewCandidateApiOrigin,
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
  ForgeConversationsApi? _deviceInventoryCandidateApi;
  ForgeDeviceInventoryCandidateReader? _deviceInventoryCandidateReader;
  ForgeConversationsApi? _localRunnerPreviewCandidateApi;
  ForgeLocalRunnerPreviewReader? _localRunnerPreviewCandidateReader;
  ForgeConversationsApi? _deviceInventoryV2CandidateApi;
  ForgeDeviceInventoryV2Reader? _deviceInventoryV2CandidateReader;
  ForgeConversationsApi? _deviceInventoryRegistryPlacementPreviewCandidateApi;
  ForgeDeviceRegistryPlacementPreviewReader?
  _deviceInventoryRegistryPlacementPreviewCandidateReader;
  ForgeConversationsApi? _clientInstanceResourceViewCandidateApi;
  ForgeClientInstanceResourceViewReader?
  _clientInstanceResourceViewCandidateReader;
  ForgeConversationsApi? _clientInstanceSessionViewCandidateApi;
  ForgeClientInstanceSessionViewReader?
  _clientInstanceSessionViewCandidateReader;
  ForgeConversationsApi? _runAttemptLeaseDispatchPreflightCandidateApi;
  ForgeRunAttemptLeaseDispatchPreflightReader?
  _runAttemptLeaseDispatchPreflightCandidateReader;
  ForgeConversationsApi? _runnerDispatchPlanPreviewCandidateApi;
  ForgeRunnerDispatchPlanPreviewReader?
  _runnerDispatchPlanPreviewCandidateReader;
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
    _configureDeviceInventoryCandidate(token);
    _configureLocalRunnerPreviewCandidate(token);
    _configureDeviceInventoryV2Candidate(token);
    _configureDeviceInventoryRegistryPlacementPreviewCandidate(token);
    _configureClientInstanceResourceViewCandidate(token);
    _configureClientInstanceSessionViewCandidate(token);
    _configureRunAttemptLeaseDispatchPreflightCandidate(token);
    _configureRunnerDispatchPlanPreviewCandidate(token);
    _configureExecutionReconciliationCandidate(token);
    _configureExecutionConsentPreviewCandidate(token);
    _configureLifecycleRegistryCandidate(token);
    _configureDeviceCredentialCandidate(token);
    _configurePendingRunIntentCandidate(token);
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
    final deviceInventoryReader =
        widget.deviceInventoryReader ?? _deviceInventoryCandidateReader;
    final deviceInventoryV2Reader =
        widget.deviceInventoryV2Reader ?? _deviceInventoryV2CandidateReader;
    final deviceInventoryRegistryPlacementPreviewReader =
        widget.deviceInventoryRegistryPlacementPreviewReader ??
        _deviceInventoryRegistryPlacementPreviewCandidateReader;
    final clientInstanceResourceViewReader =
        widget.clientInstanceResourceViewReader ??
        _clientInstanceResourceViewCandidateReader;
    final clientInstanceSessionViewReader =
        widget.clientInstanceSessionViewReader ??
        _clientInstanceSessionViewCandidateReader;
    final runAttemptLeaseDispatchPreflightReader =
        widget.runAttemptLeaseDispatchPreflightReader ??
        _runAttemptLeaseDispatchPreflightCandidateReader;
    final runnerDispatchPlanPreviewReader =
        widget.runnerDispatchPlanPreviewReader ??
        _runnerDispatchPlanPreviewCandidateReader;
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
    final pendingRunIntentSubmitter = _pendingRunIntentCandidateSubmitter;
    return ForgeSessionsScreen(
      accessToken: token,
      apiOrigin: ForgeConversationsApiOrigin.baseUrl,
      initialConversationID: _resolvedInitialConversationID,
      httpClient: widget.httpClient,
      deviceObservation: widget.deviceObservation,
      deviceObservationRequest: widget.deviceObservationRequest,
      runIntentObservation: widget.runIntentObservation,
      runnerExecutionIntentObservation: widget.runnerExecutionIntentObservation,
      localRunnerPreview: widget.localRunnerPreview,
      localRunnerPreviewRequest: widget.localRunnerPreviewRequest,
      localRunnerPreviewReader: localRunnerPreviewReader,
      runObserved: widget.runObserved,
      runObservedReader: runObservedReader,
      runExecutionEvidence: widget.runExecutionEvidence,
      sessionRunnerReceiptObservation: widget.sessionRunnerReceiptObservation,
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
      pendingRunIntentPreview: widget.pendingRunIntentPreview,
      pendingRunIntentOwner: widget.pendingRunIntentOwner,
      pendingRunIntentSubmitter: pendingRunIntentSubmitter,
      deviceInventoryOwner: widget.deviceInventoryOwner,
      deviceInventoryReader: deviceInventoryReader,
      deviceInventoryV2Reader: deviceInventoryV2Reader,
      deviceInventoryRegistryPlacementRequirements:
          widget.deviceInventoryRegistryPlacementRequirements,
      deviceInventoryRegistryPlacementPreviewReader:
          deviceInventoryRegistryPlacementPreviewReader,
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
      pendingRunIntentReader: widget.pendingRunIntentReader,
      pendingRunIntentPageReader: widget.pendingRunIntentPageReader,
      pendingRunIntentTimelineReader: widget.pendingRunIntentTimelineReader,
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
      runAttemptLeaseDispatchPreflightPreview:
          widget.runAttemptLeaseDispatchPreflightPreview,
      runAttemptLeaseDispatchPreflightRequest:
          widget.runAttemptLeaseDispatchPreflightRequest,
      runAttemptLeaseDispatchPreflightReader:
          runAttemptLeaseDispatchPreflightReader,
      runnerDispatchPlanPreview: widget.runnerDispatchPlanPreview,
      runnerDispatchPlanPreviewRequest: widget.runnerDispatchPlanPreviewRequest,
      runnerDispatchPlanPreviewReader: runnerDispatchPlanPreviewReader,
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
    );
    _deviceInventoryV2CandidateApi = api;
    _deviceInventoryV2CandidateReader = (owner) =>
        api.readDeviceInventoryCandidateV2(owner: owner);
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
  }

  @override
  void dispose() {
    // ForgeSessionsScreen owns an injected test client when one is supplied;
    // closing the candidate API here would otherwise close that shared client
    // before the child screen finishes disposing.
    if (widget.httpClient == null) {
      _runObservedCandidateApi?.close();
      _deviceInventoryCandidateApi?.close();
      _localRunnerPreviewCandidateApi?.close();
      _deviceInventoryV2CandidateApi?.close();
      _deviceInventoryRegistryPlacementPreviewCandidateApi?.close();
      _clientInstanceResourceViewCandidateApi?.close();
      _clientInstanceSessionViewCandidateApi?.close();
      _runAttemptLeaseDispatchPreflightCandidateApi?.close();
      _runnerDispatchPlanPreviewCandidateApi?.close();
      _executionReconciliationCandidateApi?.close();
      _executionConsentPreviewCandidateApi?.close();
      _lifecycleRegistryCandidateApi?.close();
      _deviceCredentialCandidateApi?.close();
      _pendingRunIntentCandidateApi?.close();
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
