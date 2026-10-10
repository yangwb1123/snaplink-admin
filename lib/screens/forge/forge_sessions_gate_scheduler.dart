part of 'forge_sessions_gate.dart';

extension _ForgeSessionsGateScheduler on _ForgeSessionsGateState {
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
}
