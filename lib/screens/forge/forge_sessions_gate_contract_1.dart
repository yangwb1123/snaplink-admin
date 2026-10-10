part of 'forge_sessions_gate.dart';

/// Typed documentation for the unchanged ForgeSessionsGate constructor surface.
abstract interface class _ForgeSessionsGateContract1 {
  ForgeCredentialStore? get credentialStore;

  String? get initialConversationID;

  /// Optional local client-instance selection hint. The value only narrows
  /// the owner-scoped list after a caller-supplied instance observation has
  /// converged; it never authenticates an instance or changes API requests.
  String? get initialClientInstanceID;

  /// Enables the explicitly reviewed, owner-scoped Conversation SSE read for
  /// a candidate or integration harness. The default Gate keeps polling.
  bool get enableConversationChangesStream;

  /// Bounded wait for the optional Conversation SSE read. The screen keeps
  /// its own upper-bound validation; the Gate default remains 15 seconds.
  int get conversationChangesStreamWaitMS;

  http.Client? get httpClient;

  ForgeSessionDeviceObservation? get deviceObservation;

  ForgeSessionPlacementRequest? get deviceObservationRequest;

  ForgeRunIntentObservation? get runIntentObservation;

  ForgeRunnerExecutionIntentObservation? get runnerExecutionIntentObservation;

  /// Explicit request and reader for the authenticated Runner
  /// execution-intent preview candidate. The default Gate leaves these unset
  /// and therefore makes no candidate request.
  ForgeRunnerExecutionIntentRequest? get runnerExecutionIntentRequest;

  Future<ForgeRunnerExecutionIntentObservation> Function(
    ForgeRunnerExecutionIntentRequest,
  )?
  get runnerExecutionIntentReader;

  /// Enables the reviewed, read-only Runner execution-intent candidate for a
  /// test or candidate harness. Production construction keeps this disabled.
  bool get enableRunnerExecutionIntentCandidate;

  /// Candidate-only origin for the Runner execution-intent POST.
  String? get runnerExecutionIntentCandidateApiOrigin;

  /// Optional local Runner execution-readiness observation. It remains
  /// display-only and process-local; supplying it never executes a command.
  ForgeLocalRunnerPreviewObservation? get localRunnerPreview;

  /// Explicit request and reader for the private local Runner execution
  /// readiness candidate. Both are required before the Gate can reach the
  /// route; the default Gate remains request-free.
  ForgeLocalRunnerPreviewRequest? get localRunnerPreviewRequest;

  Future<ForgeLocalRunnerPreviewObservation> Function(
    ForgeLocalRunnerPreviewRequest,
  )?
  get localRunnerPreviewReader;

  /// Enables the explicitly reviewed, read-only local Runner execution
  /// readiness candidate for a test or candidate harness. Production
  /// construction keeps this disabled.
  bool get enableLocalRunnerPreviewCandidate;

  /// Candidate-only origin for the local Runner execution readiness POST.
  /// The origin must be explicit when the candidate is enabled.
  String? get localRunnerPreviewCandidateApiOrigin;

  ForgeRunObserved? get runObserved;

  Future<ForgeRunObserved> Function(String, String)? get runObservedReader;

  /// Explicit independent reader for the selected Run's content-free Runner
  /// receipt. It is forwarded only as an injected callback; the default Gate
  /// leaves it unset and does not derive or mount a receipt API route.
  Future<ForgeSessionRunnerReceiptObservation> Function(String, String)?
  get sessionRunnerReceiptObservationReader;

  /// Enables the explicitly reviewed, read-only Run observation candidate
  /// adapter for a test or candidate harness. The default Gate keeps this
  /// disabled, so the candidate `/observation` route remains unreachable from
  /// production Web/App/Mobile construction.
  bool get enableRunObservedCandidate;

  /// Optional origin used by [enableRunObservedCandidate]. Supplying this in
  /// a candidate harness keeps the route's environment explicit; when it is
  /// omitted, the normal Forge Conversations origin is used.
  String? get runObservedCandidateApiOrigin;

  /// Enables the explicitly reviewed, read-only v2 inventory observation
  /// candidate adapter for a test or candidate harness. The default Gate
  /// keeps this disabled, so the candidate device route remains unreachable
  /// from production Web/App/Mobile construction.
  bool get enableDeviceInventoryV2Candidate;

  /// Optional origin used by [enableDeviceInventoryV2Candidate]. An explicit
  /// owner declaration is still required through [deviceInventoryOwner].
  String? get deviceInventoryV2CandidateApiOrigin;

  ForgeRunExecutionEvidence? get runExecutionEvidence;

  ForgeSessionRunnerReceiptObservation? get sessionRunnerReceiptObservation;

  ForgeSessionRunnerReceiptVectors? get sessionRunnerReceiptVectorsPreview;

  Future<String?> Function()? get sessionRunnerReceiptVectorsFileReader;

  ForgeSessionRunnerReceiptHistory? get sessionRunnerReceiptHistoryPreview;

  Future<String?> Function()? get sessionRunnerReceiptHistoryFileReader;

  ForgeSessionRunnerReconciliationProjection?
  get sessionRunnerReconciliationProjectionPreview;

  Future<String?> Function()?
  get sessionRunnerReconciliationProjectionFileReader;

  /// Explicit request and reader for the authenticated, read-only EXECUTE
  /// receipt-history reduction candidate. The default Gate leaves both unset
  /// so the shared Web/App/Mobile surface never requests history remotely.
  ForgeSessionRunnerReceiptHistory? get sessionRunnerReceiptHistoryRequest;

  Future<ForgeSessionRunnerReceiptHistory> Function(
    String,
    String,
    ForgeSessionRunnerReceiptHistory,
  )?
  get sessionRunnerReceiptHistoryReader;

  /// Explicit request and reader for the authenticated, read-only manual
  /// reconciliation projection candidate. The default Gate leaves both
  /// unset so the shared Web/App/Mobile surface never requests it remotely.
  ForgeSessionRunnerReceiptHistory?
  get sessionRunnerReconciliationProjectionRequest;

  Future<ForgeSessionRunnerReconciliationProjection> Function(
    String,
    String,
    ForgeSessionRunnerReceiptHistory,
  )?
  get sessionRunnerReconciliationProjectionReader;

  /// Enables the reviewed reconciliation projection reader for a test or
  /// candidate harness. Production construction keeps this false.
  bool get enableSessionRunnerReconciliationProjectionCandidate;

  /// Candidate-only origin for the reconciliation projection POST. It is
  /// required when the candidate is enabled.
  String? get sessionRunnerReconciliationProjectionCandidateApiOrigin;

  /// Enables the explicit two-step reconciliation candidate for a test or
  /// candidate harness. When enabled, the Gate first canonicalizes the
  /// supplied history through the history preview and then derives the
  /// projection from that returned value. Production construction keeps this
  /// false, so the default Gate remains request-free.
  bool get enableSessionRunnerReconciliationProjectionHistoryChainCandidate;

  /// Enables the reviewed remote history reader for a test or candidate
  /// harness. Production construction keeps this false.
  bool get enableSessionRunnerReceiptHistoryCandidate;

  /// Candidate-only origin for the history reduction POST. It is required
  /// when [enableSessionRunnerReceiptHistoryCandidate] is true.
  String? get sessionRunnerReceiptHistoryCandidateApiOrigin;

  /// Explicit reader for the authenticated Run/receipt evidence join. The
  /// default Gate leaves it unset, so the shared Web/App/Mobile surface makes
  /// no evidence request during startup or refresh.
  Future<ForgeRunExecutionEvidence> Function(
    String,
    String,
    ForgeRunObserved,
    ForgeSessionRunnerReceiptObservation,
  )?
  get runExecutionEvidenceReader;

  /// Enables the reviewed, read-only Run execution-evidence candidate for a
  /// test or candidate harness. Production construction keeps this false.
  bool get enableRunExecutionEvidenceCandidate;

  /// Candidate-only origin for the Run execution-evidence POST. It must be
  /// explicit when [enableRunExecutionEvidenceCandidate] is true.
  String? get runExecutionEvidenceCandidateApiOrigin;

  /// Optional caller-supplied restart-boundary reconciliation observation.
  /// The Gate never fetches it by default; when supplied it remains strictly
  /// display-only and candidate-bound.
  ForgeExecutionReconciliationObservation?
  get executionReconciliationObservation;

  /// Optional explicit restart image and reader for the authenticated
  /// execution-reconciliation candidate. The default Gate leaves both unset
  /// and therefore cannot make this candidate request.
  ForgeExecutionReconciliationInput? get executionReconciliationInput;

  Future<ForgeExecutionReconciliationObservation> Function(
    ForgeExecutionReconciliationInput,
  )?
  get executionReconciliationReader;

  /// Enables the explicitly reviewed execution-reconciliation candidate for a
  /// test or candidate harness. Production construction keeps this false.
  bool get enableExecutionReconciliationCandidate;

  /// Optional origin used only by the explicitly enabled candidate adapter.
  String? get executionReconciliationCandidateApiOrigin;

  /// Explicit owner and reader for the private execution-consent preview
  /// candidate. The selected Conversation is supplied by the Sessions screen;
  /// the default Gate leaves this seam unset and request-free.
  ForgeDeviceOwner? get executionConsentPreviewOwner;

  Future<ForgeExecutionConsentPreview> Function({
    required String conversationID,
    required ForgeDeviceOwner owner,
  })?
  get executionConsentPreviewReader;

  /// Enables the reviewed, read-only execution-consent preview candidate for
  /// a test or candidate harness. Production construction keeps this false.
  bool get enableExecutionConsentPreviewCandidate;

  /// Candidate-only origin for the execution-consent preview GET. It must be
  /// explicit when [enableExecutionConsentPreviewCandidate] is true.
  String? get executionConsentPreviewCandidateApiOrigin;

  /// Optional caller-supplied offline Attempt request contract. It remains a
  /// display-only value and never creates a Run or dispatches a task.
  ForgeAttemptRequestPreviewFixture? get attemptRequestPreview;

  /// Optional local Runner Attempt lifecycle boundary observation. It is
  /// accepted only through the explicit scope below and never opens a route.
  ForgeRunnerAttemptBoundaryObservation? get runnerAttemptBoundaryPreview;

  ForgeRunnerAttemptBoundaryScope? get runnerAttemptBoundaryScope;

  Future<String?> Function()? get runnerAttemptBoundaryFileReader;

  /// Explicit request and reader for the authenticated Attempt boundary
  /// preview candidate. The default Gate leaves both unset and request-free.
  ForgeRunnerAttemptBoundaryPreviewRequest? get runnerAttemptBoundaryRequest;

  Future<ForgeRunnerAttemptBoundaryObservation> Function(
    ForgeRunnerAttemptBoundaryPreviewRequest,
  )?
  get runnerAttemptBoundaryReader;

  /// Enables the reviewed, read-only Attempt boundary candidate for a test or
  /// candidate harness. Production construction keeps this disabled.
  bool get enableRunnerAttemptBoundaryCandidate;

  /// Candidate-only origin for the Attempt boundary POST. It must match the
  /// API origin exactly when the candidate is enabled.
  String? get runnerAttemptBoundaryCandidateApiOrigin;

  /// Enables the explicit local Attempt boundary projection/import seam. The
  /// default Gate keeps this disabled and request-free.
  bool get enableRunnerAttemptBoundaryProjection;

  /// Optional caller-supplied pending Run-intent receipt. It remains a
  /// metadata-only display value and never creates or dispatches a Run.
  ForgePendingRunIntentFixture? get pendingRunIntentPreview;

  /// Explicitly enables the candidate scheduling-review submit action. The
  /// default Gate leaves it disabled, so normal Web/App/Mobile construction
  /// cannot POST `/run-intents`.
  bool get enablePendingRunIntentCandidate;

  /// Owner and candidate origin are both required before the Gate creates the
  /// submitter. The authenticated server remains the owner authority.
  ForgeDeviceOwner? get pendingRunIntentOwner;

  String? get pendingRunIntentCandidateApiOrigin;

  /// Explicit owner and submitter for the authenticated, content-free Prompt
  /// append receipt path. Supplying these values is the only way for the
  /// Sessions Screen to consume the receipt projection; the default Gate
  /// leaves both unset and request-free.
  ForgeDeviceOwner? get promptAppendReceiptOwner;

  Future<ForgePromptAppendReceiptObservation> Function({
    required String content,
    required String conversationID,
    required int expectedVersion,
    required String idempotencyKey,
    required ForgeDeviceOwner owner,
  })?
  get promptAppendReceiptSubmitter;

  /// Enables the reviewed Prompt append receipt adapter for a test or
  /// candidate harness. Production construction keeps this false.
  bool get enablePromptAppendReceiptCandidate;

  /// Candidate-only origin for the authenticated Prompt append receipt POST.
  /// It must be explicit when the candidate is enabled.
  String? get promptAppendReceiptCandidateApiOrigin;

  /// Requires an owner-bound inventory/resource convergence before an
  /// explicit Prompt append can be submitted. The default remains false so
  /// the ordinary storage-only Prompt journey is unchanged; candidate
  /// harnesses can enable this to keep the selected shared-session journey
  /// aligned with its resource observation.
  bool get requireDeviceInventoryResourceConvergenceForPromptAppend;

  /// Optional, explicitly injected owner-bound inventory candidate seam. The
  /// default Gate does not provide it, so production `/devices` remains
  /// unreachable until its separate governance gate is accepted.
  ForgeDeviceOwner? get deviceInventoryOwner;

  Future<ForgeDeviceInventoryPage> Function(ForgeDeviceOwner)?
  get deviceInventoryReader;

  /// Enables the reviewed, read-only v1 inventory candidate adapter for a
  /// test or candidate harness. Normal Web/App/Mobile construction keeps it
  /// disabled and request-free.
  bool get enableDeviceInventoryCandidate;

  /// Candidate-only origin for the v1 inventory adapter. It must be explicit
  /// when the adapter is enabled so the production Coordinator cannot be
  /// reached accidentally.
  String? get deviceInventoryCandidateApiOrigin;

  /// Optional, explicitly injected owner-bound lossless v2 inventory reader.
  /// The default Gate leaves it unset, so no v2 device request is made.
  Future<ForgeDeviceInventoryPageV2> Function(ForgeDeviceOwner)?
  get deviceInventoryV2Reader;

  /// Optional, explicitly injected owner-bound paired inventory/resource
  /// reader. The default Gate leaves it unset, so the two candidate GETs are
  /// never issued as a pair.
  ForgeDeviceOwner? get deviceInventoryResourceConvergenceOwner;

  Future<ForgeDeviceInventoryResourceConvergence> Function(ForgeDeviceOwner)?
  get deviceInventoryResourceConvergenceReader;

  /// Enables the reviewed, read-only paired inventory/resource candidate for
  /// a test or candidate harness. Normal Web/App/Mobile construction keeps it
  /// disabled and request-free.
  bool get enableDeviceInventoryResourceConvergenceCandidate;

  /// Candidate-only origin for the paired inventory/resource GETs.
  String? get deviceInventoryResourceConvergenceCandidateApiOrigin;

  /// Optional requirements for the explicit registry-backed placement
  /// preview candidate. The default Gate leaves this unset, so no POST is
  /// issued and production scheduling remains unreachable.
  ForgeDevicePlacementRequirements?
  get deviceInventoryRegistryPlacementRequirements;

  Future<ForgeDeviceRegistryPlacementPreview> Function(
    ForgeDeviceOwner,
    ForgeDevicePlacementRequirements,
  )?
  get deviceInventoryRegistryPlacementPreviewReader;
}
