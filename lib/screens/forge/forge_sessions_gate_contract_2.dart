part of 'forge_sessions_gate.dart';

/// Typed documentation for the unchanged ForgeSessionsGate constructor surface.
abstract interface class _ForgeSessionsGateContract2 {
  /// Enables the reviewed, read-only registry placement preview candidate for
  /// a test or migration harness. Normal Web/App/Mobile construction keeps it
  /// disabled and request-free.
  bool get enableDeviceInventoryRegistryPlacementPreviewCandidate;

  /// Candidate-only origin for the registry placement preview adapter.
  String? get deviceInventoryRegistryPlacementPreviewCandidateApiOrigin;

  /// Explicit request and reader for the planning-only scheduler-selection
  /// preview. The default Gate leaves it disabled and request-free.
  ForgeSchedulerSelectionPreviewRequest? get schedulerSelectionPreviewRequest;

  Future<ForgeSchedulerSelectionPreview> Function(
    ForgeSchedulerSelectionPreviewRequest,
  )?
  get schedulerSelectionPreviewReader;

  /// Enables the reviewed, read-only scheduler-selection adapter for a test
  /// or candidate harness. Normal Web/App/Mobile construction keeps it off.
  bool get enableSchedulerSelectionPreviewCandidate;

  /// Candidate-only origin for the scheduler-selection adapter.
  String? get schedulerSelectionPreviewCandidateApiOrigin;

  /// Explicit request and reader for the accepted EXECUTE scheduler lease
  /// claim. The default Gate leaves this unset and request-free.
  ForgeSchedulerSelectionLeaseRequest? get schedulerSelectionLeaseRequest;

  Future<ForgeSchedulerSelectionLease> Function(
    ForgeSchedulerSelectionLeaseRequest,
    String,
  )?
  get schedulerSelectionLeaseReader;

  /// Enables the reviewed scheduler-lease candidate for a test or candidate
  /// harness. Claiming is single-shot and bound to the supplied key.
  bool get enableSchedulerSelectionLeaseCandidate;

  /// Candidate-only origin for the scheduler-lease POST.
  String? get schedulerSelectionLeaseCandidateApiOrigin;

  /// Stable idempotency key retained across an explicit caller retry.
  String? get schedulerSelectionLeaseIdempotencyKey;

  /// Explicit request and reader for the accepted EXECUTE scheduler-lease
  /// renewal. The default Gate leaves this unset and request-free.
  ForgeSchedulerSelectionLeaseRenewalRequest?
  get schedulerSelectionLeaseRenewalRequest;

  Future<ForgeSchedulerSelectionLease> Function(
    ForgeSchedulerSelectionLeaseRenewalRequest,
    String,
  )?
  get schedulerSelectionLeaseRenewalReader;

  /// Enables the reviewed scheduler-lease renewal candidate for a test or
  /// candidate harness. Renewal is one-shot and bound to the supplied proof
  /// and idempotency key.
  bool get enableSchedulerSelectionLeaseRenewalCandidate;

  /// Candidate-only origin for the scheduler-lease renewal POST.
  String? get schedulerSelectionLeaseRenewalCandidateApiOrigin;

  /// Stable idempotency key retained across an explicit renewal retry.
  String? get schedulerSelectionLeaseRenewalIdempotencyKey;

  /// Explicit request and reader for the accepted EXECUTE scheduler-lease
  /// release. The default Gate leaves this unset and request-free.
  ForgeSchedulerSelectionLeaseReleaseRequest?
  get schedulerSelectionLeaseReleaseRequest;

  Future<ForgeSchedulerSelectionLeaseRelease> Function(
    ForgeSchedulerSelectionLeaseReleaseRequest,
    String,
  )?
  get schedulerSelectionLeaseReleaseReader;

  /// Enables the reviewed scheduler-lease release candidate for a test or
  /// candidate harness. Release is one-shot and bound to the supplied proof
  /// and idempotency key.
  bool get enableSchedulerSelectionLeaseReleaseCandidate;

  /// Candidate-only origin for the scheduler-lease release POST.
  String? get schedulerSelectionLeaseReleaseCandidateApiOrigin;

  /// Stable idempotency key retained across an explicit release retry.
  String? get schedulerSelectionLeaseReleaseIdempotencyKey;

  /// Optional, explicitly injected v2 persisted inventory observation. The
  /// default Gate leaves it unset; when present it is display-only and local.
  ForgeDeviceInventoryPageV2? get deviceInventoryV2Preview;

  /// Optional bounded JSON reader for the local v2 inventory preview. The
  /// default Gate leaves it unset; the platform picker and injected readers
  /// remain request-free and do not enable inventory authority.
  Future<String?> Function()? get deviceInventoryV2FileReader;

  /// Optional, explicitly injected v2 placement comparison. The default Gate
  /// leaves it unset; when present it is display-only and local.
  ForgeDeviceInventoryPlacementEvaluationV2?
  get deviceInventoryPlacementEvaluationV2Preview;

  /// Optional bounded JSON reader for the local v2 placement comparison. The
  /// default Gate leaves it unset; the preview never selects or reserves a
  /// target and never opens a placement route.
  Future<String?> Function()?
  get deviceInventoryPlacementEvaluationV2FileReader;

  /// Optional, explicitly injected persisted-inventory placement evaluation.
  /// The default Gate leaves it unset; when present it is display-only and
  /// local.
  ForgeDeviceInventoryPlacementEvaluationFixture?
  get deviceInventoryPlacementEvaluationPreview;

  /// Optional bounded JSON reader for the local placement evaluation preview.
  /// The preview never selects or reserves a target and never opens a route.
  Future<String?> Function()? get deviceInventoryPlacementEvaluationFileReader;

  /// Optional, explicitly injected persisted-inventory placement batch
  /// comparison. The default Gate leaves it unset; when present it remains a
  /// display-only value and never selects or reserves a target.
  ForgeDeviceInventoryPlacementBatchEvaluationFixture?
  get deviceInventoryPlacementBatchEvaluationPreview;

  /// Optional bounded JSON reader for the local placement batch preview. The
  /// default Gate leaves it unset; the preview never selects or reserves a
  /// target and never opens a scheduling route.
  Future<String?> Function()?
  get deviceInventoryPlacementBatchEvaluationFileReader;

  /// Optional, explicitly injected owner-scoped pending Run-intent metadata
  /// seam. The default Gate leaves it unset; the opt-in pending Run-intent
  /// candidate supplies the same reader from its authenticated API adapter.
  Future<ForgePendingRunIntentListPage> Function(String)?
  get pendingRunIntentReader;

  /// Optional paged variant of [pendingRunIntentReader]. The first call uses
  /// a null cursor; subsequent calls receive the strictly validated cursor
  /// from the previous page. The default Gate leaves it unset.
  Future<ForgePendingRunIntentListPage> Function(
    String,
    ForgePendingRunIntentCursor?,
  )?
  get pendingRunIntentPageReader;

  /// Optional, explicitly injected owner-scoped pending Run-intent timeline
  /// seam. The default Gate leaves it unset; the opt-in pending Run-intent
  /// candidate supplies the same reader from its authenticated API adapter.
  Future<ForgePendingRunIntentTimelinePage> Function(String, String)?
  get pendingRunIntentTimelineReader;

  /// Optional local Runner lease/fencing fixture and bounded file reader.
  /// Neither value opens a production device or execution route.
  ForgeRunnerLeaseFencingFixture? get runnerLeaseFencingPreview;

  Future<String?> Function()? get runnerLeaseFencingFileReader;

  /// Optional local execution-lease restart image. It remains a strict,
  /// display-only value and never restores a lease or opens a Runner route.
  ForgeExecutionLeaseCheckpointFixture? get executionLeaseCheckpointPreview;

  /// Optional bounded JSON reader for the local execution-lease checkpoint
  /// preview. The default Gate leaves it unset and request-free.
  Future<String?> Function()? get executionLeaseCheckpointFileReader;

  /// Optional local client-instance/session metadata. The default Gate leaves
  /// it unset; when supplied it remains read-only and fixture-backed.
  ForgeClientInstanceSessionView? get clientInstanceSessionViewPreview;

  /// Optional local client-instance/resource metadata. The default Gate leaves
  /// it unset; when supplied it remains read-only and fixture-backed.
  ForgeClientInstanceResourceView? get clientInstanceResourceViewPreview;

  /// Explicit owner and reader for the private client-instance/resource-view
  /// candidate. Both values are required before the Gate permits a request;
  /// the default Gate leaves them unset.
  ForgeDeviceOwner? get clientInstanceResourceViewOwner;

  Future<ForgeClientInstanceResourceView> Function(ForgeDeviceOwner)?
  get clientInstanceResourceViewReader;

  /// Enables the explicitly reviewed, read-only client-instance/resource-view
  /// candidate adapter for a test or candidate harness. The default Gate
  /// keeps this disabled, so the candidate route remains unreachable from
  /// normal Web/App/Mobile construction.
  bool get enableClientInstanceResourceViewCandidate;

  /// Optional origin used by [enableClientInstanceResourceViewCandidate]. An
  /// explicit owner declaration is still required through
  /// [clientInstanceResourceViewOwner].
  String? get clientInstanceResourceViewCandidateApiOrigin;

  /// Optional local Run → Attempt → lease dispatch preflight. It is strictly
  /// display-only; the default Gate leaves it unset and never opens a route.
  ForgePreflightFixture? get runAttemptLeaseDispatchPreflightPreview;

  /// Explicit request and reader for the private Run → Attempt → lease
  /// dispatch preflight candidate. Both are required before the Gate can
  /// reach the route; the default Gate leaves them unset and request-free.
  ForgeRunAttemptLeaseDispatchPreflightRequest?
  get runAttemptLeaseDispatchPreflightRequest;

  Future<ForgePreflightFixture> Function(
    ForgeRunAttemptLeaseDispatchPreflightRequest,
  )?
  get runAttemptLeaseDispatchPreflightReader;

  /// Enables the explicitly reviewed, read-only Run → Attempt → lease
  /// dispatch preflight candidate adapter for a test or candidate harness.
  /// The default Gate keeps this disabled, so the candidate POST route is
  /// unreachable from normal Web/App/Mobile construction.
  bool get enableRunAttemptLeaseDispatchPreflightCandidate;

  /// Optional origin used by
  /// [enableRunAttemptLeaseDispatchPreflightCandidate]. An explicit typed
  /// request is still required through
  /// [runAttemptLeaseDispatchPreflightRequest].
  String? get runAttemptLeaseDispatchPreflightCandidateApiOrigin;

  /// Optional local Runner dispatch-plan comparison. It is strictly
  /// display-only; the default Gate leaves it unset and never opens a route.
  ForgeRunnerDispatchPlanPreview? get runnerDispatchPlanPreview;

  /// Explicit request and reader for the private Runner dispatch-plan
  /// comparison candidate. Both are required before the Gate can reach the
  /// route; normal Web/App/Mobile construction remains request-free.
  ForgeRunAttemptLeaseDispatchPreflightRequest?
  get runnerDispatchPlanPreviewRequest;

  Future<ForgeRunnerDispatchPlanPreview> Function(
    ForgeRunAttemptLeaseDispatchPreflightRequest,
  )?
  get runnerDispatchPlanPreviewReader;

  /// Enables the explicitly reviewed, read-only Runner dispatch-plan
  /// comparison candidate for a test or candidate harness. Production
  /// construction keeps this disabled.
  bool get enableRunnerDispatchPlanPreviewCandidate;

  /// Optional origin used only by the explicitly enabled candidate adapter.
  /// An explicit typed request is still required through
  /// [runnerDispatchPlanPreviewRequest].
  String? get runnerDispatchPlanPreviewCandidateApiOrigin;

  /// Explicit request and reader for the accepted EXECUTE lease-to-Runner
  /// admission recheck. The default Gate leaves this unset and request-free.
  ForgeRunnerDispatchAdmission? get runnerDispatchAdmission;

  ForgeRunnerDispatchAdmissionRequest? get runnerDispatchAdmissionRequest;

  Future<ForgeRunnerDispatchAdmission> Function(
    ForgeRunnerDispatchAdmissionRequest,
  )?
  get runnerDispatchAdmissionReader;

  /// Enables the reviewed, read-only Runner dispatch admission candidate for a
  /// test or candidate harness. Production construction keeps it disabled.
  bool get enableRunnerDispatchAdmissionCandidate;

  /// Candidate-only origin for the Runner dispatch admission POST.
  String? get runnerDispatchAdmissionCandidateApiOrigin;

  /// Explicit request and reader for the accepted EXECUTE transport
  /// admission preview. The default Gate leaves this unset and request-free.
  ForgeRunnerTransportAdmission? get runnerTransportAdmission;

  ForgeRunnerTransportAdmissionRequest? get runnerTransportAdmissionRequest;

  Future<ForgeRunnerTransportAdmission> Function(
    ForgeRunnerTransportAdmissionRequest,
  )?
  get runnerTransportAdmissionReader;

  /// Enables the reviewed, read-only Runner transport admission candidate for
  /// a test or candidate harness. Production construction keeps it disabled.
  bool get enableRunnerTransportAdmissionCandidate;

  /// Candidate-only origin for the Runner transport admission POST.
  String? get runnerTransportAdmissionCandidateApiOrigin;

  /// Explicit request and reader for the final server-owned Runner
  /// execution-boundary preview. The default Gate leaves this unset.
  ForgeRunnerExecutionBoundaryObservation? get runnerExecutionBoundary;

  ForgeRunnerExecutionBoundaryPreviewRequest?
  get runnerExecutionBoundaryRequest;

  Future<ForgeRunnerExecutionBoundaryObservation> Function(
    ForgeRunnerExecutionBoundaryPreviewRequest,
  )?
  get runnerExecutionBoundaryReader;

  /// Enables the reviewed, read-only execution-boundary candidate for a test
  /// or candidate harness. Production construction keeps it disabled.
  bool get enableRunnerExecutionBoundaryCandidate;

  /// Candidate-only origin for the execution-boundary POST.
  String? get runnerExecutionBoundaryCandidateApiOrigin;

  /// Explicit owner and reader for the private client-instance/session-view
  /// candidate. Both values are required before the Gate permits a request;
  /// the default Gate leaves them unset.
  ForgeDeviceOwner? get clientInstanceSessionViewOwner;

  Future<ForgeClientInstanceSessionView> Function(ForgeDeviceOwner)?
  get clientInstanceSessionViewReader;

  /// Enables the explicitly reviewed, read-only client-instance/session-view
  /// candidate adapter for a test or candidate harness. The default Gate
  /// keeps this disabled, so the candidate route remains unreachable from
  /// normal Web/App/Mobile construction.
  bool get enableClientInstanceSessionViewCandidate;

  /// Optional origin used by [enableClientInstanceSessionViewCandidate]. An
  /// explicit owner declaration is still required through
  /// [clientInstanceSessionViewOwner].
  String? get clientInstanceSessionViewCandidateApiOrigin;

  /// Explicit owner and reader for the private paired client-instance
  /// session/resource candidate. The default Gate leaves this unset, so the
  /// shared Sessions surface performs no candidate GETs unless a caller opts
  /// in with an owner and the reviewed flag.
  ForgeDeviceOwner? get clientInstanceSessionResourceConvergenceOwner;

  Future<ForgeClientInstanceSessionResourceConvergence> Function(
    ForgeDeviceOwner,
  )?
  get clientInstanceSessionResourceConvergenceReader;

  /// Enables the reviewed, read-only client-instance session/resource pair
  /// adapter for a test or candidate harness. Production construction keeps
  /// this disabled.
  bool get enableClientInstanceSessionResourceConvergenceCandidate;

  /// Candidate-only origin used by the paired client-instance reader.
  String? get clientInstanceSessionResourceConvergenceCandidateApiOrigin;

  /// Explicit owner and origin for the private lifecycle-registry GET
  /// candidate. Both values stay unset in normal Web/App/Mobile construction;
  /// no lifecycle-registry request is made unless the reviewed candidate flag
  /// is enabled with an owner and candidate origin.
  ForgeDeviceOwner? get lifecycleRegistryOwner;

  Future<ForgeDeviceEnrollmentHeartbeatLifecycleRegistry> Function(
    ForgeDeviceOwner,
  )?
  get lifecycleRegistryReader;

  /// Enables the explicitly reviewed, read-only lifecycle-registry candidate
  /// adapter for a test or candidate harness. The default Gate keeps this
  /// disabled, so enrollment/heartbeat state remains request-free.
  bool get enableLifecycleRegistryCandidate;

  /// Candidate-only origin for the lifecycle-registry GET adapter. It must be
  /// explicit when [enableLifecycleRegistryCandidate] is true.
  String? get lifecycleRegistryCandidateApiOrigin;

  /// Explicit owner, metadata request, and reader for the private credential
  /// lifecycle candidate. These values stay unset in normal Web/App/Mobile
  /// construction; the candidate POST cannot be reached without all three
  /// declarations and the opt-in flag below.
  ForgeDeviceOwner? get deviceCredentialCandidateOwner;

  ForgeDeviceCredentialLifecycleRequest? get deviceCredentialCandidateRequest;

  Future<ForgeDeviceCredentialLifecycleCandidate> Function({
    required ForgeDeviceOwner owner,
    required ForgeDeviceCredentialLifecycleRequest request,
  })?
  get deviceCredentialCandidateReader;
}
