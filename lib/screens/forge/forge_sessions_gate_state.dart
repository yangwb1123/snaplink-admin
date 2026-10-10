part of 'forge_sessions_gate.dart';

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

  @override
  Widget build(BuildContext context) => _buildGate(context);
}
