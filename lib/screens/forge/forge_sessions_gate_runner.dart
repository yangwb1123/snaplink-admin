part of 'forge_sessions_gate.dart';

extension _ForgeSessionsGateRunner on _ForgeSessionsGateState {
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
}
