part of 'forge_sessions_gate.dart';

extension _ForgeSessionsGateDeviceRegistry on _ForgeSessionsGateState {
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
      useWallClockTimeout: true,
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
      useWallClockTimeout: true,
    );
    _deviceInventoryV2CandidateApi = api;
    _deviceInventoryV2CandidateReader = (owner) =>
        api.readDeviceInventoryCandidateV2(owner: owner);
  }

  void _configureDeviceInventoryResourceConvergenceCandidate(String? token) {
    final owner = widget.deviceInventoryResourceConvergenceOwner;
    if (token == null ||
        !widget.enableDeviceInventoryResourceConvergenceCandidate ||
        widget.deviceInventoryResourceConvergenceReader != null ||
        owner == null) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl:
          widget.deviceInventoryResourceConvergenceCandidateApiOrigin ??
          ForgeConversationsApiOrigin.baseUrl,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _deviceInventoryResourceConvergenceCandidateApi = api;
    _deviceInventoryResourceConvergenceCandidateReader = (requestedOwner) {
      if (requestedOwner != owner) {
        return Future<ForgeDeviceInventoryResourceConvergence>.error(
          const FormatException(
            'Forge inventory/resource convergence owner binding changed.',
          ),
        );
      }
      return api.readConvergedInventoryResourceView(owner: owner);
    };
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
}
