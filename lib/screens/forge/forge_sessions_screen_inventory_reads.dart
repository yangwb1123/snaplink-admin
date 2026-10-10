part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenInventoryReads on _ForgeSessionsScreenState {
  Future<void> _loadDeviceInventoryIfRequested({bool force = false}) async {
    final owner = widget.deviceInventoryOwner;
    final reader = widget.deviceInventoryReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null) {
      if (mounted &&
          (_fetchedDeviceInventory != null ||
              _deviceInventoryError != null ||
              _loadingDeviceInventory)) {
        _update(_clearDeviceInventory);
      }
      return;
    }
    if (_loadingDeviceInventory) return;
    if (!force &&
        (_fetchedDeviceInventory != null || _deviceInventoryError != null)) {
      return;
    }
    final previousPage = _fetchedDeviceInventory;
    final generation = ++_deviceInventoryGeneration;
    _update(() {
      _loadingDeviceInventory = true;
      _deviceInventoryError = null;
      // Keep the last owner-validated snapshot visible while a foreground
      // refresh is in flight. A temporary network failure must not look like
      // an empty resource pool.
      _deviceInventoryStale = previousPage != null;
    });
    try {
      // Re-decode the callback result through the strict wire boundary. This
      // keeps a test or future adapter from constructing an authority-bearing
      // value through the public const model constructor.
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final page = ForgeDeviceInventoryPage.fromJson(
        (await reader(owner)).toJson(),
      );
      if (page.owner != expectedOwner) {
        throw const FormatException(
          'Forge returned device inventory for another owner.',
        );
      }
      if (!mounted ||
          generation != _deviceInventoryGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedDeviceInventory = page;
        _deviceInventoryError = null;
        _deviceInventoryStale = false;
        _loadingDeviceInventory = false;
      });
    } catch (error) {
      if (!mounted || generation != _deviceInventoryGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _deviceInventoryGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedDeviceInventory = previousPage;
        _deviceInventoryError = _friendlyError(
          error,
          'Could not load device inventory observation.',
        );
        _deviceInventoryStale = previousPage != null;
        _loadingDeviceInventory = false;
      });
    }
  }

  void _clearDeviceInventory() {
    _deviceInventoryGeneration++;
    _fetchedDeviceInventory = null;
    _deviceInventoryError = null;
    _deviceInventoryStale = false;
    _loadingDeviceInventory = false;
  }

  Future<void> _loadDeviceInventoryV2IfRequested({bool force = false}) async {
    final inFlight = _deviceInventoryV2Refresh;
    if (inFlight != null) {
      final inFlightWasForced = _deviceInventoryV2RefreshWasForced;
      await inFlight;
      if (!force ||
          (inFlightWasForced &&
              _deviceInventoryV2Error == null &&
              !_deviceInventoryV2Stale)) {
        return;
      }
    }
    final refresh = _loadDeviceInventoryV2Now(force: force);
    _deviceInventoryV2Refresh = refresh;
    _deviceInventoryV2RefreshWasForced = force;
    try {
      await refresh;
    } finally {
      if (identical(_deviceInventoryV2Refresh, refresh)) {
        _deviceInventoryV2Refresh = null;
        _deviceInventoryV2RefreshWasForced = false;
      }
    }
  }

  Future<void> _loadDeviceInventoryV2Now({bool force = false}) async {
    final owner = widget.deviceInventoryOwner;
    final reader = widget.deviceInventoryV2Reader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null) {
      if (mounted &&
          (_fetchedDeviceInventoryV2 != null ||
              _deviceInventoryV2Error != null ||
              _loadingDeviceInventoryV2)) {
        _update(_clearDeviceInventoryV2);
      }
      return;
    }
    if (_loadingDeviceInventoryV2) return;
    if (!force &&
        (_fetchedDeviceInventoryV2 != null ||
            _deviceInventoryV2Error != null)) {
      return;
    }
    final previousPage = _fetchedDeviceInventoryV2;
    final generation = ++_deviceInventoryV2Generation;
    _update(() {
      _loadingDeviceInventoryV2 = true;
      _deviceInventoryV2Error = null;
      // Preserve the last owner-validated v2 snapshot while a refresh is in
      // flight, matching the existing v1 inventory reader behavior.
      _deviceInventoryV2Stale = previousPage != null;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final page = ForgeDeviceInventoryPageV2.fromJson(
        (await reader(owner)).toJson(),
      );
      if (page.owner != expectedOwner) {
        throw const FormatException(
          'Forge returned v2 device inventory for another owner.',
        );
      }
      if (!mounted ||
          generation != _deviceInventoryV2Generation ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedDeviceInventoryV2 = page;
        _deviceInventoryV2Error = null;
        _deviceInventoryV2Stale = false;
        _loadingDeviceInventoryV2 = false;
      });
    } catch (error) {
      if (!mounted || generation != _deviceInventoryV2Generation) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _deviceInventoryV2Generation ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedDeviceInventoryV2 = previousPage;
        _deviceInventoryV2Error = _friendlyError(
          error,
          'Could not load v2 device inventory observation.',
        );
        _deviceInventoryV2Stale = previousPage != null;
        _loadingDeviceInventoryV2 = false;
      });
    }
  }

  void _clearDeviceInventoryV2() {
    _deviceInventoryV2Generation++;
    _fetchedDeviceInventoryV2 = null;
    _deviceInventoryV2Error = null;
    _deviceInventoryV2Stale = false;
    _loadingDeviceInventoryV2 = false;
  }

  Future<void> _loadDeviceInventoryResourceConvergenceIfRequested({
    bool force = false,
  }) async {
    final owner = widget.deviceInventoryResourceConvergenceOwner;
    final reader = widget.deviceInventoryResourceConvergenceReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null) {
      if (mounted &&
          (_fetchedDeviceInventoryResourceConvergence != null ||
              _deviceInventoryResourceConvergenceError != null ||
              _loadingDeviceInventoryResourceConvergence)) {
        _update(_clearDeviceInventoryResourceConvergence);
      }
      return;
    }
    if (_loadingDeviceInventoryResourceConvergence) return;
    if (!force &&
        (_fetchedDeviceInventoryResourceConvergence != null ||
            _deviceInventoryResourceConvergenceError != null)) {
      return;
    }
    final previous = _fetchedDeviceInventoryResourceConvergence;
    final generation = ++_deviceInventoryResourceConvergenceGeneration;
    _update(() {
      _loadingDeviceInventoryResourceConvergence = true;
      _deviceInventoryResourceConvergenceError = null;
      _deviceInventoryResourceConvergenceStale = previous != null;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final convergence = ForgeDeviceInventoryResourceConvergence.fromJson(
        (await reader(owner)).toJson(),
      );
      if (convergence.owner != expectedOwner || !convergence.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid inventory/resource convergence pair.',
        );
      }
      if (!mounted ||
          generation != _deviceInventoryResourceConvergenceGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedDeviceInventoryResourceConvergence = convergence;
        _deviceInventoryResourceConvergenceError = null;
        _deviceInventoryResourceConvergenceStale = false;
        _loadingDeviceInventoryResourceConvergence = false;
      });
      _reconcileSelectedClientInstanceProjection();
    } catch (error) {
      if (!mounted ||
          generation != _deviceInventoryResourceConvergenceGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _deviceInventoryResourceConvergenceGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedDeviceInventoryResourceConvergence = previous;
        _deviceInventoryResourceConvergenceError = _friendlyError(
          error,
          'Could not load converged device resources.',
        );
        _deviceInventoryResourceConvergenceStale = previous != null;
        _loadingDeviceInventoryResourceConvergence = false;
      });
    }
  }

  void _clearDeviceInventoryResourceConvergence() {
    _deviceInventoryResourceConvergenceGeneration++;
    _fetchedDeviceInventoryResourceConvergence = null;
    _deviceInventoryResourceConvergenceError = null;
    _deviceInventoryResourceConvergenceStale = false;
    _loadingDeviceInventoryResourceConvergence = false;
    if (_selectedClientInstanceID != null) {
      _clearRunDetailsForHiddenClientInstance();
    }
  }
}
