part of 'forge_sessions_screen.dart';

/// Typed documentation for the unchanged ForgeSessionsScreen constructor surface.
abstract interface class _ForgeSessionsScreenContract2 {
  /// Optional bounded JSON reader for the local placement evaluation preview.
  /// A supplied reader remains request-free and process-local.
  Future<String?> Function()? get deviceInventoryPlacementEvaluationFileReader;

  /// Optional, caller-supplied persisted-inventory placement batch
  /// comparison. It is rendered as a local read-only preview and never
  /// selects a target or issues a device request.
  ForgeDeviceInventoryPlacementBatchEvaluationFixture?
  get deviceInventoryPlacementBatchEvaluationPreview;

  /// Optional bounded JSON reader for the local persisted-inventory placement
  /// batch preview. It remains request-free and never selects a target.
  Future<String?> Function()?
  get deviceInventoryPlacementBatchEvaluationFileReader;

  /// Explicit reader for the private, owner-scoped pending Run-intent
  /// metadata candidate. The callback is optional and the default route never
  /// requests `/run-intents`; it also never exposes Prompt content or any
  /// execution action.
  Future<ForgePendingRunIntentListPage> Function(String)?
  get pendingRunIntentReader;

  /// Optional paged reader for the private pending Run-intent candidate. The
  /// first call receives a null cursor and later calls receive the validated
  /// cursor from the previous page. The default route remains request-free.
  Future<ForgePendingRunIntentListPage> Function(
    String,
    ForgePendingRunIntentCursor?,
  )?
  get pendingRunIntentPageReader;

  /// Explicit reader for one payload-free pending Run-intent timeline. The
  /// callback is invoked only after the owner expands a receipt; the default
  /// route never requests the timeline endpoint or exposes execution action.
  Future<ForgePendingRunIntentTimelinePage> Function(String, String)?
  get pendingRunIntentTimelineReader;

  /// Optional initial local Runner lease/fencing fixture. It is rendered only
  /// as metadata and never creates a lease, selects a target, or dispatches a
  /// command.
  ForgeRunnerLeaseFencingFixture? get runnerLeaseFencingPreview;

  /// Optional bounded JSON reader for the local Runner lease/fencing preview.
  /// The default screen uses the platform workspace file picker; callers can
  /// inject a reader for Web/App/Mobile tests without opening any API route.
  Future<String?> Function()? get runnerLeaseFencingFileReader;

  /// Optional local execution-lease restart image. It is strictly re-decoded
  /// before display and never restores a lease or grants execution authority.
  ForgeExecutionLeaseCheckpointFixture? get executionLeaseCheckpointPreview;

  /// Optional bounded JSON reader for the local execution-lease checkpoint
  /// preview. The default screen uses the platform workspace file picker.
  Future<String?> Function()? get executionLeaseCheckpointFileReader;

  /// Optional local client-instance/session metadata. It is strictly
  /// re-decoded before display and never creates a request or authority.
  ForgeClientInstanceSessionView? get clientInstanceSessionViewPreview;

  /// Optional bounded JSON reader for the local client-instance/session
  /// observation. The default screen uses the platform workspace picker; the
  /// reader remains process-local and cannot grant Prompt or execution
  /// authority.
  Future<String?> Function()? get clientInstanceSessionViewFileReader;

  /// Optional local client-instance/resource metadata. It is strictly
  /// re-decoded before display and never creates a request or authority.
  ForgeClientInstanceResourceView? get clientInstanceResourceViewPreview;

  /// Optional bounded JSON reader for the local client-instance/resource
  /// observation. The default screen uses the platform workspace picker; the
  /// reader remains process-local and cannot grant scheduling authority.
  Future<String?> Function()? get clientInstanceResourceViewFileReader;

  /// Explicit owner and reader for the private client-instance/resource-view
  /// candidate. Both values are required before this screen makes a request;
  /// the default screen leaves them unset.
  ForgeDeviceOwner? get clientInstanceResourceViewOwner;

  Future<ForgeClientInstanceResourceView> Function(ForgeDeviceOwner)?
  get clientInstanceResourceViewReader;

  /// Optional local Run → Attempt → lease dispatch preflight. It is strictly
  /// re-decoded before display and never creates a request or dispatches work.
  ForgePreflightFixture? get runAttemptLeaseDispatchPreflightPreview;

  /// Explicitly injected request and reader for the private, stateless
  /// Run → Attempt → lease dispatch preflight candidate. Both values are
  /// required before this screen makes a request; the default screen leaves
  /// them unset, so no preflight route is contacted.
  ForgeRunAttemptLeaseDispatchPreflightRequest?
  get runAttemptLeaseDispatchPreflightRequest;

  Future<ForgePreflightFixture> Function(
    ForgeRunAttemptLeaseDispatchPreflightRequest,
  )?
  get runAttemptLeaseDispatchPreflightReader;

  /// Optional local Runner dispatch-plan comparison. It is strictly
  /// re-decoded before display and never selects, reserves, authorizes, or
  /// dispatches a target.
  ForgeRunnerDispatchPlanPreview? get runnerDispatchPlanPreview;

  /// Explicitly injected request and reader for the private Runner
  /// dispatch-plan comparison candidate. Both are required before this
  /// screen makes a request; the default screen remains request-free.
  ForgeRunAttemptLeaseDispatchPreflightRequest?
  get runnerDispatchPlanPreviewRequest;

  Future<ForgeRunnerDispatchPlanPreview> Function(
    ForgeRunAttemptLeaseDispatchPreflightRequest,
  )?
  get runnerDispatchPlanPreviewReader;

  /// Optional lease-to-Runner admission recheck. It is metadata-only and
  /// never authorizes or dispatches a command.
  ForgeRunnerDispatchAdmission? get runnerDispatchAdmission;

  /// Explicit request and reader for the owner-authenticated admission
  /// candidate. The default screen leaves both unset and request-free.
  ForgeRunnerDispatchAdmissionRequest? get runnerDispatchAdmissionRequest;

  Future<ForgeRunnerDispatchAdmission> Function(
    ForgeRunnerDispatchAdmissionRequest,
  )?
  get runnerDispatchAdmissionReader;

  /// Optional lease-bound Runner transport admission preview. It is strictly
  /// metadata-only and never opens a Runner connection or sends a payload.
  ForgeRunnerTransportAdmission? get runnerTransportAdmission;

  /// Explicit request and reader for the owner-authenticated transport
  /// admission candidate. The default screen leaves both unset and
  /// request-free.
  ForgeRunnerTransportAdmissionRequest? get runnerTransportAdmissionRequest;

  Future<ForgeRunnerTransportAdmission> Function(
    ForgeRunnerTransportAdmissionRequest,
  )?
  get runnerTransportAdmissionReader;

  /// Optional server-owned Runner execution-boundary preview. It is strictly
  /// display-only and never opens a Runner connection.
  ForgeRunnerExecutionBoundaryObservation? get runnerExecutionBoundary;

  ForgeRunnerExecutionBoundaryPreviewRequest?
  get runnerExecutionBoundaryRequest;

  Future<ForgeRunnerExecutionBoundaryObservation> Function(
    ForgeRunnerExecutionBoundaryPreviewRequest,
  )?
  get runnerExecutionBoundaryReader;

  /// Explicit owner and reader for the private client-instance/session-view
  /// candidate. Both values are required before this screen makes a request;
  /// the default screen leaves them unset.
  ForgeDeviceOwner? get clientInstanceSessionViewOwner;

  Future<ForgeClientInstanceSessionView> Function(ForgeDeviceOwner)?
  get clientInstanceSessionViewReader;

  /// Explicit owner and reader for the paired client-instance session and
  /// resource observations. When supplied, the screen consumes both views
  /// from one validated read pair before rendering the existing cards.
  ForgeDeviceOwner? get clientInstanceSessionResourceConvergenceOwner;

  Future<ForgeClientInstanceSessionResourceConvergence> Function(
    ForgeDeviceOwner,
  )?
  get clientInstanceSessionResourceConvergenceReader;

  /// Explicit owner and reader for the private lifecycle-registry GET
  /// candidate. Both values are required before this screen makes a request;
  /// the default screen remains request-free.
  ForgeDeviceOwner? get lifecycleRegistryOwner;

  Future<ForgeDeviceEnrollmentHeartbeatLifecycleRegistry> Function(
    ForgeDeviceOwner,
  )?
  get lifecycleRegistryReader;

  /// Explicit owner, metadata request, and reader for the private credential
  /// lifecycle candidate. The default screen leaves these unset and therefore
  /// never posts to the candidate route.
  ForgeDeviceOwner? get deviceCredentialCandidateOwner;

  ForgeDeviceCredentialLifecycleRequest? get deviceCredentialCandidateRequest;

  Future<ForgeDeviceCredentialLifecycleCandidate> Function({
    required ForgeDeviceOwner owner,
    required ForgeDeviceCredentialLifecycleRequest request,
  })?
  get deviceCredentialCandidateReader;
}
