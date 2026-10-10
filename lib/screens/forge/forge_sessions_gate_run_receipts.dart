part of 'forge_sessions_gate.dart';

extension _ForgeSessionsGateRunReceipts on _ForgeSessionsGateState {
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
}
