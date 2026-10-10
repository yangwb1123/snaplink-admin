part of 'forge_conversations_api.dart';

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
