part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenResourceGuards on _ForgeSessionsScreenState {
  /// Returns an explanatory error when the explicit Prompt journey is not
  /// backed by a fresh, owner-bound inventory/resource observation. This
  /// guard is disabled by default and only composes the already opt-in
  /// display readers; it never grants or infers Prompt authority.
  String? get _promptAppendInventoryResourceConvergenceError {
    final separateObservationError = _inventoryResourceObservationErrorFor(
      'Prompt append',
    );
    if (separateObservationError != null) return separateObservationError;
    if (!widget.requireDeviceInventoryResourceConvergenceForPromptAppend) {
      return null;
    }
    final inventoryOwner = widget.deviceInventoryResourceConvergenceOwner;
    final inventoryReader = widget.deviceInventoryResourceConvergenceReader;
    if (inventoryOwner == null || inventoryReader == null) {
      return 'Prompt append is waiting for an explicit inventory/resource convergence reader.';
    }
    final inventoryConvergence = _fetchedDeviceInventoryResourceConvergence;
    if (inventoryConvergence == null ||
        _loadingDeviceInventoryResourceConvergence ||
        _deviceInventoryResourceConvergenceError != null ||
        _deviceInventoryResourceConvergenceStale) {
      return 'Prompt append is waiting for a fresh validated inventory/resource observation.';
    }

    final sessionPairOwner =
        widget.clientInstanceSessionResourceConvergenceOwner;
    final sessionPairReader =
        widget.clientInstanceSessionResourceConvergenceReader;
    if (sessionPairOwner != null && sessionPairReader != null) {
      final sessionPair = _fetchedClientInstanceSessionResourceConvergence;
      if (sessionPair == null ||
          _loadingClientInstanceSessionResourceConvergence ||
          _clientInstanceSessionResourceConvergenceError != null ||
          _clientInstanceSessionResourceConvergenceStale) {
        return 'Prompt append is waiting for a fresh validated session/resource observation.';
      }
      if (sessionPair.owner != inventoryConvergence.owner ||
          jsonEncode(sessionPair.resourceView.toJson()) !=
              jsonEncode(inventoryConvergence.resourceView.toJson())) {
        return 'Prompt append is disabled because session/resource and inventory/resource observations do not converge.';
      }
    } else {
      final resourceOwner = widget.clientInstanceResourceViewOwner;
      final resourceReader = widget.clientInstanceResourceViewReader;
      if (resourceOwner != null && resourceReader != null) {
        if (_fetchedClientInstanceResourceView == null ||
            _loadingClientInstanceResourceView ||
            _clientInstanceResourceViewError != null ||
            _clientInstanceResourceViewStale) {
          return 'Prompt append is waiting for a fresh validated resource observation.';
        }
        if (jsonEncode(_fetchedClientInstanceResourceView!.toJson()) !=
            jsonEncode(inventoryConvergence.resourceView.toJson())) {
          return 'Prompt append is disabled because the client resource observation does not converge with inventory.';
        }
      }
      final sessionOwner = widget.clientInstanceSessionViewOwner;
      final sessionReader = widget.clientInstanceSessionViewReader;
      if (sessionOwner != null && sessionReader != null) {
        if (_fetchedClientInstanceSessionView == null ||
            _loadingClientInstanceSessionView ||
            _clientInstanceSessionViewError != null ||
            _clientInstanceSessionViewStale) {
          return 'Prompt append is waiting for a fresh validated session observation.';
        }
        final sessionView = _fetchedClientInstanceSessionView!;
        final sessionInstances = sessionView.instances
            .map((instance) => instance.toJson())
            .toList(growable: false);
        final resourceInstances = inventoryConvergence.resourceView.instances
            .map((instance) => instance.toJson())
            .toList(growable: false);
        if (sessionView.owner != inventoryConvergence.owner ||
            jsonEncode(sessionInstances) != jsonEncode(resourceInstances)) {
          return 'Prompt append is disabled because session and inventory observations do not converge.';
        }
      }
    }
    final selectedInstanceID = _selectedClientInstanceID;
    if (selectedInstanceID != null &&
        !inventoryConvergence.resourceView.instances.any(
          (instance) => instance.instanceID == selectedInstanceID,
        )) {
      return 'Prompt append is disabled because the selected client instance is absent from the validated resource observation.';
    }
    return null;
  }

  bool get _separateInventoryResourceObservationsConfigured {
    final inventoryConfigured =
        widget.deviceInventoryOwner != null &&
        widget.deviceInventoryV2Reader != null;
    final resourceConfigured =
        (widget.clientInstanceSessionResourceConvergenceOwner != null &&
            widget.clientInstanceSessionResourceConvergenceReader != null) ||
        (widget.clientInstanceResourceViewOwner != null &&
            widget.clientInstanceResourceViewReader != null);
    return inventoryConfigured && resourceConfigured;
  }

  String? _inventoryResourceObservationErrorFor(String operation) {
    if (!_separateInventoryResourceObservationsConfigured) return null;
    final inventory = _fetchedDeviceInventoryV2;
    final resource = _fetchedClientInstanceResourceView;
    if (inventory == null ||
        resource == null ||
        _loadingDeviceInventoryV2 ||
        _loadingClientInstanceResourceView ||
        _loadingClientInstanceSessionResourceConvergence ||
        _deviceInventoryV2Error != null ||
        _clientInstanceResourceViewError != null ||
        _clientInstanceSessionResourceConvergenceError != null ||
        _deviceInventoryV2Stale ||
        _clientInstanceResourceViewStale ||
        _clientInstanceSessionResourceConvergenceStale) {
      return '$operation is waiting for a fresh validated inventory/resource observation.';
    }
    if (!forgeDeviceInventoryAndResourceObservationsConverged(
      inventory,
      resource,
    )) {
      return '$operation blocked by inventory/resource observation drift. No request was sent.';
    }
    return null;
  }

  Future<String?> _refreshInventoryResourceObservationsBeforeOperation(
    String operation, {
    bool force = false,
  }) async {
    final combinedConfigured =
        widget.deviceInventoryResourceConvergenceOwner != null &&
        widget.deviceInventoryResourceConvergenceReader != null;
    if (!_separateInventoryResourceObservationsConfigured &&
        !combinedConfigured) {
      return null;
    }
    if (combinedConfigured) {
      final current = _fetchedDeviceInventoryResourceConvergence;
      if (force ||
          current == null ||
          _loadingDeviceInventoryResourceConvergence ||
          _deviceInventoryResourceConvergenceError != null ||
          _deviceInventoryResourceConvergenceStale) {
        await _loadDeviceInventoryResourceConvergenceIfRequested(force: true);
      }
      if (!mounted || _authorizationInvalidated) {
        return '$operation was cancelled.';
      }
      final refreshed = _fetchedDeviceInventoryResourceConvergence;
      if (refreshed == null ||
          _loadingDeviceInventoryResourceConvergence ||
          _deviceInventoryResourceConvergenceError != null ||
          _deviceInventoryResourceConvergenceStale) {
        return '$operation is waiting for a fresh validated inventory/resource observation.';
      }

      // A composed inventory/resource response proves that its own device
      // rows converge, but it does not prove that a separately read
      // client-instance pair still describes the same resource image. Keep
      // the selected Sessions surface and the scheduling boundary on one
      // owner-bound snapshot before any candidate POST is allowed.
      final sessionPairConfigured =
          widget.clientInstanceSessionResourceConvergenceOwner != null &&
          widget.clientInstanceSessionResourceConvergenceReader != null;
      if (sessionPairConfigured) {
        final sessionPair = _fetchedClientInstanceSessionResourceConvergence;
        if (sessionPair == null ||
            _loadingClientInstanceSessionResourceConvergence ||
            _clientInstanceSessionResourceConvergenceError != null ||
            _clientInstanceSessionResourceConvergenceStale) {
          return '$operation is waiting for a fresh validated session/resource observation.';
        }
        if (sessionPair.owner != refreshed.owner ||
            jsonEncode(sessionPair.resourceView.toJson()) !=
                jsonEncode(refreshed.resourceView.toJson())) {
          return '$operation blocked by inventory/resource observation drift. No request was sent.';
        }
      } else {
        final resourceConfigured =
            widget.clientInstanceResourceViewOwner != null &&
            widget.clientInstanceResourceViewReader != null;
        if (resourceConfigured) {
          final resource = _fetchedClientInstanceResourceView;
          if (resource == null ||
              _loadingClientInstanceResourceView ||
              _clientInstanceResourceViewError != null ||
              _clientInstanceResourceViewStale) {
            return '$operation is waiting for a fresh validated session/resource observation.';
          }
          if (resource.owner != refreshed.owner ||
              jsonEncode(resource.toJson()) !=
                  jsonEncode(refreshed.resourceView.toJson())) {
            return '$operation blocked by inventory/resource observation drift. No request was sent.';
          }
        }
        final sessionConfigured =
            widget.clientInstanceSessionViewOwner != null &&
            widget.clientInstanceSessionViewReader != null;
        if (sessionConfigured) {
          final session = _fetchedClientInstanceSessionView;
          if (session == null ||
              _loadingClientInstanceSessionView ||
              _clientInstanceSessionViewError != null ||
              _clientInstanceSessionViewStale) {
            return '$operation is waiting for a fresh validated session/resource observation.';
          }
          final sessionInstances = session.instances
              .map((instance) => instance.toJson())
              .toList(growable: false);
          final resourceInstances = refreshed.resourceView.instances
              .map((instance) => instance.toJson())
              .toList(growable: false);
          if (session.owner != refreshed.owner ||
              jsonEncode(sessionInstances) != jsonEncode(resourceInstances)) {
            return '$operation blocked by inventory/resource observation drift. No request was sent.';
          }
        }
      }
      return null;
    }
    // A successful owner-scoped refresh already establishes the proof used by
    // this write boundary. Reusing that current, converged image avoids
    // starting a second pair of real HTTP reads in the same frame (which can
    // race the scheduled poll on Web/App/Mobile), while any missing, stale,
    // failed, or drifted image still takes the forced refresh path below.
    final currentError = _inventoryResourceObservationErrorFor(operation);
    if (!force && currentError == null) return null;
    await _loadDeviceInventoryV2IfRequested(force: true);
    if (widget.clientInstanceSessionResourceConvergenceOwner != null &&
        widget.clientInstanceSessionResourceConvergenceReader != null) {
      await _loadClientInstanceSessionResourceConvergenceIfRequested(
        force: true,
      );
    } else {
      await _loadClientInstanceResourceViewIfRequested(force: true);
    }
    if (!mounted || _authorizationInvalidated) {
      return '$operation was cancelled.';
    }
    final refreshedError = _inventoryResourceObservationErrorFor(operation);
    return refreshedError;
  }

  bool _schedulerSelectionTargetMatchesResources(
    ForgeSchedulerSelectionPreview preview,
  ) {
    if (!preview.selectionAvailable) return true;
    final resourceView =
        _strictClientInstanceResourceView(
          widget.clientInstanceResourceViewPreview,
        ) ??
        _strictClientInstanceResourceView(_fetchedClientInstanceResourceView) ??
        _strictClientInstanceResourceView(_clientInstanceResourceViewPreview) ??
        _fetchedDeviceInventoryResourceConvergence?.resourceView;
    // A scheduler preview can be used without an opted-in resource reader.
    // Preserve that request-compatible path; once a resource image is
    // supplied, the selected target must be one of its owner-bound rows.
    if (resourceView == null || resourceView.devices.isEmpty) return true;
    final deviceID = preview.selectedDeviceID;
    final runnerInstanceID = preview.selectedInstanceID;
    if (deviceID == null ||
        runnerInstanceID == null ||
        preview.owner != resourceView.owner) {
      return false;
    }
    return resourceView.devices.any(
      (device) =>
          device.deviceID == deviceID &&
          device.runnerInstanceID == runnerInstanceID,
    );
  }

  bool _runnerDispatchPlanTargetsMatchResources(
    ForgeRunnerDispatchPlanPreview preview,
  ) {
    final resourceView =
        _strictClientInstanceResourceView(
          widget.clientInstanceResourceViewPreview,
        ) ??
        _strictClientInstanceResourceView(_fetchedClientInstanceResourceView) ??
        _strictClientInstanceResourceView(_clientInstanceResourceViewPreview) ??
        _fetchedDeviceInventoryResourceConvergence?.resourceView;
    // Preserve the request-compatible path when no resource reader is
    // configured or the observation has no device rows. Once a non-empty
    // owner-bound resource image is available, every plan candidate must be
    // one of its device or Runner instance IDs. The dispatch-plan contract
    // orders candidates by device ID, while some adapters expose the same
    // target through the Runner instance ID, so bind both declared identities
    // to the same owner-bound resource row.
    if (resourceView == null || resourceView.devices.isEmpty) return true;
    if (preview.owner != resourceView.owner) return false;
    final targetIDs = <String>{};
    for (final device in resourceView.devices) {
      targetIDs
        ..add(device.deviceID)
        ..add(device.runnerInstanceID);
    }
    return targetIDs.contains(preview.intentTargetID) &&
        preview.candidates.every(
          (candidate) => targetIDs.contains(candidate.targetID),
        );
  }

  /// Keeps admission candidates inside the current owner-bound resource
  /// image. A missing resource reader preserves the existing candidate-only
  /// compatibility path; once a non-empty image is supplied, either the
  /// device ID or its Runner instance ID is an acceptable target identity.
  bool _runnerAdmissionTargetMatchesResources(
    ForgeDeviceOwner owner,
    String targetID,
  ) {
    final resourceView =
        _strictClientInstanceResourceView(
          widget.clientInstanceResourceViewPreview,
        ) ??
        _strictClientInstanceResourceView(_fetchedClientInstanceResourceView) ??
        _strictClientInstanceResourceView(_clientInstanceResourceViewPreview) ??
        _fetchedClientInstanceSessionResourceConvergence?.resourceView ??
        _fetchedDeviceInventoryResourceConvergence?.resourceView;
    if (resourceView == null) return true;
    if (resourceView.devices.isEmpty &&
        !_runnerAdmissionResourceObservationConfigured) {
      return true;
    }
    if (resourceView.owner != owner) return false;
    return resourceView.devices.any(
      (device) =>
          device.deviceID == targetID || device.runnerInstanceID == targetID,
    );
  }

  bool _runnerAttemptBoundaryTargetMatchesResources(
    ForgeDeviceOwner owner,
    String targetID,
  ) {
    final resourceView =
        _strictClientInstanceResourceView(
          widget.clientInstanceResourceViewPreview,
        ) ??
        _strictClientInstanceResourceView(_fetchedClientInstanceResourceView) ??
        _strictClientInstanceResourceView(_clientInstanceResourceViewPreview) ??
        _fetchedClientInstanceSessionResourceConvergence?.resourceView ??
        _strictDeviceInventoryResourceConvergence(
          _fetchedDeviceInventoryResourceConvergence,
        )?.resourceView;
    if (resourceView == null) return true;
    if (resourceView.devices.isEmpty &&
        !_runnerAdmissionResourceObservationConfigured) {
      return true;
    }
    if (resourceView.owner != owner) return false;
    return resourceView.devices.any(
      (device) =>
          device.deviceID == targetID || device.runnerInstanceID == targetID,
    );
  }

  bool get _runnerAdmissionResourceObservationConfigured =>
      (widget.deviceInventoryResourceConvergenceOwner != null &&
          widget.deviceInventoryResourceConvergenceReader != null) ||
      (widget.clientInstanceSessionResourceConvergenceOwner != null &&
          widget.clientInstanceSessionResourceConvergenceReader != null) ||
      (widget.clientInstanceResourceViewOwner != null &&
          widget.clientInstanceResourceViewReader != null) ||
      (widget.deviceInventoryOwner != null &&
          widget.deviceInventoryV2Reader != null &&
          (widget.clientInstanceResourceViewOwner != null ||
              widget.clientInstanceSessionResourceConvergenceOwner != null));
}
