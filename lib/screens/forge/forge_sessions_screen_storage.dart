part of 'forge_sessions_screen.dart';

mixin _ForgeSessionsScreenStorage on State<ForgeSessionsScreen> {
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
}
