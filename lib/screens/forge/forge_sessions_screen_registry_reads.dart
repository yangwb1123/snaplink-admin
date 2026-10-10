part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenRegistryReads on _ForgeSessionsScreenState {
  Future<void> _loadDeviceInventoryRegistryPlacementPreviewIfRequested({
    bool force = false,
  }) async {
    final owner = widget.deviceInventoryOwner;
    final requirements = widget.deviceInventoryRegistryPlacementRequirements;
    final reader = widget.deviceInventoryRegistryPlacementPreviewReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || requirements == null || reader == null) {
      if (mounted &&
          (_fetchedDeviceInventoryRegistryPlacementPreview != null ||
              _deviceInventoryRegistryPlacementPreviewError != null ||
              _loadingDeviceInventoryRegistryPlacementPreview)) {
        _update(_clearDeviceInventoryRegistryPlacementPreview);
      }
      return;
    }
    if (_loadingDeviceInventoryRegistryPlacementPreview) return;
    if (!force &&
        (_fetchedDeviceInventoryRegistryPlacementPreview != null ||
            _deviceInventoryRegistryPlacementPreviewError != null)) {
      return;
    }
    final previousPreview = _fetchedDeviceInventoryRegistryPlacementPreview;
    final generation = ++_deviceInventoryRegistryPlacementPreviewGeneration;
    _update(() {
      _loadingDeviceInventoryRegistryPlacementPreview = true;
      _deviceInventoryRegistryPlacementPreviewError = null;
      _deviceInventoryRegistryPlacementPreviewStale = previousPreview != null;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final expectedRequirements = ForgeDevicePlacementRequirements.fromJson(
        requirements.toJson(),
      );
      final preview = ForgeDeviceRegistryPlacementPreview.fromJson(
        (await reader(owner, expectedRequirements)).toJson(),
      );
      if (preview.evaluationOwner != expectedOwner ||
          preview.authority.anyGranted ||
          preview.selectedDeviceID != null ||
          preview.selectedInstanceID != null) {
        throw const FormatException(
          'Forge returned an invalid registry placement preview.',
        );
      }
      if (!mounted ||
          generation != _deviceInventoryRegistryPlacementPreviewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedDeviceInventoryRegistryPlacementPreview = preview;
        _deviceInventoryRegistryPlacementPreviewError = null;
        _deviceInventoryRegistryPlacementPreviewStale = false;
        _loadingDeviceInventoryRegistryPlacementPreview = false;
      });
    } catch (error) {
      if (!mounted ||
          generation != _deviceInventoryRegistryPlacementPreviewGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _deviceInventoryRegistryPlacementPreviewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedDeviceInventoryRegistryPlacementPreview = previousPreview;
        _deviceInventoryRegistryPlacementPreviewError = _friendlyError(
          error,
          'Could not load registry placement preview.',
        );
        _deviceInventoryRegistryPlacementPreviewStale = previousPreview != null;
        _loadingDeviceInventoryRegistryPlacementPreview = false;
      });
    }
  }

  void _clearDeviceInventoryRegistryPlacementPreview() {
    _deviceInventoryRegistryPlacementPreviewGeneration++;
    _fetchedDeviceInventoryRegistryPlacementPreview = null;
    _deviceInventoryRegistryPlacementPreviewError = null;
    _deviceInventoryRegistryPlacementPreviewStale = false;
    _loadingDeviceInventoryRegistryPlacementPreview = false;
  }

  Future<void> _loadLifecycleRegistryIfRequested({bool force = false}) async {
    final owner = widget.lifecycleRegistryOwner;
    final reader = widget.lifecycleRegistryReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null) {
      if (mounted &&
          (_fetchedLifecycleRegistry != null ||
              _lifecycleRegistryError != null ||
              _loadingLifecycleRegistry)) {
        _update(_clearLifecycleRegistry);
      }
      return;
    }
    if (_loadingLifecycleRegistry) return;
    if (!force &&
        (_fetchedLifecycleRegistry != null ||
            _lifecycleRegistryError != null)) {
      return;
    }
    final previousRegistry = _fetchedLifecycleRegistry;
    final generation = ++_lifecycleRegistryGeneration;
    _update(() {
      _loadingLifecycleRegistry = true;
      _lifecycleRegistryError = null;
      _lifecycleRegistryStale = previousRegistry != null;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      // Re-decode the callback result through the strict wire boundary. This
      // keeps a candidate adapter from bypassing state joins, canonical
      // ordering, numeric bounds, or duplicate/unknown-key checks.
      final registry = ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
        (await reader(owner)).toJson(),
      );
      if (registry.owner != expectedOwner || !registry.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid or differently bound lifecycle registry.',
        );
      }
      if (!mounted ||
          generation != _lifecycleRegistryGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedLifecycleRegistry = registry;
        _lifecycleRegistryError = null;
        _lifecycleRegistryStale = false;
        _loadingLifecycleRegistry = false;
      });
    } catch (error) {
      if (!mounted || generation != _lifecycleRegistryGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _lifecycleRegistryGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedLifecycleRegistry = previousRegistry;
        _lifecycleRegistryError = _friendlyError(
          error,
          'Could not load lifecycle registry observation.',
        );
        _lifecycleRegistryStale = previousRegistry != null;
        _loadingLifecycleRegistry = false;
      });
    }
  }

  void _clearLifecycleRegistry() {
    _lifecycleRegistryGeneration++;
    _fetchedLifecycleRegistry = null;
    _lifecycleRegistryError = null;
    _lifecycleRegistryStale = false;
    _loadingLifecycleRegistry = false;
  }

  /// Loads one explicitly configured credential lifecycle candidate. This is
  /// deliberately not part of change-feed, resume, or manual refresh polling:
  /// the route is a one-shot metadata POST and callers must deliberately
  /// rebuild the candidate request before asking for another preview.
  Future<void> _loadDeviceCredentialCandidateIfRequested() async {
    final owner = widget.deviceCredentialCandidateOwner;
    final request = widget.deviceCredentialCandidateRequest;
    final reader = widget.deviceCredentialCandidateReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || request == null || reader == null) {
      if (mounted &&
          (_fetchedDeviceCredentialCandidate != null ||
              _deviceCredentialCandidateError != null ||
              _loadingDeviceCredentialCandidate)) {
        _update(_clearDeviceCredentialCandidate);
      }
      return;
    }
    if (_loadingDeviceCredentialCandidate ||
        _fetchedDeviceCredentialCandidate != null ||
        _deviceCredentialCandidateError != null) {
      return;
    }
    final generation = ++_deviceCredentialCandidateGeneration;
    _update(() {
      _loadingDeviceCredentialCandidate = true;
      _deviceCredentialCandidateError = null;
      _deviceCredentialCandidateStale = false;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final expectedRequest = ForgeDeviceCredentialLifecycleRequest.fromJson(
        request.toJson(),
      );
      final candidate = ForgeDeviceCredentialLifecycleCandidate.fromJson(
        (await reader(owner: owner, request: expectedRequest)).toJson(),
      );
      if (candidate.owner != expectedOwner ||
          candidate.deviceID != expectedRequest.deviceID ||
          candidate.action != expectedRequest.action ||
          candidate.revision != expectedRequest.expectedDeviceRevision ||
          !candidate.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid credential lifecycle candidate.',
        );
      }
      if (!mounted ||
          generation != _deviceCredentialCandidateGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedDeviceCredentialCandidate = candidate;
        _deviceCredentialCandidateError = null;
        _deviceCredentialCandidateStale = false;
        _loadingDeviceCredentialCandidate = false;
      });
    } catch (error) {
      if (!mounted || generation != _deviceCredentialCandidateGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _deviceCredentialCandidateGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedDeviceCredentialCandidate = null;
        _deviceCredentialCandidateError = _friendlyError(
          error,
          'Could not load credential lifecycle candidate.',
        );
        _deviceCredentialCandidateStale = false;
        _loadingDeviceCredentialCandidate = false;
      });
    }
  }

  void _clearDeviceCredentialCandidate() {
    _deviceCredentialCandidateGeneration++;
    _fetchedDeviceCredentialCandidate = null;
    _deviceCredentialCandidateError = null;
    _deviceCredentialCandidateStale = false;
    _loadingDeviceCredentialCandidate = false;
  }

  bool _sameDeviceCredentialCandidateRequest(
    ForgeDeviceCredentialLifecycleRequest? left,
    ForgeDeviceCredentialLifecycleRequest? right,
  ) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return false;
    return jsonEncode(left.toJson()) == jsonEncode(right.toJson());
  }
}
